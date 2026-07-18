import CryptoKit
import Foundation

public struct HFHTTPResponse: Sendable {
    public let data: Data
    public let finalURL: URL
    public let statusCode: Int

    public init(data: Data, finalURL: URL, statusCode: Int) {
        self.data = data
        self.finalURL = finalURL
        self.statusCode = statusCode
    }
}

public protocol HFHTTPTransport: Sendable {
    func metadata(from url: URL, maxBytes: Int) async throws -> HFHTTPResponse
}

public protocol HFHubFileDownloading: Sendable {
    func downloadFile(
        reference: ModelRepositoryReference,
        revision: String,
        path: String,
        to destinationURL: URL,
        progress: Progress
    ) async throws -> URL
}

/// Production file transport using an app-owned streaming URLSession delegate.
///
/// swift-huggingface 0.9.0 uses `URLSession.download(for:delegate:)` on Apple
/// platforms, where its per-task delegate does not own the completion lifecycle.
/// That upstream behavior leaves progress at zero and can lose the temporary file.
/// Keeping the delegate here lets Mirage persist each chunk before acknowledging it.
public final class URLSessionHFFileDownloader: NSObject, HFHubFileDownloading, @unchecked Sendable {
    private let state = URLSessionFileDownloadState()
    private let session: URLSession

    public override convenience init() {
        self.init(configuration: .default)
    }

    public init(configuration: URLSessionConfiguration) {
        let safeConfiguration = configuration.copy() as! URLSessionConfiguration
        safeConfiguration.httpShouldSetCookies = false
        safeConfiguration.httpCookieAcceptPolicy = .never
        safeConfiguration.timeoutIntervalForRequest = max(safeConfiguration.timeoutIntervalForRequest, 60)
        safeConfiguration.timeoutIntervalForResource = max(safeConfiguration.timeoutIntervalForResource, 24 * 60 * 60)
        let delegate = URLSessionFileDownloadDelegate(state: state)
        self.session = URLSession(configuration: safeConfiguration, delegate: delegate, delegateQueue: nil)
        super.init()
    }

    public func downloadFile(
        reference: ModelRepositoryReference,
        revision: String,
        path: String,
        to destinationURL: URL,
        progress: Progress
    ) async throws -> URL {
        guard revision.count == 40, revision.allSatisfy(\.isHexDigit) else {
            throw ModelDownloadError.immutableRevisionMissing
        }
        let sourceURL = URL(string: "https://huggingface.co")!
            .appendingPathComponent(reference.owner)
            .appendingPathComponent(reference.repository)
            .appendingPathComponent("resolve")
            .appendingPathComponent(revision)
            .appendingPathComponent(path)
        try HuggingFaceModelDownloader.validateRequestURL(sourceURL)

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                do {
                    var request = URLRequest(url: sourceURL)
                    request.cachePolicy = .reloadIgnoringLocalCacheData
                    let task = session.dataTask(with: request)
                    try state.register(
                        continuation: continuation,
                        task: task,
                        destinationURL: destinationURL,
                        progress: progress
                    )
                    if Task.isCancelled {
                        state.cancel(destinationURL: destinationURL)
                    } else {
                        task.resume()
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            self.state.cancel(destinationURL: destinationURL)
        }
    }
}

/// Compatibility name retained for callers created before the progress fix.
public typealias SwiftHuggingFaceFileDownloader = URLSessionHFFileDownloader

private final class URLSessionFileDownloadDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let state: URLSessionFileDownloadState

    init(state: URLSessionFileDownloadState) {
        self.state = state
    }

    func urlSession(
        _: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let currentURL = task.currentRequest?.url,
              let targetURL = request.url,
              HuggingFaceModelDownloader.validateRedirect(from: currentURL, to: targetURL) else {
            state.fail(task, error: ModelDownloadError.redirectNotAllowed)
            completionHandler(nil)
            task.cancel()
            return
        }
        completionHandler(request)
    }

    func urlSession(
        _: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            completionHandler(.performDefaultHandling, nil)
        } else {
            completionHandler(.rejectProtectionSpace, nil)
        }
    }

    func urlSession(
        _: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            state.fail(dataTask, error: ModelDownloadError.transportFailed)
            completionHandler(.cancel)
            return
        }
        state.receiveResponse(dataTask)
        completionHandler(.allow)
    }

    func urlSession(_: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if let error = state.append(dataTask, data: data) {
            state.fail(dataTask, error: error)
            dataTask.cancel()
        }
    }

    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        state.complete(task, error: error)
    }
}

final class URLSessionFileDownloadState: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [Int: RequestState] = [:]
    private var taskIDsByDestination: [URL: Int] = [:]

    func register(
        continuation: CheckedContinuation<URL, Error>,
        task: URLSessionDataTask,
        destinationURL: URL,
        progress: Progress
    ) throws {
        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? FileManager.default.removeItem(at: destinationURL)
        guard FileManager.default.createFile(atPath: destinationURL.path, contents: nil) else {
            throw ModelDownloadError.fileSystemFailure
        }
        let handle = try FileHandle(forWritingTo: destinationURL)
        lock.withLock {
            requests[task.taskIdentifier] = RequestState(
                continuation: continuation,
                task: task,
                destinationURL: destinationURL,
                handle: handle,
                progress: progress
            )
            taskIDsByDestination[destinationURL] = task.taskIdentifier
        }
    }

    func receiveResponse(_ task: URLSessionDataTask) {
        lock.withLock {
            requests[task.taskIdentifier]?.receivedResponse = true
        }
    }

    func append(_ task: URLSessionDataTask, data: Data) -> Error? {
        lock.withLock {
            guard var request = requests[task.taskIdentifier] else { return nil }
            do {
                try request.handle.write(contentsOf: data)
                request.receivedBytes += Int64(data.count)
                request.progress.completedUnitCount = request.receivedBytes
                requests[task.taskIdentifier] = request
                return nil
            } catch {
                return error
            }
        }
    }

    func complete(_ task: URLSessionTask, error: Error?) {
        guard let request = take(task) else { return }
        try? request.handle.close()
        if let error {
            try? FileManager.default.removeItem(at: request.destinationURL)
            request.continuation.resume(throwing: error)
            return
        }
        guard request.receivedResponse else {
            try? FileManager.default.removeItem(at: request.destinationURL)
            request.continuation.resume(throwing: ModelDownloadError.transportFailed)
            return
        }
        request.progress.completedUnitCount = request.receivedBytes
        request.continuation.resume(returning: request.destinationURL)
    }

    func fail(_ task: URLSessionTask, error: Error) {
        guard let request = take(task) else { return }
        try? request.handle.close()
        try? FileManager.default.removeItem(at: request.destinationURL)
        request.continuation.resume(throwing: error)
    }

    func cancel(destinationURL: URL) {
        let request = lock.withLock { () -> RequestState? in
            guard let taskID = taskIDsByDestination.removeValue(forKey: destinationURL) else { return nil }
            return requests.removeValue(forKey: taskID)
        }
        guard let request else { return }
        request.task.cancel()
        try? request.handle.close()
        try? FileManager.default.removeItem(at: request.destinationURL)
        request.continuation.resume(throwing: ModelDownloadError.cancelled)
    }

    private func take(_ task: URLSessionTask) -> RequestState? {
        lock.withLock {
            guard let request = requests.removeValue(forKey: task.taskIdentifier) else { return nil }
            taskIDsByDestination.removeValue(forKey: request.destinationURL)
            return request
        }
    }

    private struct RequestState {
        let continuation: CheckedContinuation<URL, Error>
        let task: URLSessionDataTask
        let destinationURL: URL
        let handle: FileHandle
        let progress: Progress
        var receivedBytes: Int64 = 0
        var receivedResponse = false
    }
}

/// Metadata stays on a capped, redirect-restricted session. Large model files are not handled here;
/// `SwiftHuggingFaceFileDownloader` delegates them to swift-huggingface.
public final class URLSessionHFHTTPTransport: NSObject, HFHTTPTransport, @unchecked Sendable {
    private let session: URLSession
    private let state = URLSessionMetadataState()

    public override init() {
        let configuration = URLSessionConfiguration.default
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        let delegate = URLSessionMetadataDelegate(state: state)
        self.session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        super.init()
    }

    public func metadata(from url: URL, maxBytes: Int) async throws -> HFHTTPResponse {
        try HuggingFaceModelDownloader.validateRequestURL(url)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                var request = URLRequest(url: url)
                request.cachePolicy = .reloadIgnoringLocalCacheData
                let task = session.dataTask(with: request)
                state.register(
                    continuation: continuation,
                    task: task,
                    maxBytes: maxBytes,
                    originalURL: url
                )
                task.resume()
            }
        } onCancel: {
            self.state.cancelTask(forOriginalURL: url)
        }
    }
}

private final class URLSessionMetadataDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let state: URLSessionMetadataState

    init(state: URLSessionMetadataState) {
        self.state = state
    }

    func urlSession(
        _: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let currentURL = task.currentRequest?.url,
              let targetURL = request.url,
              HuggingFaceModelDownloader.validateRedirect(from: currentURL, to: targetURL) else {
            state.fail(task, error: ModelDownloadError.redirectNotAllowed)
            completionHandler(nil)
            task.cancel()
            return
        }
        completionHandler(request)
    }

    func urlSession(
        _: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            completionHandler(.performDefaultHandling, nil)
        } else {
            completionHandler(.rejectProtectionSpace, nil)
        }
    }

    func urlSession(
        _: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let http = response as? HTTPURLResponse else {
            state.fail(dataTask, error: ModelDownloadError.transportFailed)
            completionHandler(.cancel)
            return
        }
        guard response.expectedContentLength <= 0
                || response.expectedContentLength <= Int64(state.maxBytes(for: dataTask)) else {
            state.fail(dataTask, error: ModelDownloadError.metadataTooLarge)
            completionHandler(.cancel)
            return
        }
        state.receiveResponse(dataTask, response: http)
        completionHandler(.allow)
    }

    func urlSession(_: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if state.append(dataTask, data: data) {
            state.fail(dataTask, error: ModelDownloadError.metadataTooLarge)
            dataTask.cancel()
        }
    }

    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        state.complete(task, error: error)
    }
}

private final class URLSessionMetadataState: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [Int: RequestState] = [:]
    private var taskIDsByURL: [URL: Int] = [:]

    func register(
        continuation: CheckedContinuation<HFHTTPResponse, Error>,
        task: URLSessionDataTask,
        maxBytes: Int,
        originalURL: URL
    ) {
        lock.withLock {
            requests[task.taskIdentifier] = RequestState(
                continuation: continuation,
                task: task,
                maxBytes: maxBytes,
                originalURL: originalURL
            )
            taskIDsByURL[originalURL] = task.taskIdentifier
        }
    }

    func maxBytes(for task: URLSessionDataTask) -> Int {
        lock.withLock { requests[task.taskIdentifier]?.maxBytes ?? 0 }
    }

    func receiveResponse(_ task: URLSessionDataTask, response: HTTPURLResponse) {
        lock.withLock {
            requests[task.taskIdentifier]?.statusCode = response.statusCode
            requests[task.taskIdentifier]?.finalURL = response.url ?? task.currentRequest?.url
        }
    }

    /// Returns true once the configured metadata cap has been exceeded.
    func append(_ task: URLSessionDataTask, data: Data) -> Bool {
        lock.withLock {
            guard var request = requests[task.taskIdentifier] else { return false }
            request.data.append(data)
            requests[task.taskIdentifier] = request
            return request.data.count > request.maxBytes
        }
    }

    func complete(_ task: URLSessionTask, error: Error?) {
        guard let request = take(task) else { return }
        if let error {
            request.continuation.resume(throwing: error)
            return
        }
        guard let finalURL = request.finalURL ?? task.currentRequest?.url,
              let statusCode = request.statusCode else {
            request.continuation.resume(throwing: ModelDownloadError.transportFailed)
            return
        }
        request.continuation.resume(returning: HFHTTPResponse(
            data: request.data,
            finalURL: finalURL,
            statusCode: statusCode
        ))
    }

    func fail(_ task: URLSessionTask, error: Error) {
        guard let request = take(task) else { return }
        request.continuation.resume(throwing: error)
    }

    func cancelTask(forOriginalURL url: URL) {
        let request = lock.withLock { () -> RequestState? in
            guard let taskID = taskIDsByURL.removeValue(forKey: url) else { return nil }
            return requests.removeValue(forKey: taskID)
        }
        guard let request else { return }
        request.task.cancel()
        request.continuation.resume(throwing: ModelDownloadError.cancelled)
    }

    private func take(_ task: URLSessionTask) -> RequestState? {
        lock.withLock {
            guard let request = requests.removeValue(forKey: task.taskIdentifier) else { return nil }
            taskIDsByURL.removeValue(forKey: request.originalURL)
            return request
        }
    }

    private struct RequestState {
        let continuation: CheckedContinuation<HFHTTPResponse, Error>
        let task: URLSessionDataTask
        let maxBytes: Int
        let originalURL: URL
        var statusCode: Int?
        var finalURL: URL?
        var data = Data()
    }
}

public actor HuggingFaceModelDownloader: ModelDownloading {
    public static let metadataByteLimit = 2 * 1_024 * 1_024
    public static let maxModelFileCount = 24
    public static let maxModelFileBytes: Int64 = 16 * 1_024 * 1_024 * 1_024
    public static let maxSnapshotBytes: Int64 = 24 * 1_024 * 1_024 * 1_024

    private let transport: any HFHTTPTransport
    private let fileDownloader: any HFHubFileDownloading
    private let jsonDecoder = JSONDecoder()
    private let fileManager: FileManager

    public init(
        transport: any HFHTTPTransport = URLSessionHFHTTPTransport(),
        fileDownloader: any HFHubFileDownloading = SwiftHuggingFaceFileDownloader(),
        fileManager: FileManager = .default
    ) {
        self.transport = transport
        self.fileDownloader = fileDownloader
        self.fileManager = fileManager
    }

    public func resolve(reference: ModelRepositoryReference) async throws -> ModelDownloadPlan {
        let metadataURL = reference.apiURLWithBlobs
        let response = try await transport.metadata(from: metadataURL, maxBytes: Self.metadataByteLimit)
        guard response.statusCode == 200 else { throw ModelDownloadError.transportFailed }
        try Self.validateFinalURL(response.finalURL)
        guard response.data.count <= Self.metadataByteLimit else {
            throw ModelDownloadError.metadataTooLarge
        }
        let metadata = try jsonDecoder.decode(HuggingFaceModelMetadata.self, from: response.data)
        guard metadata.isPrivate != true, metadata.gated?.isGated != true else {
            throw ModelDownloadError.privateOrGatedRepository
        }
        guard let sha = metadata.sha, sha.count == 40, sha.allSatisfy(\.isHexDigit) else {
            throw ModelDownloadError.immutableRevisionMissing
        }
        guard let license = metadata.license?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !license.isEmpty else {
            throw ModelDownloadError.licenseUnavailable
        }
        let selected = (metadata.siblings ?? []).filter { Self.isSupportedModelPath($0.rfilename) }
        guard !selected.isEmpty else { throw ModelDownloadError.expectedSizeUnavailable }
        guard selected.count <= Self.maxModelFileCount else { throw ModelDownloadError.tooManyFiles }

        var totalSize: Int64 = 0
        let files = try selected.map { sibling -> ModelDownloadFile in
            guard let size = sibling.size, size > 0 else {
                throw ModelDownloadError.expectedSizeUnavailable
            }
            guard size <= Self.maxModelFileBytes else {
                throw ModelDownloadError.snapshotTooLarge
            }
            guard let sha256 = sibling.lfs?.sha256?.lowercased(),
                  sha256.count == 64,
                  sha256.allSatisfy(\.isHexDigit) else {
                throw ModelDownloadError.expectedHashUnavailable(sibling.rfilename)
            }
            totalSize += size
            guard totalSize <= Self.maxSnapshotBytes else {
                throw ModelDownloadError.snapshotTooLarge
            }
            let downloadURL = URL(
                string: "https://huggingface.co/\(reference.owner)/\(reference.repository)/resolve/\(sha)/\(sibling.rfilename)"
            )!
            return ModelDownloadFile(
                path: sibling.rfilename,
                sizeBytes: size,
                sha256: sha256,
                downloadURL: downloadURL
            )
        }
        let revision = try ResolvedModelRevision(
            reference: reference,
            commitSHA: sha,
            license: license,
            totalSizeBytes: totalSize
        )
        return ModelDownloadPlan(revision: revision, files: files)
    }

    public func download(
        plan: ModelDownloadPlan,
        to stagingURL: URL,
        progress: @escaping @Sendable (ModelDownloadProgress) -> Void
    ) async throws {
        try fileManager.createDirectory(at: stagingURL, withIntermediateDirectories: true)
        var completed: Int64 = 0
        do {
            for file in plan.files {
                try Task.checkCancellation()
                try Self.validateRequestURL(file.downloadURL)
                let target = try safeDestination(for: file.path, root: stagingURL)
                try fileManager.createDirectory(
                    at: target.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )

                let completedBeforeFile = completed
                let fileProgress = Progress(totalUnitCount: file.sizeBytes)
                progress(.init(completedBytes: completedBeforeFile, totalBytes: plan.expectedSizeBytes))
                let samplingTask = Task { [fileProgress] in
                    while !Task.isCancelled {
                        let downloaded = min(max(fileProgress.completedUnitCount, 0), file.sizeBytes)
                        progress(.init(
                            completedBytes: completedBeforeFile + downloaded,
                            totalBytes: plan.expectedSizeBytes
                        ))
                        do {
                            try await Task.sleep(for: .milliseconds(100))
                        } catch {
                            break
                        }
                    }
                }

                do {
                    _ = try await fileDownloader.downloadFile(
                        reference: plan.revision.reference,
                        revision: plan.revision.commitSHA,
                        path: file.path,
                        to: target,
                        progress: fileProgress
                    )
                } catch {
                    samplingTask.cancel()
                    _ = await samplingTask.result
                    throw error
                }
                samplingTask.cancel()
                _ = await samplingTask.result

                let actualSize = try target.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? -1
                guard Int64(actualSize) == file.sizeBytes else {
                    throw ModelDownloadError.integrityFailed(file.path)
                }
                guard try sha256(of: target) == file.sha256 else {
                    throw ModelDownloadError.integrityFailed(file.path)
                }
                completed += file.sizeBytes
                progress(.init(completedBytes: completed, totalBytes: plan.expectedSizeBytes))
            }
            let manifest = try VerifiedDownloadManifest(
                plan: plan,
                rootURL: stagingURL,
                fileManager: fileManager
            )
            let manifestURL = stagingURL.appendingPathComponent(VerifiedDownloadManifest.fileName)
            let manifestData = try JSONEncoder().encode(manifest)
            try manifestData.write(to: manifestURL, options: [.atomic])
        } catch {
            try? fileManager.removeItem(at: stagingURL)
            if Self.isCancellation(error) {
                throw ModelDownloadError.cancelled
            }
            throw error
        }
    }

    public static func validateRedirect(from _: URL, to target: URL) -> Bool {
        guard target.scheme?.lowercased() == "https",
              target.user == nil,
              target.password == nil,
              target.port == nil,
              let host = target.host?.lowercased() else { return false }
        return host == "huggingface.co"
            || host.hasSuffix(".cdn.hf.co")
            || host == "cdn-lfs.huggingface.co"
            || host == "cdn-lfs-us-1.huggingface.co"
            || host == "cdn-lfs-eu-1.huggingface.co"
            || host == "cas-bridge.xethub.hf.co"
            || host == "cas-server.xethub.hf.co"
    }

    public static func validateRequestURL(_ url: URL) throws {
        guard validateRedirect(from: url, to: url) else { throw ModelDownloadError.unsupportedHost }
    }

    private static func validateFinalURL(_ url: URL) throws {
        guard validateRedirect(from: url, to: url) else { throw ModelDownloadError.redirectNotAllowed }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError || Task.isCancelled { return true }
        return (error as? URLError)?.code == .cancelled
            || (error as NSError).code == NSURLErrorCancelled
    }

    private static func isSupportedModelPath(_ path: String) -> Bool {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        return isSafeRelativePath(path)
            && (ext == "gguf" || ext == "safetensors")
    }

    private static func isSafeRelativePath(_ path: String) -> Bool {
        guard !path.isEmpty,
              !path.hasPrefix("/"),
              !path.contains("\\"),
              !path.contains("//"),
              !path.lowercased().contains("%2f"),
              !path.lowercased().contains("%5c") else {
            return false
        }
        return !path.split(separator: "/", omittingEmptySubsequences: false).contains { part in
            part == "." || part == ".." || part.isEmpty
        }
    }

    private func safeDestination(for relativePath: String, root: URL) throws -> URL {
        guard Self.isSafeRelativePath(relativePath) else {
            throw ModelDownloadError.unsafeSnapshot(relativePath)
        }
        let destination = root.appendingPathComponent(relativePath).standardizedFileURL
        let rootPath = root.standardizedFileURL.path + "/"
        guard destination.path.hasPrefix(rootPath) else {
            throw ModelDownloadError.unsafeSnapshot(relativePath)
        }
        return destination
    }

    private func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let data = try handle.read(upToCount: 4 * 1_024 * 1_024) ?? Data()
            if data.isEmpty { break }
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

private struct HuggingFaceModelMetadata: Decodable {
    let sha: String?
    let isPrivate: Bool?
    let gated: GatedStatus?
    let cardData: CardData?
    let siblings: [Sibling]?

    var license: String? { cardData?.license }

    enum CodingKeys: String, CodingKey {
        case sha
        case isPrivate = "private"
        case gated
        case cardData
        case siblings
    }

    struct CardData: Decodable {
        let license: String?
    }

    struct Sibling: Decodable {
        let rfilename: String
        let size: Int64?
        let lfs: LFS?
    }

    struct LFS: Decodable {
        let sha256: String?
    }

    struct GatedStatus: Decodable {
        let isGated: Bool

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let value = try? container.decode(Bool.self) {
                isGated = value
            } else if let value = try? container.decode(String.self) {
                isGated = !value.isEmpty && value.lowercased() != "false"
            } else {
                isGated = true
            }
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
