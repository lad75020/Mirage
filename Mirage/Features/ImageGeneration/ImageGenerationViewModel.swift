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
    public private(set) var downloadedSnapshots: [LocalModelSnapshot] = []
    public private(set) var catalogEntries: [ModelCatalogEntry]
    public private(set) var downloadStates: [ModelRepositoryReference: ModelDownloadState] = [:]
    public private(set) var pendingDownloadPlan: ModelDownloadPlan?
    public private(set) var customReferenceError: String?
    public private(set) var advancedModelError: String?
    public private(set) var activeDownloadReference: ModelRepositoryReference?
    public var customReferenceInput = "" {
        didSet { customReferenceError = nil }
    }
    public var tokenizerReferenceInput = "" {
        didSet { advancedModelError = nil }
    }
    public var transformerReferenceInput = "" {
        didSet { advancedModelError = nil }
    }
    public var vaeReferenceInput = "" {
        didSet { advancedModelError = nil }
    }

    public private(set) var catalog: [ModelDescriptor]
    public let featuredReferences: [ModelRepositoryReference]

    @ObservationIgnored private let baseCatalog: [ModelDescriptor]
    @ObservationIgnored private let availabilityProvider: any ModelAvailabilityProviding
    @ObservationIgnored private let generator: any ImageGenerating
    @ObservationIgnored private let safetyService: any ImageSafetyChecking
    @ObservationIgnored private let photoSaver: any PhotoLibrarySaving
    @ObservationIgnored private let downloader: (any ModelDownloading)?
    @ObservationIgnored private let modelStore: (any ModelSnapshotStoring)?
    @ObservationIgnored private var activeRequestID: UUID?
    @ObservationIgnored private var generationTask: Task<Void, Never>?
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var downloadTask: Task<Void, Never>?
    @ObservationIgnored private var pendingDownloadReference: ModelRepositoryReference?

    public init(
        catalog: [ModelDescriptor] = ModelCatalog.entries,
        availabilityProvider: any ModelAvailabilityProviding,
        generator: any ImageGenerating,
        safetyService: any ImageSafetyChecking,
        photoSaver: any PhotoLibrarySaving,
        downloader: (any ModelDownloading)? = nil,
        modelStore: (any ModelSnapshotStoring)? = nil
    ) {
        self.baseCatalog = catalog
        self.catalog = catalog
        self.featuredReferences = ModelCatalog.featuredReferences
        self.availabilityProvider = availabilityProvider
        self.generator = generator
        self.safetyService = safetyService
        self.photoSaver = photoSaver
        self.downloader = downloader
        self.modelStore = modelStore
        self.availabilityByID = Dictionary(
            uniqueKeysWithValues: catalog.map { ($0.id, ModelAvailability.checking) }
        )
        self.catalogEntries = ModelCatalog.catalogEntries()
        for reference in ModelCatalog.featuredReferences {
            downloadStates[reference] = .notDownloaded
        }
    }

    public var selectedDescriptor: ModelDescriptor? {
        guard let selectedModelID else { return nil }
        return catalog.first { $0.id == selectedModelID }
    }

    public var canSend: Bool {
        guard !operationLocked,
              let selectedModelID,
              availability(for: selectedModelID).isAvailable else {
            return false
        }
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 1_000
    }

    public var canDownloadAdvancedModel: Bool {
        !operationLocked && [tokenizerReferenceInput, transformerReferenceInput, vaeReferenceInput]
            .allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    public var selectionLocked: Bool { operationLocked }

    public var operationLocked: Bool {
        state.isBusy || generationTask != nil || downloadTask != nil || activeDownloadReference != nil
    }

    public var filesLocationText: String {
        guard modelStore != nil else { return "Files > On My iPhone > Mirage > Mirage Models" }
        return "Files > On My iPhone > Mirage > Mirage Models"
    }

    public func availability(for id: ModelID) -> ModelAvailability {
        availabilityByID[id] ?? .configurationIncomplete
    }

    public func downloadState(for reference: ModelRepositoryReference) -> ModelDownloadState {
        downloadStates[reference] ?? .notDownloaded
    }

    public func refreshAvailability() async {
        let previous = state.currentImage
        state = .checkingModels
        if let modelStore {
            downloadedSnapshots = await modelStore.refreshSnapshots()
            catalog = mergedCatalog(with: downloadedSnapshots)
            catalogEntries = ModelCatalog.catalogEntries(downloadedSnapshots: downloadedSnapshots)
            let currentReferences = Set(downloadedSnapshots.map(\.reference))
            for (reference, downloadState) in downloadStates where !currentReferences.contains(reference) {
                if case .downloaded = downloadState {
                    downloadStates[reference] = .notDownloaded
                }
            }
            for snapshot in downloadedSnapshots {
                downloadStates[snapshot.reference] = .downloaded(snapshot)
            }
        }
        var results: [ModelID: ModelAvailability] = [:]
        for descriptor in catalog {
            results[descriptor.id] = await availabilityProvider.availability(for: descriptor)
        }
        availabilityByID = results
        if let selectedModelID, results[selectedModelID]?.isAvailable != true {
            self.selectedModelID = nil
        }
        state = previous.map(ImageGenerationState.success) ?? .ready
    }

    public func selectModel(_ id: ModelID) async {
        guard !operationLocked else { return }
        await refreshAvailability()
        guard availability(for: id).isAvailable,
              let descriptor = catalog.first(where: { $0.id == id }),
              descriptor.repository.map({ downloadedSnapshot(for: $0)?.compatibility.isSelectable == true }) ?? true else {
            selectedModelID = selectedModelID == id ? nil : selectedModelID
            return
        }
        selectedModelID = id
        validationMessage = nil
    }

    public func requestDownload(for reference: ModelRepositoryReference) async {
        guard !operationLocked, let downloader, let modelStore else { return }
        activeDownloadReference = reference
        defer { activeDownloadReference = nil }
        downloadStates[reference] = .resolving(reference: reference)
        do {
            let plan = try await downloader.resolve(reference: reference)
            try await modelStore.validateCanStore(plan: plan)
            pendingDownloadReference = reference
            pendingDownloadPlan = plan
            downloadStates[reference] = .awaitingConfirmation(
                revision: plan.revision,
                sizeBytes: plan.revision.totalSizeBytes ?? plan.expectedSizeBytes,
                license: plan.revision.license
            )
        } catch {
            pendingDownloadReference = nil
            pendingDownloadPlan = nil
            downloadStates[reference] = .failed(reference: reference, reason: mapDownloadError(error))
        }
    }

    public func submitCustomReference() async {
        do {
            let reference = try ModelRepositoryReference(customReferenceInput)
            customReferenceError = nil
            await requestDownload(for: reference)
        } catch {
            customReferenceError = "Enter a public Hugging Face model reference."
        }
    }

    public func submitAdvancedModel() async {
        guard canDownloadAdvancedModel, let downloader, let modelStore else { return }
        let compositeReference = AdvancedModelComposer.compositeReference
        activeDownloadReference = compositeReference
        downloadStates[compositeReference] = .resolving(reference: compositeReference)
        do {
            let tokenizerReference = try ModelRepositoryReference(tokenizerReferenceInput)
            let transformerReference = try ModelRepositoryReference(transformerReferenceInput)
            let vaeReference = try ModelRepositoryReference(vaeReferenceInput)

            async let tokenizerPlan = downloader.resolve(reference: tokenizerReference)
            async let transformerPlan = downloader.resolve(reference: transformerReference)
            async let vaePlan = downloader.resolve(reference: vaeReference)
            let plan = try await AdvancedModelComposer.compose(
                tokenizer: tokenizerPlan,
                transformer: transformerPlan,
                vae: vaePlan
            )
            try await modelStore.validateCanStore(plan: plan)
            advancedModelError = nil
            downloadTask = Task { [weak self] in
                await self?.performConfirmedDownload(
                    plan: plan,
                    reference: compositeReference,
                    downloader: downloader,
                    modelStore: modelStore
                )
            }
        } catch let error as AdvancedModelComposerError {
            activeDownloadReference = nil
            downloadStates[compositeReference] = .failed(reference: compositeReference, reason: .invalidReference)
            advancedModelError = advancedModelMessage(for: error)
        } catch is ModelRepositoryReferenceError {
            activeDownloadReference = nil
            downloadStates[compositeReference] = .failed(reference: compositeReference, reason: .invalidReference)
            advancedModelError = "Enter three public Hugging Face references in owner/model_name format."
        } catch {
            activeDownloadReference = nil
            downloadStates[compositeReference] = .failed(reference: compositeReference, reason: mapDownloadError(error))
            advancedModelError = "The advanced model could not be prepared for download."
        }
    }

    public func confirmDownload() {
        guard downloadTask == nil,
              let plan = pendingDownloadPlan,
              let reference = pendingDownloadReference,
              let downloader,
              let modelStore else { return }
        pendingDownloadPlan = nil
        pendingDownloadReference = nil
        activeDownloadReference = reference
        downloadTask = Task { [weak self] in
            await self?.performConfirmedDownload(
                plan: plan,
                reference: reference,
                downloader: downloader,
                modelStore: modelStore
            )
        }
    }

    public func cancelDownload() {
        guard let pendingDownloadReference else {
            downloadTask?.cancel()
            return
        }
        pendingDownloadPlan = nil
        self.pendingDownloadReference = nil
        downloadStates[pendingDownloadReference] = .cancelled(reference: pendingDownloadReference)
    }

    public func retryDownload(for reference: ModelRepositoryReference) async {
        await requestDownload(for: reference)
    }

    public func startGeneration() {
        guard generationTask == nil else { return }
        generationTask = Task { [weak self] in
            await self?.generate()
        }
    }

    public func generate() async {
        guard !state.isBusy, activeDownloadReference == nil, downloadTask == nil else { return }
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
        await refreshAvailability()
        guard selectedModelID == descriptor.id,
              availability(for: descriptor.id).isAvailable else {
            state = .failed(.modelUnavailable, previousResult: previousResult)
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

    private func performConfirmedDownload(
        plan: ModelDownloadPlan,
        reference: ModelRepositoryReference,
        downloader: any ModelDownloading,
        modelStore: any ModelSnapshotStoring
    ) async {
        var stagingURL: URL?
        do {
            downloadStates[reference] = .downloading(
                reference: reference,
                progress: .init(completedBytes: 0, totalBytes: plan.expectedSizeBytes)
            )
            let staging = try await modelStore.stagingURL(for: reference)
            stagingURL = staging
            try Task.checkCancellation()
            try await downloader.download(plan: plan, to: staging) { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.downloadStates[reference] = .downloading(reference: reference, progress: progress)
                }
            }
            try Task.checkCancellation()
            downloadStates[reference] = .validating(reference: reference)
            let snapshot = try await modelStore.promote(plan: plan, from: staging)
            stagingURL = nil
            downloadedSnapshots.removeAll { $0.reference == snapshot.reference }
            downloadedSnapshots.append(snapshot)
            catalog = mergedCatalog(with: downloadedSnapshots)
            catalogEntries = ModelCatalog.catalogEntries(downloadedSnapshots: downloadedSnapshots)
            downloadStates[reference] = .downloaded(snapshot)
            downloadTask = nil
            activeDownloadReference = nil
            await refreshAvailability()
            return
        } catch is CancellationError {
            if let stagingURL { await modelStore.discardStagingURL(stagingURL) }
            downloadStates[reference] = .cancelled(reference: reference)
        } catch ModelDownloadError.cancelled {
            if let stagingURL { await modelStore.discardStagingURL(stagingURL) }
            downloadStates[reference] = .cancelled(reference: reference)
        } catch {
            if let stagingURL { await modelStore.discardStagingURL(stagingURL) }
            downloadStates[reference] = .failed(reference: reference, reason: mapDownloadError(error))
        }
        downloadTask = nil
        activeDownloadReference = nil
    }

    private func mergedCatalog(with snapshots: [LocalModelSnapshot]) -> [ModelDescriptor] {
        var seen = Set(baseCatalog.map(\.id))
        let downloadedDescriptors = snapshots.compactMap(\.descriptor).filter { seen.insert($0.id).inserted }
        return baseCatalog + downloadedDescriptors
    }

    private func advancedModelMessage(for error: AdvancedModelComposerError) -> String {
        switch error {
        case .missingModelFile(let label):
            return "\(label) does not contain a supported model weight file."
        case .ambiguousRepository(let label):
            return "\(label) contains multiple model weight files. Use a repository with exactly one."
        case .incompatibleModelFile(let label):
            return "\(label) is missing immutable integrity metadata."
        }
    }

    private func downloadedSnapshot(for reference: ModelRepositoryReference) -> LocalModelSnapshot? {
        downloadedSnapshots.first { $0.reference == reference && $0.compatibility.isSelectable }
    }

    private func mapDownloadError(_ error: Error) -> ModelDownloadError {
        if let error = error as? ModelDownloadError { return error }
        if let error = error as? ModelStoreError {
            return switch error {
            case .lowStorage(let required, let available): .lowStorage(required: required, available: available)
            case .integrityFailed(let path): .integrityFailed(path)
            case .unsafePath(let path),
                 .caseCollision(let path),
                 .executablePayload(let path),
                 .archivePayload(let path),
                 .symlinkEscape(let path),
                 .unexpectedFile(let path),
                 .hiddenFile(let path): .unsafeSnapshot(path)
            case .tooManyFiles: .tooManyFiles
            case .snapshotTooLarge: .snapshotTooLarge
            case .fileSystemFailure: .fileSystemFailure
            }
        }
        if error is CancellationError { return .cancelled }
        return .transportFailed
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
