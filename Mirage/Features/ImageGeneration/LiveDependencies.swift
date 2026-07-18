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
    static func makeViewModel(modelStorageBaseURL: URL? = nil) -> ImageGenerationViewModel {
        do {
            let store = try ModelStore(documentsURL: modelStorageBaseURL)
            let resolver = try ModelFileResolver(rootURL: store.modelRootURL)
            let downloader = HuggingFaceModelDownloader()
            return ImageGenerationViewModel(
                availabilityProvider: resolver,
                generator: MirageInferenceService(resolver: resolver),
                safetyService: ImageSafetyService(),
                photoSaver: PhotoLibrarySaver(),
                downloader: downloader,
                modelStore: store
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
