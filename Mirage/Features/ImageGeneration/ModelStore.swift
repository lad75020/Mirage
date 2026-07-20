import CryptoKit
import Foundation

public enum ModelStoreError: Error, Equatable, Sendable {
    case lowStorage(required: Int64, available: Int64)
    case unsafePath(String)
    case caseCollision(String)
    case executablePayload(String)
    case archivePayload(String)
    case symlinkEscape(String)
    case integrityFailed(String)
    case unexpectedFile(String)
    case hiddenFile(String)
    case tooManyFiles
    case snapshotTooLarge
    case fileSystemFailure
}

public actor ModelStore: ModelSnapshotStoring {
    public nonisolated let modelRootURL: URL
    private let stagingRootURL: URL
    private let fileManager: FileManager
    private let availableSpaceProvider: @Sendable () -> Int64

    public init(
        documentsURL: URL? = nil,
        stagingURL: URL? = nil,
        fileManager: FileManager = .default,
        availableSpaceProvider: (@Sendable () -> Int64)? = nil
    ) throws {
        self.fileManager = fileManager
        let documents = documentsURL ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.modelRootURL = documents
            .appendingPathComponent("Mirage Models", isDirectory: true)
            .standardizedFileURL
        self.stagingRootURL = stagingURL ?? fileManager.temporaryDirectory
            .appendingPathComponent("MirageModelStaging", isDirectory: true)
            .standardizedFileURL
        self.availableSpaceProvider = availableSpaceProvider ?? {
            let values = try? documents.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            return values?.volumeAvailableCapacityForImportantUsage ?? 0
        }
        try fileManager.createDirectory(at: modelRootURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: stagingRootURL, withIntermediateDirectories: true)
        try Self.setProtection(on: modelRootURL, recursive: false, fileManager: fileManager)
        try Self.setProtection(on: stagingRootURL, recursive: false, fileManager: fileManager)
    }

    public func stagingURL(for reference: ModelRepositoryReference) async throws -> URL {
        let folder = Self.safeFolderName(for: reference)
        let url = stagingRootURL
            .appendingPathComponent(folder + "-" + UUID().uuidString, isDirectory: true)
            .standardizedFileURL
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        try setProtection(on: url, recursive: false)
        return url
    }

    public func discardStagingURL(_ url: URL) async {
        let standardized = url.standardizedFileURL
        let rootPath = stagingRootURL.standardizedFileURL.path.hasSuffix("/")
            ? stagingRootURL.standardizedFileURL.path
            : stagingRootURL.standardizedFileURL.path + "/"
        guard standardized.path.hasPrefix(rootPath) else { return }
        try? fileManager.removeItem(at: standardized)
    }

    public func validateCanStore(plan: ModelDownloadPlan) async throws {
        try ensureSufficientSpace(for: plan)
    }

    public func promote(plan: ModelDownloadPlan, from stagingURL: URL) async throws -> LocalModelSnapshot {
        try ensureSufficientSpace(for: plan)
        try ensureOwnedStagingURL(stagingURL)
        let trustsDownloadedHashes = verificationManifest(at: stagingURL)?.matches(
            plan,
            rootURL: stagingURL,
            fileManager: fileManager
        ) == true
        try validate(
            folderURL: stagingURL,
            files: plan.files,
            allowMetadata: false,
            allowVerificationManifest: trustsDownloadedHashes,
            hashContents: !trustsDownloadedHashes
        )

        let folder = Self.safeFolderName(for: plan.revision.reference)
        let destination = modelRootURL.appendingPathComponent(folder, isDirectory: true)
        let replacement = modelRootURL.appendingPathComponent(".\(folder).replacement-\(UUID().uuidString)", isDirectory: true)
        do {
            try moveDirectoryContents(from: stagingURL, to: replacement, files: plan.files)
            try? fileManager.removeItem(at: replacement.appendingPathComponent(VerifiedDownloadManifest.fileName))
            try writeMetadata(plan: plan, folderName: folder, root: replacement)
            try validate(
                folderURL: replacement,
                files: plan.files,
                allowMetadata: true,
                allowVerificationManifest: false,
                hashContents: false
            )
            try setProtection(on: replacement, recursive: true)
            if fileManager.fileExists(atPath: destination.path) {
                _ = try fileManager.replaceItemAt(
                    destination,
                    withItemAt: replacement,
                    backupItemName: nil,
                    options: []
                )
            } else {
                try fileManager.moveItem(at: replacement, to: destination)
            }
            try setProtection(on: destination, recursive: true)
            try validate(
                folderURL: destination,
                files: plan.files,
                allowMetadata: true,
                allowVerificationManifest: false,
                hashContents: false
            )
            let provisionalSnapshot = LocalModelSnapshot(
                reference: plan.revision.reference,
                commitSHA: plan.revision.commitSHA,
                folderName: folder,
                folderURL: destination,
                files: plan.files,
                license: plan.revision.license,
                compatibility: .unknownCustomRepository,
                descriptor: plan.descriptor
            )
            return LocalModelSnapshot(
                reference: provisionalSnapshot.reference,
                commitSHA: provisionalSnapshot.commitSHA,
                folderName: provisionalSnapshot.folderName,
                folderURL: provisionalSnapshot.folderURL,
                files: provisionalSnapshot.files,
                license: provisionalSnapshot.license,
                compatibility: ModelCatalog.compatibility(for: provisionalSnapshot),
                descriptor: provisionalSnapshot.descriptor
            )
        } catch {
            try? fileManager.removeItem(at: replacement)
            throw error
        }
    }

    public func refreshSnapshots() async -> [LocalModelSnapshot] {
        guard let children = try? fileManager.contentsOfDirectory(
            at: modelRootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return children.compactMap { folder in
            guard let resourceValues = try? folder.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                  resourceValues.isDirectory == true,
                  resourceValues.isSymbolicLink != true,
                  let data = try? Data(contentsOf: folder.appendingPathComponent(".mirage-snapshot.json")),
                  data.count <= 256 * 1_024,
                  let metadata = try? JSONDecoder().decode(SnapshotMetadata.self, from: data),
                  let reference = try? ModelRepositoryReference(owner: metadata.owner, repository: metadata.repository),
                  metadata.folderName == folder.lastPathComponent else {
                return nil
            }
            let snapshot = LocalModelSnapshot(
                reference: reference,
                commitSHA: metadata.commitSHA,
                folderName: folder.lastPathComponent,
                folderURL: folder,
                files: metadata.files,
                license: metadata.license,
                compatibility: .unknownCustomRepository,
                descriptor: metadata.descriptor
            )
            guard (try? validate(
                folderURL: folder,
                files: metadata.files,
                allowMetadata: true,
                allowVerificationManifest: false,
                hashContents: true
            )) != nil else {
                return LocalModelSnapshot(
                    reference: reference,
                    commitSHA: metadata.commitSHA,
                    folderName: folder.lastPathComponent,
                    folderURL: folder,
                    files: metadata.files,
                    license: metadata.license,
                    compatibility: .incompatible(reason: "Files changed in Files."),
                    descriptor: metadata.descriptor
                )
            }
            return LocalModelSnapshot(
                reference: snapshot.reference,
                commitSHA: snapshot.commitSHA,
                folderName: snapshot.folderName,
                folderURL: snapshot.folderURL,
                files: snapshot.files,
                license: snapshot.license,
                compatibility: ModelCatalog.compatibility(for: snapshot),
                descriptor: snapshot.descriptor
            )
        }
    }

    public func availableBytes() -> Int64 {
        availableSpaceProvider()
    }

    public static func safeFolderName(for reference: ModelRepositoryReference) -> String {
        let readable = "\(reference.owner)--\(reference.repository)"
            .lowercased()
            .map { character in
                if character.isLetter || character.isNumber || character == "-" || character == "_" {
                    return character
                }
                return "-"
            }
            .reduce(into: "") { $0.append($1) }
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        let slug = readable.isEmpty ? "model" : String(readable.prefix(80))
        let digest = SHA256.hash(data: Data(reference.id.utf8))
            .prefix(8)
            .map { String(format: "%02x", $0) }
            .joined()
        return "\(slug)-\(digest)"
    }

    private func ensureOwnedStagingURL(_ url: URL) throws {
        let root = stagingRootURL.standardizedFileURL
        let candidate = url.standardizedFileURL
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard candidate.path.hasPrefix(rootPath), candidate.deletingLastPathComponent() == root else {
            throw ModelStoreError.unsafePath(url.path)
        }
    }

    private func verificationManifest(at stagingURL: URL) -> VerifiedDownloadManifest? {
        let url = stagingURL.appendingPathComponent(VerifiedDownloadManifest.fileName)
        guard let data = try? Data(contentsOf: url), data.count <= 64 * 1_024 else { return nil }
        return try? JSONDecoder().decode(VerifiedDownloadManifest.self, from: data)
    }

    private func moveDirectoryContents(
        from stagingURL: URL,
        to replacement: URL,
        files: [ModelDownloadFile]
    ) throws {
        do {
            try fileManager.moveItem(at: stagingURL, to: replacement)
            return
        } catch {
            try fileManager.createDirectory(at: replacement, withIntermediateDirectories: true)
        }

        for file in files {
            let source = try containedURL(root: stagingURL, relativePath: file.path)
            let target = try containedURL(root: replacement, relativePath: file.path)
            try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try moveOrCopyItem(from: source, to: target)
        }
        let manifestSource = stagingURL.appendingPathComponent(VerifiedDownloadManifest.fileName)
        if fileManager.fileExists(atPath: manifestSource.path) {
            try moveOrCopyItem(
                from: manifestSource,
                to: replacement.appendingPathComponent(VerifiedDownloadManifest.fileName)
            )
        }
        try? fileManager.removeItem(at: stagingURL)
    }

    private func moveOrCopyItem(from source: URL, to destination: URL) throws {
        do {
            try fileManager.moveItem(at: source, to: destination)
        } catch {
            try fileManager.copyItem(at: source, to: destination)
            try fileManager.removeItem(at: source)
        }
    }

    private func ensureSufficientSpace(for plan: ModelDownloadPlan) throws {
        guard plan.files.count <= HuggingFaceModelDownloader.maxModelFileCount else {
            throw ModelStoreError.tooManyFiles
        }
        guard plan.files.allSatisfy({ $0.sizeBytes <= HuggingFaceModelDownloader.maxModelFileBytes }),
              plan.expectedSizeBytes <= HuggingFaceModelDownloader.maxSnapshotBytes else {
            throw ModelStoreError.snapshotTooLarge
        }
        let available = availableBytes()
        guard available >= plan.expectedSizeBytes else {
            throw ModelStoreError.lowStorage(required: plan.expectedSizeBytes, available: available)
        }
    }

    private func validate(
        folderURL: URL,
        files: [ModelDownloadFile],
        allowMetadata: Bool,
        allowVerificationManifest: Bool,
        hashContents: Bool
    ) throws {
        let expectedPaths = Set(files.map(\.path))
        let expectedLowered = files.map { $0.path.lowercased() }
        guard Set(expectedLowered).count == expectedLowered.count else {
            throw ModelStoreError.caseCollision("duplicate path")
        }
        guard files.count <= HuggingFaceModelDownloader.maxModelFileCount else {
            throw ModelStoreError.tooManyFiles
        }
        guard files.reduce(Int64(0), { $0 + $1.sizeBytes }) <= HuggingFaceModelDownloader.maxSnapshotBytes else {
            throw ModelStoreError.snapshotTooLarge
        }
        for file in files {
            _ = try containedURL(root: folderURL, relativePath: file.path)
            let ext = URL(fileURLWithPath: file.path).pathExtension.lowercased()
            guard !["zip", "tar", "gz", "xz", "7z", "rar"].contains(ext) else {
                throw ModelStoreError.archivePayload(file.path)
            }
            guard ext == "gguf" || ext == "safetensors" else {
                throw ModelStoreError.unsafePath(file.path)
            }
            guard file.sizeBytes > 0,
                  file.sizeBytes <= HuggingFaceModelDownloader.maxModelFileBytes else {
                throw ModelStoreError.snapshotTooLarge
            }
            guard file.sha256?.count == 64,
                  file.sha256?.allSatisfy(\.isHexDigit) == true else {
                throw ModelStoreError.integrityFailed(file.path)
            }
        }

        var actualLowered = Set<String>()
        var actualFileCount = 0
        var actualTotalSize: Int64 = 0
        let root = folderURL.standardizedFileURL
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .isExecutableKey, .fileSizeKey],
            options: []
        ) else {
            throw ModelStoreError.fileSystemFailure
        }
        for case let url as URL in enumerator {
            let relativePath = try relativePath(for: url, root: root)
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .isExecutableKey, .fileSizeKey])
            guard values.isSymbolicLink != true else {
                throw ModelStoreError.symlinkEscape(relativePath)
            }
            if values.isDirectory == true {
                guard !url.lastPathComponent.hasPrefix(".") else {
                    throw ModelStoreError.hiddenFile(relativePath)
                }
                continue
            }
            guard values.isRegularFile == true else {
                throw ModelStoreError.unsafePath(relativePath)
            }
            guard !url.lastPathComponent.hasPrefix(".") else {
                if allowMetadata, relativePath == ".mirage-snapshot.json" {
                    continue
                }
                if allowVerificationManifest, relativePath == VerifiedDownloadManifest.fileName {
                    continue
                }
                throw ModelStoreError.hiddenFile(relativePath)
            }
            guard expectedPaths.contains(relativePath) else {
                throw ModelStoreError.unexpectedFile(relativePath)
            }
            let lowered = relativePath.lowercased()
            guard actualLowered.insert(lowered).inserted else {
                throw ModelStoreError.caseCollision(relativePath)
            }
            try validateAllowedFile(url: url, relativePath: relativePath, values: values)
            actualFileCount += 1
            let fileSize = Int64(values.fileSize ?? -1)
            actualTotalSize += fileSize
            guard actualFileCount <= HuggingFaceModelDownloader.maxModelFileCount else {
                throw ModelStoreError.tooManyFiles
            }
            guard fileSize <= HuggingFaceModelDownloader.maxModelFileBytes,
                  actualTotalSize <= HuggingFaceModelDownloader.maxSnapshotBytes else {
                throw ModelStoreError.snapshotTooLarge
            }
        }

        guard actualFileCount == files.count else {
            throw ModelStoreError.integrityFailed("file count")
        }
        for file in files {
            let url = try containedURL(root: folderURL, relativePath: file.path)
            guard fileManager.fileExists(atPath: url.path) else {
                throw ModelStoreError.integrityFailed(file.path)
            }
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
            if let actualSize = resourceValues.fileSize, Int64(actualSize) != file.sizeBytes {
                throw ModelStoreError.integrityFailed(file.path)
            }
            if hashContents {
                guard let expectedHash = file.sha256, try sha256(of: url) == expectedHash else {
                    throw ModelStoreError.integrityFailed(file.path)
                }
            }
        }
    }

    private func validateAllowedFile(url: URL, relativePath: String, values: URLResourceValues) throws {
        _ = try containedURL(root: url.deletingLastPathComponent(), relativePath: url.lastPathComponent)
        let ext = url.pathExtension.lowercased()
        guard !["zip", "tar", "gz", "xz", "7z", "rar"].contains(ext) else {
            throw ModelStoreError.archivePayload(relativePath)
        }
        guard ext == "gguf" || ext == "safetensors" else {
            throw ModelStoreError.unsafePath(relativePath)
        }
        guard values.isExecutable != true else {
            throw ModelStoreError.executablePayload(relativePath)
        }
    }

    private func containedURL(root: URL, relativePath: String) throws -> URL {
        guard isSafeRelativePath(relativePath) else {
            throw ModelStoreError.unsafePath(relativePath)
        }
        let candidate = root.appendingPathComponent(relativePath).standardizedFileURL
        let resolvedRoot = root.resolvingSymlinksInPath().standardizedFileURL
        let resolvedCandidate = candidate.resolvingSymlinksInPath().standardizedFileURL
        let rootPath = resolvedRoot.path.hasSuffix("/") ? resolvedRoot.path : resolvedRoot.path + "/"
        guard resolvedCandidate.path.hasPrefix(rootPath) else {
            throw ModelStoreError.symlinkEscape(relativePath)
        }
        return candidate
    }

    private func isSafeRelativePath(_ path: String) -> Bool {
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

    private func relativePath(for url: URL, root: URL) throws -> String {
        let rootPath = root.standardizedFileURL.path.hasSuffix("/")
            ? root.standardizedFileURL.path
            : root.standardizedFileURL.path + "/"
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(rootPath) else {
            throw ModelStoreError.symlinkEscape(url.lastPathComponent)
        }
        return String(path.dropFirst(rootPath.count))
    }

    private func writeMetadata(plan: ModelDownloadPlan, folderName: String, root: URL) throws {
        let metadata = SnapshotMetadata(
            owner: plan.revision.reference.owner,
            repository: plan.revision.reference.repository,
            commitSHA: plan.revision.commitSHA,
            folderName: folderName,
            license: plan.revision.license,
            files: plan.files,
            descriptor: plan.descriptor
        )
        let data = try JSONEncoder().encode(metadata)
        let url = root.appendingPathComponent(".mirage-snapshot.json")
        try data.write(to: url, options: [.atomic])
        try setProtection(on: url, recursive: false)
    }

    private func setProtection(on url: URL, recursive: Bool) throws {
        try Self.setProtection(on: url, recursive: recursive, fileManager: fileManager)
    }

    private static func setProtection(on url: URL, recursive: Bool, fileManager: FileManager) throws {
        #if os(iOS)
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
        guard recursive,
              let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: nil) else {
            return
        }
        for case let child as URL in enumerator {
            try fileManager.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: child.path
            )
        }
        #else
        _ = url
        _ = recursive
        _ = fileManager
        #endif
    }

    private func sha256(of url: URL) throws -> String {
        try boundedFileSHA256(of: url)
    }
}

/// Computes a file digest without retaining Foundation read buffers for the
/// duration of a synchronous hash operation.
func boundedFileSHA256(of url: URL) throws -> String {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }

    var hasher = SHA256()
    let chunkSize = 4 * 1_024 * 1_024
    while try autoreleasepool(invoking: {
        guard let data = try handle.read(upToCount: chunkSize), !data.isEmpty else {
            return false
        }
        hasher.update(data: data)
        return true
    }) {}

    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
}

private struct SnapshotMetadata: Codable {
    let owner: String
    let repository: String
    let commitSHA: String
    let folderName: String
    let license: String?
    let files: [ModelDownloadFile]
    let descriptor: ModelDescriptor?
}
