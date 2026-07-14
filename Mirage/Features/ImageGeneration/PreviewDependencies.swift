import Foundation

#if DEBUG
actor StaticModelProvider: ModelAvailabilityProviding {
    private let availableID: ModelID?

    init(availableID: ModelID?) {
        self.availableID = availableID
    }

    func availability(for descriptor: ModelDescriptor) async -> ModelAvailability {
        descriptor.id == availableID ? .available : .configurationIncomplete
    }

    func resolve(_ descriptor: ModelDescriptor) async throws -> ResolvedModelFiles {
        guard descriptor.id == availableID else { throw ModelResolutionError.modelUnavailable }
        return ResolvedModelFiles(diffusionModel: URL(fileURLWithPath: "/dev/null"))
    }
}

actor PreviewGenerator: ImageGenerating {
    private static let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!
    private let shouldFail: Bool

    init(shouldFail: Bool = false) {
        self.shouldFail = shouldFail
    }

    func generate(
        request: GenerationRequestSnapshot,
        descriptor: ModelDescriptor,
        progress: @escaping @Sendable (GenerationProgress) -> Void
    ) async throws -> GeneratedImage {
        progress(.init(requestID: request.id, completedStep: 1, totalSteps: 2, elapsed: 0.01))
        try? await Task.sleep(for: .milliseconds(120))
        if shouldFail { throw ImageGenerationFailure.generationFailed }
        progress(.init(requestID: request.id, completedStep: 2, totalSteps: 2, elapsed: 0.01))
        return GeneratedImage(
            requestID: request.id,
            modelID: descriptor.id,
            pngData: Self.png,
            width: 1,
            height: 1
        )
    }
}

struct PreviewSafetyService: ImageSafetyChecking {
    let refusesPrompt: Bool

    init(refusesPrompt: Bool = false) {
        self.refusesPrompt = refusesPrompt
    }

    func validatePrompt(_ prompt: String) async throws -> String {
        if refusesPrompt { throw ImageSafetyError.refusedPrompt }
        return try PromptSafetyPolicy.current.validatedPrompt(prompt)
    }

    func validateOutput(_ image: GeneratedImage) async throws -> GeneratedImage { image }
}

actor PreviewPhotoSaver: PhotoLibrarySaving {
    private let status: PhotoAuthorizationState

    init(status: PhotoAuthorizationState = .authorized) {
        self.status = status
    }

    func authorizationStatus() async -> PhotoAuthorizationState { status }
    func savePNG(_ data: Data) async throws -> PhotoSaveResult { .saved }
}

@MainActor
enum PreviewDependencies {
    static func makeViewModel() -> ImageGenerationViewModel {
        let arguments = ProcessInfo.processInfo.arguments
        let availableID: ModelID? = arguments.contains("--ui-test-no-model") ? nil : .ernieImageTurbo
        let provider = StaticModelProvider(availableID: availableID)
        return ImageGenerationViewModel(
            availabilityProvider: provider,
            generator: PreviewGenerator(shouldFail: arguments.contains("--ui-test-generation-failure")),
            safetyService: PreviewSafetyService(refusesPrompt: arguments.contains("--ui-test-refusal")),
            photoSaver: PreviewPhotoSaver(status: arguments.contains("--ui-test-photos-denied") ? .denied : .authorized)
        )
    }
}
#endif
