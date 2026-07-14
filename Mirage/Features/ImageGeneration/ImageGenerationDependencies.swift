import Foundation

public struct ResolvedModelFiles: Equatable, Sendable {
    public let diffusionModel: URL
    public let vae: URL?
    public let textEncoder: URL?

    public init(diffusionModel: URL, vae: URL? = nil, textEncoder: URL? = nil) {
        self.diffusionModel = diffusionModel
        self.vae = vae
        self.textEncoder = textEncoder
    }
}

public protocol AvailableMemoryProviding: Sendable {
    func availableMemoryBytes() -> UInt64
}

public protocol ProtectedDataProviding: Sendable {
    func isProtectedDataAvailable() async -> Bool
}

public protocol DeviceCapabilityProviding: Sendable {
    func operatingSystemMajorVersion() -> Int
    func deviceIdentifier() -> String
    func supportsMetal() -> Bool
}

public protocol ModelAvailabilityProviding: Sendable {
    func availability(for descriptor: ModelDescriptor) async -> ModelAvailability
    func resolve(_ descriptor: ModelDescriptor) async throws -> ResolvedModelFiles
}

public protocol ImageGenerating: Sendable {
    func generate(
        request: GenerationRequestSnapshot,
        descriptor: ModelDescriptor,
        progress: @escaping @Sendable (GenerationProgress) -> Void
    ) async throws -> GeneratedImage
}

public protocol ImageSensitivityAnalyzing: Sendable {
    func isSensitive(pngData: Data) async throws -> Bool
}

public protocol ImageSafetyChecking: Sendable {
    func validatePrompt(_ prompt: String) async throws -> String
    func validateOutput(_ image: GeneratedImage) async throws -> GeneratedImage
}

public protocol PhotoLibrarySaving: Sendable {
    func authorizationStatus() async -> PhotoAuthorizationState
    func savePNG(_ data: Data) async throws -> PhotoSaveResult
}
