import CryptoKit
import Foundation
@testable import MirageApp

let onePixelPNG = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!

extension ModelDescriptor {
    static func testFixture(
        id: ModelID = .ernieImageTurbo,
        requirements: [ModelFileRequirement] = [],
        minimumAvailableMemoryBytes: UInt64 = 0,
        licenseApproved: Bool = true,
        evaluationApproved: Bool = true
    ) -> ModelDescriptor {
        ModelDescriptor(
            id: id,
            familyName: id.displayName,
            summary: "Test model",
            packageVersion: "0.2.0",
            requirements: requirements,
            profile: GenerationProfile(width: 1024, height: 1024, steps: 8, cfgScale: 1),
            minimumAvailableMemoryBytes: minimumAvailableMemoryBytes,
            licenseApproved: licenseApproved,
            evaluationApproved: evaluationApproved
        )
    }
}

extension Data {
    var sha256String: String {
        SHA256.hash(data: self).map { String(format: "%02x", $0) }.joined()
    }
}

struct FixedMemoryProvider: AvailableMemoryProviding {
    let bytes: UInt64

    func availableMemoryBytes() -> UInt64 { bytes }
}

struct FixedProtectedDataProvider: ProtectedDataProviding {
    let available: Bool

    func isProtectedDataAvailable() async -> Bool { available }
}

struct FixedDeviceCapabilityProvider: DeviceCapabilityProviding {
    let osMajorVersion: Int
    let identifier: String
    let metalSupported: Bool

    init(osMajorVersion: Int = 26, identifier: String = "test-device", metalSupported: Bool = true) {
        self.osMajorVersion = osMajorVersion
        self.identifier = identifier
        self.metalSupported = metalSupported
    }

    func operatingSystemMajorVersion() -> Int { osMajorVersion }
    func deviceIdentifier() -> String { identifier }
    func supportsMetal() -> Bool { metalSupported }
}

actor StubAvailabilityProvider: ModelAvailabilityProviding {
    var availabilityByID: [ModelID: ModelAvailability]
    var resolvedFiles: ResolvedModelFiles

    init(
        availabilityByID: [ModelID: ModelAvailability],
        resolvedFiles: ResolvedModelFiles = .init(diffusionModel: URL(fileURLWithPath: "/tmp/model.gguf"))
    ) {
        self.availabilityByID = availabilityByID
        self.resolvedFiles = resolvedFiles
    }

    func availability(for descriptor: ModelDescriptor) async -> ModelAvailability {
        availabilityByID[descriptor.id] ?? .configurationIncomplete
    }

    func resolve(_ descriptor: ModelDescriptor) async throws -> ResolvedModelFiles {
        guard availabilityByID[descriptor.id]?.isAvailable == true else {
            throw ModelResolutionError.modelUnavailable
        }
        return resolvedFiles
    }
}

actor StubGenerator: ImageGenerating {
    private(set) var requests: [GenerationRequestSnapshot] = []
    var output = onePixelPNG
    var failure: ImageGenerationFailure?

    func generate(
        request: GenerationRequestSnapshot,
        descriptor: ModelDescriptor,
        progress: @escaping @Sendable (GenerationProgress) -> Void
    ) async throws -> GeneratedImage {
        requests.append(request)
        progress(.init(requestID: request.id, completedStep: 1, totalSteps: 2, elapsed: 0.01))
        progress(.init(requestID: request.id, completedStep: 2, totalSteps: 2, elapsed: 0.01))
        if let failure { throw failure }
        return GeneratedImage(
            requestID: request.id,
            modelID: descriptor.id,
            pngData: output,
            width: 1,
            height: 1
        )
    }

    func requestCount() -> Int { requests.count }
}

struct PassingSafetyService: ImageSafetyChecking {
    func validatePrompt(_ prompt: String) async throws -> String {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func validateOutput(_ image: GeneratedImage) async throws -> GeneratedImage { image }
}

actor StubPhotoSaver: PhotoLibrarySaving {
    private(set) var savedPayloads: [Data] = []
    var result: PhotoSaveResult = .saved

    func authorizationStatus() async -> PhotoAuthorizationState { .authorized }

    func savePNG(_ data: Data) async throws -> PhotoSaveResult {
        savedPayloads.append(data)
        return result
    }

    func saveCount() -> Int { savedPayloads.count }
}
