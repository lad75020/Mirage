import Foundation

public enum ModelID: String, CaseIterable, Codable, Identifiable, Sendable {
    case stableDiffusion
    case sdxl
    case sd3
    case flux
    case chroma1HD
    case qwenImage
    case ernieImageTurbo
    case zImageTurbo

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .stableDiffusion: "Stable Diffusion 1.x / 2.x"
        case .sdxl: "SDXL / SDXL-Turbo"
        case .sd3: "SD3 / SD3.5"
        case .flux: "FLUX.1 schnell / dev"
        case .chroma1HD: "Chroma1-HD"
        case .qwenImage: "Qwen-Image"
        case .ernieImageTurbo: "ERNIE-Image-Turbo"
        case .zImageTurbo: "Z-Image-Turbo"
        }
    }
}

public enum ModelFileRole: String, Codable, Sendable {
    case diffusionModel
    case vae
    case textEncoder
}

public struct ModelFileRequirement: Equatable, Codable, Sendable {
    public let role: ModelFileRole
    public let fileName: String
    public let expectedByteCount: Int64?
    public let sha256: String?

    public init(
        role: ModelFileRole,
        fileName: String,
        expectedByteCount: Int64? = nil,
        sha256: String?
    ) {
        self.role = role
        self.fileName = fileName
        self.expectedByteCount = expectedByteCount
        self.sha256 = sha256
    }
}

public struct GenerationProfile: Equatable, Codable, Sendable {
    public let width: Int
    public let height: Int
    public let steps: Int
    public let cfgScale: Float
    public let negativePrompt: String?

    public init(
        width: Int,
        height: Int,
        steps: Int,
        cfgScale: Float,
        negativePrompt: String? = nil
    ) {
        self.width = width
        self.height = height
        self.steps = steps
        self.cfgScale = cfgScale
        self.negativePrompt = negativePrompt
    }
}

public struct ModelDescriptor: Identifiable, Equatable, Codable, Sendable {
    public let id: ModelID
    public let familyName: String
    public let summary: String
    public let packageVersion: String
    public let requirements: [ModelFileRequirement]
    public let profile: GenerationProfile
    public let minimumAvailableMemoryBytes: UInt64
    public let licenseApproved: Bool
    public let evaluationApproved: Bool
    public let minimumOSMajorVersion: Int
    public let supportedDeviceIdentifiers: [String]
    public let profileApproved: Bool
    public let safetyPolicyVersion: String

    public init(
        id: ModelID,
        familyName: String,
        summary: String,
        packageVersion: String,
        requirements: [ModelFileRequirement],
        profile: GenerationProfile,
        minimumAvailableMemoryBytes: UInt64,
        licenseApproved: Bool,
        evaluationApproved: Bool,
        minimumOSMajorVersion: Int = 26,
        supportedDeviceIdentifiers: [String] = [],
        profileApproved: Bool = true,
        safetyPolicyVersion: String = PromptSafetyPolicy.version
    ) {
        self.id = id
        self.familyName = familyName
        self.summary = summary
        self.packageVersion = packageVersion
        self.requirements = requirements
        self.profile = profile
        self.minimumAvailableMemoryBytes = minimumAvailableMemoryBytes
        self.licenseApproved = licenseApproved
        self.evaluationApproved = evaluationApproved
        self.minimumOSMajorVersion = minimumOSMajorVersion
        self.supportedDeviceIdentifiers = supportedDeviceIdentifiers
        self.profileApproved = profileApproved
        self.safetyPolicyVersion = safetyPolicyVersion
    }
}

public enum ModelAvailability: Equatable, Sendable {
    case checking
    case available
    case configurationIncomplete
    case missingFiles([String])
    case integrityFailed(String)
    case licenseNotApproved
    case evaluationRequired
    case unsupportedDevice
    case insufficientMemory(required: UInt64, available: UInt64)
    case protectedDataUnavailable
    case invalidPath
    case incompatibleAssets

    public var isAvailable: Bool {
        self == .available
    }
}

public struct GenerationRequestSnapshot: Equatable, Sendable {
    public let id: UUID
    public let prompt: String
    public let modelID: ModelID
    public let profile: GenerationProfile
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        prompt: String,
        modelID: ModelID,
        profile: GenerationProfile,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.prompt = prompt
        self.modelID = modelID
        self.profile = profile
        self.createdAt = createdAt
    }
}

public struct GenerationProgress: Equatable, Sendable {
    public let requestID: UUID
    public let completedStep: Int
    public let totalSteps: Int
    public let elapsed: TimeInterval

    public init(requestID: UUID, completedStep: Int, totalSteps: Int, elapsed: TimeInterval) {
        self.requestID = requestID
        self.completedStep = completedStep
        self.totalSteps = totalSteps
        self.elapsed = elapsed
    }

    public var fractionCompleted: Double {
        guard totalSteps > 0 else { return 0 }
        return min(max(Double(completedStep) / Double(totalSteps), 0), 1)
    }
}

public struct GeneratedImage: Equatable, Sendable {
    public let requestID: UUID
    public let modelID: ModelID
    public let pngData: Data
    public let width: Int
    public let height: Int

    public init(requestID: UUID, modelID: ModelID, pngData: Data, width: Int, height: Int) {
        self.requestID = requestID
        self.modelID = modelID
        self.pngData = pngData
        self.width = width
        self.height = height
    }
}

public enum ImageGenerationFailure: Error, Equatable, Sendable {
    case noAvailableModel
    case invalidPrompt
    case modelUnavailable
    case insufficientMemory
    case modelLoadFailed
    case generationFailed
    case invalidImage
    case safetyAnalysisUnavailable
    case sensitiveOutput
    case cancelled
}

public enum PhotoAuthorizationState: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

public enum PhotoSaveResult: Equatable, Sendable {
    case saved
    case alreadySaved
}

public enum SaveState: Equatable, Sendable {
    case hidden
    case ready
    case requestingPermission
    case saving
    case saved
    case denied
    case failed
}
