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

actor PreviewModelDownloader: ModelDownloading {
    private let shouldFailResolve: Bool
    private let slowDownload: Bool

    init(shouldFailResolve: Bool = false, slowDownload: Bool = false) {
        self.shouldFailResolve = shouldFailResolve
        self.slowDownload = slowDownload
    }

    func resolve(reference: ModelRepositoryReference) async throws -> ModelDownloadPlan {
        if shouldFailResolve { throw ModelDownloadError.transportFailed }
        let revision = try ResolvedModelRevision(
            reference: reference,
            commitSHA: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            license: "apache-2.0",
            totalSizeBytes: 0
        )
        return ModelDownloadPlan(revision: revision, files: [])
    }

    func download(
        plan: ModelDownloadPlan,
        to stagingURL: URL,
        progress: @escaping @Sendable (ModelDownloadProgress) -> Void
    ) async throws {
        progress(.init(completedBytes: 0, totalBytes: 0))
        if slowDownload {
            try await Task.sleep(for: .seconds(30))
            try Task.checkCancellation()
        }
    }
}

actor PreviewModelStore: ModelSnapshotStoring {
    nonisolated let modelRootURL: URL
    private let snapshots: [LocalModelSnapshot]

    init(availableID: ModelID? = .ernieImageTurbo) {
        let rootURL = URL(fileURLWithPath: "/tmp/Mirage Models", isDirectory: true)
        self.modelRootURL = rootURL
        if let descriptor = availableID.flatMap(ModelCatalog.descriptor(for:)),
           let reference = descriptor.repository,
           let revision = descriptor.reviewedRevisionSHA {
            self.snapshots = [
                LocalModelSnapshot(
                    reference: reference,
                    commitSHA: revision,
                    folderName: ModelStore.safeFolderName(for: reference),
                    folderURL: rootURL.appendingPathComponent(ModelStore.safeFolderName(for: reference)),
                    files: descriptor.requirements.map {
                        ModelDownloadFile(
                            path: $0.fileName,
                            sizeBytes: $0.expectedByteCount ?? 1,
                            sha256: $0.sha256,
                            downloadURL: URL(string: "https://huggingface.co/\(reference.id)/resolve/\(revision)/\($0.fileName)")!
                        )
                    },
                    license: "apache-2.0",
                    compatibility: .compatible(profile: descriptor.profile)
                )
            ]
        } else {
            self.snapshots = []
        }
    }

    func stagingURL(for reference: ModelRepositoryReference) async throws -> URL {
        URL(fileURLWithPath: "/tmp/\(ModelStore.safeFolderName(for: reference))-staging", isDirectory: true)
    }

    func discardStagingURL(_ url: URL) async {}

    func validateCanStore(plan: ModelDownloadPlan) async throws {}

    func promote(plan: ModelDownloadPlan, from stagingURL: URL) async throws -> LocalModelSnapshot {
        LocalModelSnapshot(
            reference: plan.revision.reference,
            commitSHA: plan.revision.commitSHA,
            folderName: ModelStore.safeFolderName(for: plan.revision.reference),
            folderURL: modelRootURL.appendingPathComponent(ModelStore.safeFolderName(for: plan.revision.reference)),
            files: plan.files,
            license: plan.revision.license,
            compatibility: .unknownCustomRepository
        )
    }

    func refreshSnapshots() async -> [LocalModelSnapshot] { snapshots }
    func availableBytes() async -> Int64 { .max }
}

@MainActor
enum PreviewDependencies {
    static func makeViewModel() -> ImageGenerationViewModel {
        let arguments = ProcessInfo.processInfo.arguments
        let availableID: ModelID? = arguments.contains("--ui-test-no-model") ? nil : .ernieImageTurbo
        let provider = StaticModelProvider(availableID: availableID)
        let downloader = PreviewModelDownloader(
            shouldFailResolve: arguments.contains("--ui-test-download-failure"),
            slowDownload: arguments.contains("--ui-test-slow-download")
        )
        let store = PreviewModelStore(availableID: availableID)
        return ImageGenerationViewModel(
            availabilityProvider: provider,
            generator: PreviewGenerator(shouldFail: arguments.contains("--ui-test-generation-failure")),
            safetyService: PreviewSafetyService(refusesPrompt: arguments.contains("--ui-test-refusal")),
            photoSaver: PreviewPhotoSaver(status: arguments.contains("--ui-test-photos-denied") ? .denied : .authorized),
            downloader: downloader,
            modelStore: store
        )
    }
}
#endif
