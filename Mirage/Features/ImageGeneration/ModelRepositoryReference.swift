import Foundation

public enum ModelRepositoryReferenceError: Error, Equatable, Sendable {
    case empty
    case malformed
    case unsupportedHost
    case credentialsNotAllowed
    case queryOrFragmentNotAllowed
    case privateOrGatedNotSupported
}

public struct ModelRepositoryReference: Hashable, Codable, Sendable, CustomStringConvertible {
    public let owner: String
    public let repository: String

    public var id: String { "\(owner)/\(repository)" }
    public var description: String { id }
    public var apiURL: URL {
        URL(string: "https://huggingface.co/api/models/\(owner)/\(repository)")!
    }
    public var apiURLWithBlobs: URL {
        URL(string: "https://huggingface.co/api/models/\(owner)/\(repository)?blobs=true")!
    }

    public init(owner: String, repository: String) throws {
        let owner = owner.trimmingCharacters(in: .whitespacesAndNewlines)
        let repository = repository.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !owner.isEmpty, !repository.isEmpty else { throw ModelRepositoryReferenceError.empty }
        guard Self.isValidComponent(owner), Self.isValidComponent(repository) else {
            throw ModelRepositoryReferenceError.malformed
        }
        self.owner = owner
        self.repository = repository
    }

    public init(_ rawValue: String) throws {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ModelRepositoryReferenceError.empty }
        if trimmed.contains("://") {
            try self.init(urlString: trimmed)
            return
        }
        guard !trimmed.contains("?"), !trimmed.contains("#") else {
            throw ModelRepositoryReferenceError.queryOrFragmentNotAllowed
        }
        let parts = trimmed.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 2 else { throw ModelRepositoryReferenceError.malformed }
        try self.init(owner: parts[0], repository: parts[1])
    }

    public init(urlString: String) throws {
        guard let components = URLComponents(string: urlString),
              components.scheme?.lowercased() == "https",
              let host = components.host?.lowercased(),
              host == "huggingface.co" else {
            throw ModelRepositoryReferenceError.unsupportedHost
        }
        guard components.user == nil, components.password == nil else {
            throw ModelRepositoryReferenceError.credentialsNotAllowed
        }
        guard components.port == nil else {
            throw ModelRepositoryReferenceError.unsupportedHost
        }
        guard components.query == nil, components.fragment == nil else {
            throw ModelRepositoryReferenceError.queryOrFragmentNotAllowed
        }
        guard !urlString.lowercased().contains("%2f"),
              !urlString.lowercased().contains("%5c") else {
            throw ModelRepositoryReferenceError.malformed
        }
        let pathParts = components.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
        guard pathParts.count == 2 else { throw ModelRepositoryReferenceError.malformed }
        guard components.path == "/\(pathParts[0])/\(pathParts[1])"
            || components.path == "/\(pathParts[0])/\(pathParts[1])/" else {
            throw ModelRepositoryReferenceError.malformed
        }
        try self.init(owner: pathParts[0], repository: pathParts[1])
    }

    private static func isValidComponent(_ value: String) -> Bool {
        guard (1...96).contains(value.count) else { return false }
        guard !value.hasPrefix("."), !value.hasSuffix("."), !value.contains("..") else { return false }
        return value.allSatisfy { character in
            character.isLetter || character.isNumber || character == "-" || character == "_" || character == "."
        }
    }

}

public struct ResolvedModelRevision: Equatable, Codable, Sendable {
    public let reference: ModelRepositoryReference
    public let commitSHA: String
    public let license: String?
    public let totalSizeBytes: Int64?

    public init(
        reference: ModelRepositoryReference,
        commitSHA: String,
        license: String?,
        totalSizeBytes: Int64?
    ) throws {
        guard commitSHA.count == 40, commitSHA.allSatisfy(\.isHexDigit) else {
            throw ModelRepositoryReferenceError.malformed
        }
        self.reference = reference
        self.commitSHA = commitSHA.lowercased()
        self.license = license?.lowercased()
        self.totalSizeBytes = totalSizeBytes
    }
}

public enum ModelCompatibility: Equatable, Codable, Sendable {
    case compatible(profile: GenerationProfile)
    case incompatible(reason: String)
    case unknownCustomRepository

    public var isSelectable: Bool {
        if case .compatible = self { return true }
        return false
    }
}
