import Foundation

private actor UnavailableModelProvider: ModelAvailabilityProviding {
    func availability(for descriptor: ModelDescriptor) async -> ModelAvailability {
        .configurationIncomplete
    }

    func resolve(_ descriptor: ModelDescriptor) async throws -> ResolvedModelFiles {
        throw ModelResolutionError.modelUnavailable
    }
}

private actor UnavailableGenerator: ImageGenerating {
    func generate(
        request: GenerationRequestSnapshot,
        descriptor: ModelDescriptor,
        progress: @escaping @Sendable (GenerationProgress) -> Void
    ) async throws -> GeneratedImage {
        throw ImageGenerationFailure.modelUnavailable
    }
}

@MainActor
enum LiveDependencies {
    static func makeViewModel() -> ImageGenerationViewModel {
        do {
            let resolver = try ModelFileResolver()
            return ImageGenerationViewModel(
                availabilityProvider: resolver,
                generator: MirageInferenceService(resolver: resolver),
                safetyService: ImageSafetyService(),
                photoSaver: PhotoLibrarySaver()
            )
        } catch {
            let unavailable = UnavailableModelProvider()
            return ImageGenerationViewModel(
                availabilityProvider: unavailable,
                generator: UnavailableGenerator(),
                safetyService: ImageSafetyService(),
                photoSaver: PhotoLibrarySaver()
            )
        }
    }
}
