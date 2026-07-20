import CryptoKit
import Foundation
#if os(iOS)
import UIKit
#endif

public enum ModelResolutionError: Error, Equatable, Sendable {
    case modelUnavailable
    case invalidPath
    case missingFile
    case integrityFailed
    case fileSystemFailure
}

private struct FileSignature: Equatable {
    let sizeBytes: Int64
    let modificationTime: TimeInterval
}
public struct LiveProtectedDataProvider: ProtectedDataProviding {
    public init() {}

    public func isProtectedDataAvailable() async -> Bool {
        #if os(iOS)
        await MainActor.run { UIApplication.shared.isProtectedDataAvailable }
        #else
        true
        #endif
    }
}

public actor ModelFileResolver: ModelAvailabilityProviding {
    public let rootURL: URL
    private let memoryProvider: any AvailableMemoryProviding
    private let protectedDataProvider: any ProtectedDataProviding
    private let deviceProvider: any DeviceCapabilityProviding
    private let fileManager: FileManager
    private var verifiedFileSignatures: [String: FileSignature] = [:]

    public init(
        rootURL: URL? = nil,
        memoryProvider: any AvailableMemoryProviding = SystemAvailableMemoryProvider(),
        protectedDataProvider: any ProtectedDataProviding = LiveProtectedDataProvider(),
        deviceProvider: any DeviceCapabilityProviding = SystemDeviceCapabilityProvider(),
        fileManager: FileManager = .default
    ) throws {
        let baseURL = rootURL ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Mirage Models", isDirectory: true)
        try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableBaseURL = baseURL
        try mutableBaseURL.setResourceValues(values)
        self.rootURL = baseURL.standardizedFileURL
        self.memoryProvider = memoryProvider
        self.protectedDataProvider = protectedDataProvider
        self.deviceProvider = deviceProvider
        self.fileManager = fileManager
    }

    public func availability(for descriptor: ModelDescriptor) async -> ModelAvailability {
        await availability(for: descriptor, revalidateFiles: true)
    }

    public func availability(
        for descriptor: ModelDescriptor,
        revalidateFiles: Bool
    ) async -> ModelAvailability {
        guard await protectedDataProvider.isProtectedDataAvailable() else {
            return .protectedDataUnavailable
        }
        guard descriptor.licenseApproved else { return .licenseNotApproved }
        guard descriptor.evaluationApproved else { return .evaluationRequired }
        guard deviceProvider.supportsMetal(),
              deviceProvider.operatingSystemMajorVersion() >= descriptor.minimumOSMajorVersion else {
            return .unsupportedDevice
        }
        let allowlist = descriptor.supportedDeviceIdentifiers
        guard allowlist.isEmpty || allowlist.contains(deviceProvider.deviceIdentifier()) else {
            return .unsupportedDevice
        }
        guard descriptor.profileApproved,
              descriptor.profile.width > 0,
              descriptor.profile.height > 0,
              descriptor.profile.width.isMultiple(of: 8),
              descriptor.profile.height.isMultiple(of: 8),
              descriptor.profile.steps > 0,
              descriptor.safetyPolicyVersion == PromptSafetyPolicy.version else {
            return .configurationIncomplete
        }
        let availableMemory = memoryProvider.availableMemoryBytes()
        guard availableMemory >= descriptor.minimumAvailableMemoryBytes else {
            return .insufficientMemory(
                required: descriptor.minimumAvailableMemoryBytes,
                available: availableMemory
            )
        }

        guard !descriptor.requirements.isEmpty,
              descriptor.requirements.allSatisfy({ isValidHash($0.sha256) }) else {
            return .configurationIncomplete
        }

        var missingFiles: [String] = []
        for requirement in descriptor.requirements {
            guard let url = containedURL(for: requirement, descriptor: descriptor) else {
                return .invalidPath
            }
            guard fileManager.fileExists(atPath: url.path) else {
                missingFiles.append(requirement.fileName)
                continue
            }
            guard isAllowedExtension(url.pathExtension, for: requirement.role) else {
                return .incompatibleAssets
            }
            do {
                let resourceValues = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .isExecutableKey])
                guard resourceValues.isSymbolicLink != true,
                      resourceValues.isExecutable != true else {
                    return .incompatibleAssets
                }
                let attributes = try fileManager.attributesOfItem(atPath: url.path)
                let actualSize = (attributes[.size] as? NSNumber)?.int64Value
                if let expected = requirement.expectedByteCount,
                   actualSize != expected {
                    return .integrityFailed(requirement.fileName)
                }
                guard let modified = attributes[.modificationDate] as? Date else {
                    return .integrityFailed(requirement.fileName)
                }
                let signature = FileSignature(
                    sizeBytes: actualSize ?? -1,
                    modificationTime: modified.timeIntervalSinceReferenceDate
                )
                let signatureKey = "\(descriptor.id.rawValue):\(requirement.fileName)"
                let changedSinceVerification = verifiedFileSignatures[signatureKey].map { $0 != signature } ?? false
                #if os(iOS)
                try fileManager.setAttributes(
                    [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                    ofItemAtPath: url.path
                )
                #endif
                if revalidateFiles || changedSinceVerification {
                    if try sha256(of: url) != requirement.sha256?.lowercased() {
                        return .integrityFailed(requirement.fileName)
                    }
                }
                verifiedFileSignatures[signatureKey] = signature
            } catch {
                return .integrityFailed(requirement.fileName)
            }
        }
        return missingFiles.isEmpty ? .available : .missingFiles(missingFiles)
    }

    public func resolve(_ descriptor: ModelDescriptor) async throws -> ResolvedModelFiles {
        guard await availability(for: descriptor) == .available else {
            throw ModelResolutionError.modelUnavailable
        }
        var diffusionModel: URL?
        var vae: URL?
        var textEncoder: URL?
        for requirement in descriptor.requirements {
            guard let url = containedURL(for: requirement, descriptor: descriptor) else {
                throw ModelResolutionError.invalidPath
            }
            switch requirement.role {
            case .diffusionModel: diffusionModel = url
            case .vae: vae = url
            case .textEncoder: textEncoder = url
            }
        }
        guard let diffusionModel else { throw ModelResolutionError.missingFile }
        return ResolvedModelFiles(
            diffusionModel: diffusionModel,
            vae: vae,
            textEncoder: textEncoder
        )
    }

    private func containedURL(for requirement: ModelFileRequirement, descriptor: ModelDescriptor) -> URL? {
        let components = requirement.fileName.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.isEmpty,
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }),
              !requirement.fileName.contains("\\"),
              !requirement.fileName.hasPrefix("/") else {
            return nil
        }
        let folderName = descriptor.repository.map(ModelStore.safeFolderName(for:)) ?? descriptor.id.rawValue
        let modelRoot = rootURL.appendingPathComponent(folderName, isDirectory: true)
        let candidate = modelRoot.appendingPathComponent(requirement.fileName).standardizedFileURL
        let resolvedRoot = rootURL.resolvingSymlinksInPath().standardizedFileURL
        let resolvedCandidate = candidate.resolvingSymlinksInPath().standardizedFileURL
        let rootPath = resolvedRoot.path.hasSuffix("/") ? resolvedRoot.path : resolvedRoot.path + "/"
        guard resolvedCandidate.path.hasPrefix(rootPath) else { return nil }
        return resolvedCandidate
    }

    private func isValidHash(_ value: String?) -> Bool {
        guard let value, value.count == 64 else { return false }
        return value.allSatisfy { $0.isHexDigit }
    }

    private func isAllowedExtension(_ fileExtension: String, for role: ModelFileRole) -> Bool {
        let value = fileExtension.lowercased()
        switch role {
        case .diffusionModel, .textEncoder:
            return value == "gguf" || value == "safetensors"
        case .vae:
            return value == "safetensors"
        }
    }

    private func sha256(of url: URL) throws -> String {
        try boundedFileSHA256(of: url)
    }
}
