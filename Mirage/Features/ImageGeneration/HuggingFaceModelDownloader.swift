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

public struct HFDownloadResponse: Sendable {
    public let finalURL: URL
    public let statusCode: Int
    public let bytesWritten: Int64

    public init(finalURL: URL, statusCode: Int, bytesWritten: Int64) {
        self.finalURL = finalURL
        self.statusCode = statusCode
        self.bytesWritten = bytesWritten
    }
}

public protocol HFHTTPTransport: Sendable {
    func metadata(from url: URL, maxBytes: Int) async throws -> HFHTTPResponse
    func download(
        from url: URL,
        to destinationURL: URL,
        expectedBytes: Int64,
        progress: @escaping @Sendable (Int64) -> Void
    ) async throws -> HFDownloadResponse
}

public final class URLSessionHFHTTPTransport: NSObject, HFHTTPTransport, @unchecked Sendable {
    private let session: URLSession
    private let state = URLSessionTransportState()

    public override init() {
        let configuration = URLSessionConfiguration.default
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        let delegate = URLSessionSecurityDelegate(state: state)
        self.session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        super.init()
        delegate.owner = self
    }

    public func metadata(from url: URL, maxBytes: Int) async throws -> HFHTTPResponse {
        try HuggingFaceModelDownloader.validateRequestURL(url)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                var request = URLRequest(url: url)
                request.cachePolicy = .reloadIgnoringLocalCacheData
                let task = session.dataTask(with: request)
                state.registerMetadata(
                    continuation: continuation,
                    task: task,
                    maxBytes: maxBytes,
                    originalURL: url
                )
                task.resume()
            }
        } onCancel: {
            state.cancelTask(forOriginalURL: url)
        }
    }

    public func download(
        from url: URL,
        to destinationURL: URL,
        expectedBytes: Int64,
        progress: @escaping @Sendable (Int64) -> Void
    ) async throws -> HFDownloadResponse {
        try HuggingFaceModelDownloader.validateRequestURL(url)
        try? FileManager.default.removeItem(at: destinationURL)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                var request = URLRequest(url: url)
                request.cachePolicy = .reloadIgnoringLocalCacheData
                let task = session.downloadTask(with: request)
                state.registerDownload(
                    continuation: continuation,
                    task: task,
                    originalURL: url,
                    destinationURL: destinationURL,
                    expectedBytes: expectedBytes,
                    progress: progress
                )
                task.resume()
            }
        } onCancel: {
            try? FileManager.default.removeItem(at: destinationURL)
            state.cancelTask(forOriginalURL: url)
        }
    }
}

private final class URLSessionSecurityDelegate: NSObject, URLSessionDataDelegate, URLSessionDownloadDelegate, @unchecked Sendable {
    weak var owner: URLSessionHFHTTPTransport?
    private let state: URLSessionTransportState

    init(state: URLSessionTransportState) {
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
        state.receiveMetadataResponse(dataTask, response: http)
        completionHandler(.allow)
    }

    func urlSession(_: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        state.appendMetadata(dataTask, data: data)
    }

    func urlSession(
        _: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite _: Int64
    ) {
        if bytesWritten > 0 {
            state.reportDownloadProgress(downloadTask, totalBytesWritten: totalBytesWritten)
        }
    }

    func urlSession(
        _: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        state.finishDownload(downloadTask, temporaryURL: location)
    }

    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        state.complete(task, error: error)
    }
}

private final class URLSessionTransportState: @unchecked Sendable {
    private let lock = NSLock()
    private var metadata: [Int: MetadataState] = [:]
    private var downloads: [Int: DownloadState] = [:]
    private var taskIDsByURL: [URL: Int] = [:]

    func registerMetadata(
        continuation: CheckedContinuation<HFHTTPResponse, Error>,
        task: URLSessionDataTask,
        maxBytes: Int,
        originalURL: URL
    ) {
        lock.withLock {
            metadata[task.taskIdentifier] = MetadataState(
                continuation: continuation,
                task: task,
                maxBytes: maxBytes,
                originalURL: originalURL
            )
            taskIDsByURL[originalURL] = task.taskIdentifier
        }
    }

    func registerDownload(
        continuation: CheckedContinuation<HFDownloadResponse, Error>,
        task: URLSessionDownloadTask,
        originalURL: URL,
        destinationURL: URL,
        expectedBytes: Int64,
        progress: @escaping @Sendable (Int64) -> Void
    ) {
        lock.withLock {
            downloads[task.taskIdentifier] = DownloadState(
                continuation: continuation,
                task: task,
                originalURL: originalURL,
                destinationURL: destinationURL,
                expectedBytes: expectedBytes,
                progress: progress
            )
            taskIDsByURL[originalURL] = task.taskIdentifier
        }
    }

    func receiveMetadataResponse(_ task: URLSessionDataTask, response: HTTPURLResponse) {
        lock.withLock {
            metadata[task.taskIdentifier]?.statusCode = response.statusCode
            metadata[task.taskIdentifier]?.finalURL = response.url ?? task.currentRequest?.url
        }
    }

    func appendMetadata(_ task: URLSessionDataTask, data: Data) {
        let shouldCancel = lock.withLock {
            guard var state = metadata[task.taskIdentifier] else { return false }
            state.data.append(data)
            metadata[task.taskIdentifier] = state
            return state.data.count > state.maxBytes
        }
        if shouldCancel {
            fail(task, error: ModelDownloadError.metadataTooLarge)
            task.cancel()
        }
    }

    func reportDownloadProgress(_ task: URLSessionDownloadTask, totalBytesWritten: Int64) {
        let progress = lock.withLock { downloads[task.taskIdentifier]?.progress }
        progress?(totalBytesWritten)
    }

    func finishDownload(_ task: URLSessionDownloadTask, temporaryURL: URL) {
        do {
            let state = try lock.withLock {
                guard let state = downloads[task.taskIdentifier] else {
                    throw ModelDownloadError.transportFailed
                }
                return state
            }
            try FileManager.default.createDirectory(
                at: state.destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? FileManager.default.removeItem(at: state.destinationURL)
            try FileManager.default.moveItem(at: temporaryURL, to: state.destinationURL)
        } catch {
            fail(task, error: error)
        }
    }

    func complete(_ task: URLSessionTask, error: Error?) {
        if let error {
            let storedError = lock.withLock {
                metadata[task.taskIdentifier]?.error ?? downloads[task.taskIdentifier]?.error
            }
            fail(task, error: storedError ?? error)
            return
        }
        if let state = lock.withLock({ metadata.removeValue(forKey: task.taskIdentifier) }) {
            cleanup(originalURL: state.originalURL)
            guard let finalURL = state.finalURL ?? task.currentRequest?.url,
                  let statusCode = state.statusCode else {
                state.continuation.resume(throwing: ModelDownloadError.transportFailed)
                return
            }
            state.continuation.resume(returning: HFHTTPResponse(
                data: state.data,
                finalURL: finalURL,
                statusCode: statusCode
            ))
            return
        }
        if let state = lock.withLock({ downloads.removeValue(forKey: task.taskIdentifier) }) {
            cleanup(originalURL: state.originalURL)
            guard let finalURL = task.response?.url ?? task.currentRequest?.url,
                  let http = task.response as? HTTPURLResponse else {
                state.continuation.resume(throwing: ModelDownloadError.transportFailed)
                return
            }
            state.continuation.resume(returning: HFDownloadResponse(
                finalURL: finalURL,
                statusCode: http.statusCode,
                bytesWritten: state.expectedBytes
            ))
        }
    }

    func fail(_ task: URLSessionTask, error: Error) {
        if var state = lock.withLock({ metadata.removeValue(forKey: task.taskIdentifier) }) {
            cleanup(originalURL: state.originalURL)
            state.error = error
            state.continuation.resume(throwing: error)
            return
        }
        if var state = lock.withLock({ downloads.removeValue(forKey: task.taskIdentifier) }) {
            cleanup(originalURL: state.originalURL)
            try? FileManager.default.removeItem(at: state.destinationURL)
            state.error = error
            state.continuation.resume(throwing: error)
        }
    }

    func cancelTask(forOriginalURL url: URL) {
        let taskID = lock.withLock { taskIDsByURL[url] }
        guard let taskID else { return }
        if let state = lock.withLock({ metadata.removeValue(forKey: taskID) }) {
            cleanup(originalURL: state.originalURL)
            state.task.cancel()
            state.continuation.resume(throwing: ModelDownloadError.cancelled)
        }
        if let state = lock.withLock({ downloads.removeValue(forKey: taskID) }) {
            cleanup(originalURL: state.originalURL)
            state.task.cancel()
            try? FileManager.default.removeItem(at: state.destinationURL)
            state.continuation.resume(throwing: ModelDownloadError.cancelled)
        }
    }

    private func cleanup(originalURL: URL) {
        _ = lock.withLock {
            taskIDsByURL.removeValue(forKey: originalURL)
        }
    }

    private struct MetadataState {
        let continuation: CheckedContinuation<HFHTTPResponse, Error>
        let task: URLSessionTask
        let maxBytes: Int
        let originalURL: URL
        var statusCode: Int?
        var finalURL: URL?
        var data = Data()
        var error: Error?
    }

    private struct DownloadState {
        let continuation: CheckedContinuation<HFDownloadResponse, Error>
        let task: URLSessionTask
        let originalURL: URL
        let destinationURL: URL
        let expectedBytes: Int64
        let progress: @Sendable (Int64) -> Void
        var error: Error?
    }
}

public actor HuggingFaceModelDownloader: ModelDownloading {
    public static let metadataByteLimit = 2 * 1_024 * 1_024
    public static let maxModelFileCount = 24
    public static let maxModelFileBytes: Int64 = 16 * 1_024 * 1_024 * 1_024
    public static let maxSnapshotBytes: Int64 = 24 * 1_024 * 1_024 * 1_024

    private let transport: any HFHTTPTransport
    private let jsonDecoder = JSONDecoder()
    private let fileManager: FileManager

    public init(
        transport: any HFHTTPTransport = URLSessionHFHTTPTransport(),
        fileManager: FileManager = .default
    ) {
        self.transport = transport
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
                let response = try await transport.download(
                    from: file.downloadURL,
                    to: target,
                    expectedBytes: file.sizeBytes
                ) { fileCompleted in
                    progress(.init(
                        completedBytes: completedBeforeFile + min(max(fileCompleted, 0), file.sizeBytes),
                        totalBytes: plan.expectedSizeBytes
                    ))
                }
                try Self.validateFinalURL(response.finalURL)
                guard response.statusCode == 200 else { throw ModelDownloadError.transportFailed }
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
        } catch is CancellationError {
            try? fileManager.removeItem(at: stagingURL)
            throw ModelDownloadError.cancelled
        } catch {
            try? fileManager.removeItem(at: stagingURL)
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
            || host == "cdn-lfs.huggingface.co"
            || host == "cdn-lfs-us-1.huggingface.co"
            || host == "cdn-lfs-eu-1.huggingface.co"
            || host == "cdn-lfs.hf.co"
            || host == "cas-bridge.xethub.hf.co"
    }

    public static func validateRequestURL(_ url: URL) throws {
        guard validateRedirect(from: url, to: url) else { throw ModelDownloadError.unsupportedHost }
    }

    private static func validateFinalURL(_ url: URL) throws {
        guard validateRedirect(from: url, to: url) else { throw ModelDownloadError.redirectNotAllowed }
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
              !path.contains("%2f"),
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
