import XCTest
@testable import MirageApp

@MainActor
final class ImageGenerationViewModelModelSelectionTests: XCTestCase {
    func testRefreshDoesNotAutoSelectFirstAvailableModel() async {
        let descriptor = ModelCatalog.descriptor(for: .ernieImageTurbo)!
        let resolver = StubAvailabilityProvider(availabilityByID: [descriptor.id: .available])
        let viewModel = ImageGenerationViewModel(
            catalog: [descriptor],
            availabilityProvider: resolver,
            generator: StubGenerator(),
            safetyService: PassingSafetyService(),
            photoSaver: StubPhotoSaver()
        )

        await viewModel.refreshAvailability()

        XCTAssertNil(viewModel.selectedModelID)
        XCTAssertFalse(viewModel.canSend)
    }

    func testExplicitSelectionRequiresDownloadedCompatibleSnapshotAfterRefresh() async {
        let descriptor = ModelCatalog.descriptor(for: .ernieImageTurbo)!
        let reference = descriptor.repository!
        let compatible = LocalModelSnapshot.compatibleFixture(descriptor: descriptor)
        let store = StubModelStore(snapshots: [compatible])
        let resolver = StubAvailabilityProvider(availabilityByID: [descriptor.id: .available])
        let viewModel = ImageGenerationViewModel(
            catalog: [descriptor],
            availabilityProvider: resolver,
            generator: StubGenerator(),
            safetyService: PassingSafetyService(),
            photoSaver: StubPhotoSaver(),
            downloader: StubModelDownloader(),
            modelStore: store
        )

        await viewModel.selectModel(descriptor.id)

        XCTAssertEqual(viewModel.selectedModelID, descriptor.id)
        XCTAssertEqual(viewModel.downloadedSnapshots.map(\.reference), [reference])
    }

    func testFilesRemovalInvalidatesSelectionBeforeSend() async {
        let descriptor = ModelCatalog.descriptor(for: .ernieImageTurbo)!
        let store = StubModelStore(snapshots: [.compatibleFixture(descriptor: descriptor)])
        let resolver = StubAvailabilityProvider(availabilityByID: [descriptor.id: .available])
        let generator = StubGenerator()
        let viewModel = ImageGenerationViewModel(
            catalog: [descriptor],
            availabilityProvider: resolver,
            generator: generator,
            safetyService: PassingSafetyService(),
            photoSaver: StubPhotoSaver(),
            downloader: StubModelDownloader(),
            modelStore: store
        )
        await viewModel.selectModel(descriptor.id)
        await store.replaceSnapshots([])
        await resolver.setAvailability(.missingFiles(["model.gguf"]), for: descriptor.id)
        viewModel.prompt = "A paper sculpture"

        await viewModel.generate()

        XCTAssertNil(viewModel.selectedModelID)
        let requestCount = await generator.requestCount()
        XCTAssertEqual(requestCount, 0)
        guard case .failed(.modelUnavailable, _) = viewModel.state else {
            return XCTFail("Expected stale selection to be invalidated before SEND")
        }
    }

    func testRequestDownloadCreatesPendingConfirmationWithoutSelecting() async throws {
        let descriptor = ModelCatalog.descriptor(for: .ernieImageTurbo)!
        let reference = descriptor.repository!
        let downloader = StubModelDownloader()
        await downloader.setPlan(try .fixture(reference: reference, bytes: 1_024))
        let viewModel = ImageGenerationViewModel(
            catalog: [descriptor],
            availabilityProvider: StubAvailabilityProvider(availabilityByID: [descriptor.id: .available]),
            generator: StubGenerator(),
            safetyService: PassingSafetyService(),
            photoSaver: StubPhotoSaver(),
            downloader: downloader,
            modelStore: StubModelStore()
        )

        await viewModel.requestDownload(for: reference)

        XCTAssertNotNil(viewModel.pendingDownloadPlan)
        XCTAssertNil(viewModel.selectedModelID)
        guard case .awaitingConfirmation(_, let size, let license) = viewModel.downloadState(for: reference) else {
            return XCTFail("Expected confirmation state")
        }
        XCTAssertEqual(size, 1_024)
        XCTAssertEqual(license, "apache-2.0")
    }

    func testConfirmDownloadPromotesRefreshesCatalogAndDoesNotSelect() async throws {
        let descriptor = ModelCatalog.descriptor(for: .ernieImageTurbo)!
        let reference = descriptor.repository!
        let downloader = StubModelDownloader()
        await downloader.setPlan(try .fixture(reference: reference, bytes: 1))
        let store = StubModelStore()
        let viewModel = ImageGenerationViewModel(
            catalog: [descriptor],
            availabilityProvider: StubAvailabilityProvider(availabilityByID: [descriptor.id: .available]),
            generator: StubGenerator(),
            safetyService: PassingSafetyService(),
            photoSaver: StubPhotoSaver(),
            downloader: downloader,
            modelStore: store
        )

        await viewModel.requestDownload(for: reference)
        viewModel.confirmDownload()
        await waitUntil { viewModel.downloadedSnapshots.count == 1 }

        XCTAssertEqual(viewModel.downloadedSnapshots.first?.reference, reference)
        XCTAssertNil(viewModel.selectedModelID)
        guard case .downloaded = viewModel.downloadState(for: reference) else {
            return XCTFail("Expected downloaded state")
        }
    }

    func testValidatedDownloadUnlocksSelectionBeforeAvailabilityRefreshCompletes() async throws {
        let descriptor = ModelCatalog.descriptor(for: .zImageTurbo)!
        let reference = descriptor.repository!
        let snapshot = LocalModelSnapshot.compatibleFixture(descriptor: descriptor)
        let downloader = StubModelDownloader()
        await downloader.setPlan(try .fixture(reference: reference, bytes: 1))
        let store = StubModelStore(promotedSnapshot: snapshot)
        let resolver = BlockingAvailabilityProvider()
        let viewModel = ImageGenerationViewModel(
            catalog: [descriptor],
            availabilityProvider: resolver,
            generator: StubGenerator(),
            safetyService: PassingSafetyService(),
            photoSaver: StubPhotoSaver(),
            downloader: downloader,
            modelStore: store
        )

        await viewModel.requestDownload(for: reference)
        viewModel.confirmDownload()
        await resolver.waitUntilStarted()

        let wasLockedAfterValidation = viewModel.operationLocked
        let downloadedCompatibility = viewModel.catalogEntries
            .first(where: { $0.reference == reference })?
            .snapshot?
            .compatibility
        await resolver.release()
        await waitUntil { !viewModel.operationLocked }

        XCTAssertEqual(downloadedCompatibility, .compatible(profile: descriptor.profile))
        XCTAssertFalse(wasLockedAfterValidation)
        await viewModel.selectModel(descriptor.id)
        XCTAssertEqual(viewModel.selectedModelID, descriptor.id)
    }

    func testCancelAndRetryUseTypedStates() async throws {
        let descriptor = ModelCatalog.descriptor(for: .ernieImageTurbo)!
        let reference = descriptor.repository!
        let viewModel = ImageGenerationViewModel(
            catalog: [descriptor],
            availabilityProvider: StubAvailabilityProvider(availabilityByID: [descriptor.id: .available]),
            generator: StubGenerator(),
            safetyService: PassingSafetyService(),
            photoSaver: StubPhotoSaver(),
            downloader: StubModelDownloader(),
            modelStore: StubModelStore()
        )

        await viewModel.requestDownload(for: reference)
        viewModel.cancelDownload()
        guard case .cancelled = viewModel.downloadState(for: reference) else {
            return XCTFail("Expected cancelled state")
        }

        await viewModel.retryDownload(for: reference)
        guard case .awaitingConfirmation = viewModel.downloadState(for: reference) else {
            return XCTFail("Expected retry to return to confirmation")
        }
    }

    func testCustomReferenceValidationIsUserSafe() async {
        let viewModel = ImageGenerationViewModel(
            catalog: [],
            availabilityProvider: StubAvailabilityProvider(availabilityByID: [:]),
            generator: StubGenerator(),
            safetyService: PassingSafetyService(),
            photoSaver: StubPhotoSaver(),
            downloader: StubModelDownloader(),
            modelStore: StubModelStore()
        )

        viewModel.customReferenceInput = "https://example.com/private/model"
        await viewModel.submitCustomReference()

        XCTAssertEqual(viewModel.customReferenceError, "Enter a public Hugging Face model reference.")
    }
}

private extension LocalModelSnapshot {
    static func compatibleFixture(descriptor: ModelDescriptor) -> LocalModelSnapshot {
        let reference = descriptor.repository!
        let revision = descriptor.reviewedRevisionSHA ?? "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        return LocalModelSnapshot(
            reference: reference,
            commitSHA: revision,
            folderName: ModelStore.safeFolderName(for: reference),
            folderURL: URL(fileURLWithPath: "/tmp/Mirage Models").appendingPathComponent(ModelStore.safeFolderName(for: reference)),
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
    }
}

private extension ModelDownloadPlan {
    static func fixture(reference: ModelRepositoryReference, bytes: Int64) throws -> ModelDownloadPlan {
        let revision = try ResolvedModelRevision(
            reference: reference,
            commitSHA: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            license: "apache-2.0",
            totalSizeBytes: bytes
        )
        let file = ModelDownloadFile(
            path: "model.gguf",
            sizeBytes: bytes,
            sha256: String(repeating: "a", count: 64),
            downloadURL: URL(string: "https://huggingface.co/\(reference.id)/resolve/\(revision.commitSHA)/model.gguf")!
        )
        return ModelDownloadPlan(revision: revision, files: [file])
    }
}

private actor BlockingAvailabilityProvider: ModelAvailabilityProviding {
    private var started = false
    private var released = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiter: CheckedContinuation<Void, Never>?

    func availability(for descriptor: ModelDescriptor) async -> ModelAvailability {
        started = true
        startWaiters.forEach { $0.resume() }
        startWaiters.removeAll()
        if !released {
            await withCheckedContinuation { releaseWaiter = $0 }
        }
        return .available
    }

    func resolve(_ descriptor: ModelDescriptor) async throws -> ResolvedModelFiles {
        .init(diffusionModel: URL(fileURLWithPath: "/tmp/model.gguf"))
    }

    func waitUntilStarted() async {
        guard !started else { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func release() {
        released = true
        releaseWaiter?.resume()
        releaseWaiter = nil
    }
}

@MainActor
private func waitUntil(
    timeout: TimeInterval = 2,
    condition: @escaping @MainActor () -> Bool
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition(), Date() < deadline {
        try? await Task.sleep(for: .milliseconds(20))
    }
}
