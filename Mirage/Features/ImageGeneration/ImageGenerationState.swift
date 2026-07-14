import Foundation

public enum ImageGenerationState: Equatable, Sendable {
    case idle
    case checkingModels
    case ready
    case loadingModel(requestID: UUID, previousResult: GeneratedImage?)
    case generating(requestID: UUID, progress: GenerationProgress, previousResult: GeneratedImage?)
    case reviewingSafety(requestID: UUID, previousResult: GeneratedImage?)
    case success(GeneratedImage)
    case refused(String, previousResult: GeneratedImage?)
    case failed(ImageGenerationFailure, previousResult: GeneratedImage?)

    public var isBusy: Bool {
        switch self {
        case .loadingModel, .generating, .reviewingSafety:
            true
        default:
            false
        }
    }

    public var currentImage: GeneratedImage? {
        switch self {
        case .loadingModel(_, let image),
             .generating(_, _, let image),
             .reviewingSafety(_, let image),
             .refused(_, let image),
             .failed(_, let image):
            image
        case .success(let image):
            image
        default:
            nil
        }
    }

    public var progress: GenerationProgress? {
        guard case .generating(_, let progress, _) = self else { return nil }
        return progress
    }

    public var statusText: String {
        switch self {
        case .idle: "Preparing…"
        case .checkingModels: "Checking models…"
        case .ready: "Ready"
        case .loadingModel: "Loading model…"
        case .generating(_, let progress, _):
            "Generating step \(progress.completedStep) of \(progress.totalSteps)…"
        case .reviewingSafety: "Reviewing image…"
        case .success: "Image ready"
        case .refused(let message, _): message
        case .failed(let failure, _): failure.userMessage
        }
    }
}

public extension ImageGenerationFailure {
    var userMessage: String {
        switch self {
        case .noAvailableModel:
            "No compatible model is ready on this device."
        case .invalidPrompt:
            "Describe an image using between 1 and 1,000 characters."
        case .modelUnavailable:
            "The selected model is not ready. Check its files and compatibility."
        case .insufficientMemory:
            "There is not enough available memory for this model."
        case .modelLoadFailed:
            "Mirage could not load this model. Verify its approved files."
        case .generationFailed:
            "The image could not be generated. Your previous image is still available."
        case .invalidImage:
            "The generated image was invalid and was not displayed."
        case .safetyAnalysisUnavailable:
            "The image could not be safely reviewed on this device."
        case .sensitiveOutput:
            "That result was not shown. Try a different description."
        case .cancelled:
            "Generation did not complete."
        }
    }
}
