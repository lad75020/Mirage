import Foundation
import Observation
import UIKit

@MainActor
@Observable
public final class ImageGenerationViewModel {
    public var prompt = "" {
        didSet {
            if prompt.count > 1_000 {
                prompt = String(prompt.prefix(1_000))
            }
            validationMessage = nil
        }
    }
    public private(set) var state: ImageGenerationState = .idle
    public private(set) var selectedModelID: ModelID?
    public private(set) var availabilityByID: [ModelID: ModelAvailability]
    public private(set) var validationMessage: String?
    public private(set) var saveState: SaveState = .hidden

    public let catalog: [ModelDescriptor]

    @ObservationIgnored private let availabilityProvider: any ModelAvailabilityProviding
    @ObservationIgnored private let generator: any ImageGenerating
    @ObservationIgnored private let safetyService: any ImageSafetyChecking
    @ObservationIgnored private let photoSaver: any PhotoLibrarySaving
    @ObservationIgnored private var activeRequestID: UUID?
    @ObservationIgnored private var generationTask: Task<Void, Never>?
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    public init(
        catalog: [ModelDescriptor] = ModelCatalog.entries,
        availabilityProvider: any ModelAvailabilityProviding,
        generator: any ImageGenerating,
        safetyService: any ImageSafetyChecking,
        photoSaver: any PhotoLibrarySaving
    ) {
        self.catalog = catalog
        self.availabilityProvider = availabilityProvider
        self.generator = generator
        self.safetyService = safetyService
        self.photoSaver = photoSaver
        self.availabilityByID = Dictionary(
            uniqueKeysWithValues: catalog.map { ($0.id, ModelAvailability.checking) }
        )
    }

    public var selectedDescriptor: ModelDescriptor? {
        guard let selectedModelID else { return nil }
        return catalog.first { $0.id == selectedModelID }
    }

    public var canSend: Bool {
        guard !state.isBusy,
              let selectedModelID,
              availability(for: selectedModelID).isAvailable else {
            return false
        }
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 1_000
    }

    public var selectionLocked: Bool { state.isBusy }

    public func availability(for id: ModelID) -> ModelAvailability {
        availabilityByID[id] ?? .configurationIncomplete
    }

    public func refreshAvailability() async {
        let previous = state.currentImage
        state = .checkingModels
        var results: [ModelID: ModelAvailability] = [:]
        for descriptor in catalog {
            results[descriptor.id] = await availabilityProvider.availability(for: descriptor)
        }
        availabilityByID = results
        if let selectedModelID, results[selectedModelID]?.isAvailable == true {
            self.selectedModelID = selectedModelID
        } else {
            selectedModelID = catalog.first { results[$0.id]?.isAvailable == true }?.id
        }
        state = previous.map(ImageGenerationState.success) ?? .ready
    }

    public func selectModel(_ id: ModelID) {
        guard !selectionLocked, availability(for: id).isAvailable else { return }
        selectedModelID = id
        validationMessage = nil
    }

    public func startGeneration() {
        guard generationTask == nil else { return }
        generationTask = Task { [weak self] in
            await self?.generate()
        }
    }

    public func generate() async {
        guard !state.isBusy else { return }
        let previousResult = state.currentImage
        let rawPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawPrompt.isEmpty else {
            validationMessage = "Enter a description first."
            return
        }
        guard let descriptor = selectedDescriptor,
              availability(for: descriptor.id).isAvailable else {
            state = .failed(.noAvailableModel, previousResult: previousResult)
            announce(state.statusText)
            return
        }

        let validatedPrompt: String
        do {
            validatedPrompt = try await safetyService.validatePrompt(rawPrompt)
        } catch ImageSafetyError.refusedPrompt {
            state = .refused("That description can’t be used. Try a different idea.", previousResult: previousResult)
            announce(state.statusText)
            return
        } catch {
            validationMessage = "Use a description between 1 and 1,000 characters."
            return
        }

        let request = GenerationRequestSnapshot(
            prompt: validatedPrompt,
            modelID: descriptor.id,
            profile: descriptor.profile
        )
        activeRequestID = request.id
        state = .loadingModel(requestID: request.id, previousResult: previousResult)
        saveState = previousResult == nil ? .hidden : .ready
        announce(state.statusText)
        defer {
            if activeRequestID == request.id { activeRequestID = nil }
            generationTask = nil
        }

        do {
            let generated = try await generator.generate(
                request: request,
                descriptor: descriptor
            ) { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.accept(progress: progress, previousResult: previousResult)
                }
            }
            guard activeRequestID == request.id, !Task.isCancelled else { return }
            state = .reviewingSafety(requestID: request.id, previousResult: previousResult)
            let safeImage = try await safetyService.validateOutput(generated)
            guard activeRequestID == request.id else { return }
            state = .success(safeImage)
            saveState = .ready
            announce("Image ready")
        } catch {
            guard activeRequestID == request.id else { return }
            let failure = map(error)
            if failure == .sensitiveOutput {
                state = .refused(failure.userMessage, previousResult: previousResult)
            } else {
                state = .failed(failure, previousResult: previousResult)
            }
            saveState = previousResult == nil ? .hidden : .ready
            announce(state.statusText)
        }
    }

    public func startSaving() {
        guard saveTask == nil else { return }
        saveTask = Task { [weak self] in
            await self?.saveCurrentImage()
        }
    }

    public func saveCurrentImage() async {
        guard let image = state.currentImage,
              saveState != .saving,
              saveState != .requestingPermission else {
            return
        }
        let authorization = await photoSaver.authorizationStatus()
        switch authorization {
        case .denied, .restricted:
            saveState = .denied
            announce("Photo access is unavailable")
            return
        case .notDetermined:
            saveState = .requestingPermission
        case .authorized:
            saveState = .saving
        }
        defer { saveTask = nil }

        do {
            saveState = .saving
            _ = try await photoSaver.savePNG(image.pngData)
            saveState = .saved
            announce("Saved to Photos")
        } catch PhotoLibrarySaveError.denied, PhotoLibrarySaveError.restricted {
            saveState = .denied
            announce("Photo access is unavailable")
        } catch {
            saveState = .failed
            announce("Image was not saved")
        }
    }

    private func accept(progress: GenerationProgress, previousResult: GeneratedImage?) {
        guard activeRequestID == progress.requestID else { return }
        state = .generating(
            requestID: progress.requestID,
            progress: progress,
            previousResult: previousResult
        )
    }

    private func map(_ error: Error) -> ImageGenerationFailure {
        if let failure = error as? ImageGenerationFailure { return failure }
        guard let safety = error as? ImageSafetyError else { return .generationFailed }
        return switch safety {
        case .invalidPrompt: .invalidPrompt
        case .refusedPrompt: .invalidPrompt
        case .invalidImage: .invalidImage
        case .analysisUnavailable: .safetyAnalysisUnavailable
        case .sensitiveOutput: .sensitiveOutput
        }
    }

    private func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}
