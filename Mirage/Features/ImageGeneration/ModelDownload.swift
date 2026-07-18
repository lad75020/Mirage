import Foundation

public struct ModelDownloadProgress: Equatable, Codable, Sendable {
    public let completedBytes: Int64
    public let totalBytes: Int64?

    public init(completedBytes: Int64, totalBytes: Int64?) {
        self.completedBytes = completedBytes
        self.totalBytes = totalBytes
    }

    public var fractionCompleted: Double? {
        guard let totalBytes, totalBytes > 0 else { return nil }
        return min(max(Double(completedBytes) / Double(totalBytes), 0), 1)
    }
}

public struct ModelDownloadFile: Equatable, Codable, Sendable {
    public let path: String
    public let sizeBytes: Int64
    public let sha256: String?
    public let downloadURL: URL

    public init(path: String, sizeBytes: Int64, sha256: String?, downloadURL: URL) {
        self.path = path
        self.sizeBytes = sizeBytes
        self.sha256 = sha256?.lowercased()
        self.downloadURL = downloadURL
    }
}

public struct ModelDownloadPlan: Equatable, Codable, Sendable {
    public let revision: ResolvedModelRevision
    public let files: [ModelDownloadFile]
    public let descriptor: ModelDescriptor?

    public init(
        revision: ResolvedModelRevision,
        files: [ModelDownloadFile],
        descriptor: ModelDescriptor? = nil
    ) {
        self.revision = revision
        self.files = files
        self.descriptor = descriptor
    }

    public var expectedSizeBytes: Int64 {
        files.reduce(0) { $0 + $1.sizeBytes }
    }
}

struct VerifiedDownloadManifest: Equatable, Codable, Sendable {
    static let fileName = ".mirage-download-verified.json"

    struct File: Equatable, Codable, Sendable {
        let path: String
        let sizeBytes: Int64
        let sha256: String
        let modificationTime: TimeInterval
    }

    let commitSHA: String
    let files: [File]

    init(plan: ModelDownloadPlan, rootURL: URL, fileManager: FileManager = .default) throws {
        self.commitSHA = plan.revision.commitSHA
        self.files = try plan.files.map { file in
            guard let sha256 = file.sha256 else {
                throw ModelDownloadError.integrityFailed(file.path)
            }
            let url = rootURL.appendingPathComponent(file.path)
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            guard let modified = attributes[.modificationDate] as? Date else {
                throw ModelDownloadError.integrityFailed(file.path)
            }
            return File(
                path: file.path,
                sizeBytes: file.sizeBytes,
                sha256: sha256,
                modificationTime: modified.timeIntervalSinceReferenceDate
            )
        }
    }

    func matches(
        _ plan: ModelDownloadPlan,
        rootURL: URL,
        fileManager: FileManager = .default
    ) -> Bool {
        guard let current = try? Self(plan: plan, rootURL: rootURL, fileManager: fileManager) else {
            return false
        }
        return self == current
    }
}

public enum ModelDownloadState: Equatable, Codable, Sendable {
    case notDownloaded
    case resolving(reference: ModelRepositoryReference)
    case awaitingConfirmation(revision: ResolvedModelRevision, sizeBytes: Int64?, license: String?)
    case downloading(reference: ModelRepositoryReference, progress: ModelDownloadProgress)
    case validating(reference: ModelRepositoryReference)
    case downloaded(LocalModelSnapshot)
    case cancelled(reference: ModelRepositoryReference)
    case failed(reference: ModelRepositoryReference?, reason: ModelDownloadError)
}

public enum ModelDownloadError: Error, Equatable, Codable, Sendable {
    case invalidReference
    case unsupportedHost
    case redirectNotAllowed
    case immutableRevisionMissing
    case licenseUnavailable
    case expectedSizeUnavailable
    case expectedHashUnavailable(String)
    case metadataTooLarge
    case privateOrGatedRepository
    case tooManyFiles
    case snapshotTooLarge
    case lowStorage(required: Int64, available: Int64)
    case cancelled
    case transportFailed
    case integrityFailed(String)
    case unsafeSnapshot(String)
    case fileSystemFailure
}

public struct LocalModelSnapshot: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let reference: ModelRepositoryReference
    public let commitSHA: String
    public let folderName: String
    public let folderURL: URL
    public let files: [ModelDownloadFile]
    public let license: String?
    public let compatibility: ModelCompatibility
    public let descriptor: ModelDescriptor?

    public init(
        reference: ModelRepositoryReference,
        commitSHA: String,
        folderName: String,
        folderURL: URL,
        files: [ModelDownloadFile],
        license: String?,
        compatibility: ModelCompatibility,
        descriptor: ModelDescriptor? = nil
    ) {
        self.reference = reference
        self.commitSHA = commitSHA.lowercased()
        self.folderName = folderName
        self.folderURL = folderURL
        self.files = files
        self.license = license?.lowercased()
        self.compatibility = compatibility
        self.descriptor = descriptor
        self.id = "\(reference.id)@\(commitSHA.lowercased())"
    }
}
