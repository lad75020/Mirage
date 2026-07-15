import XCTest
@testable import MirageApp

final class AdvancedCompositeModelTests: XCTestCase {
    func testComposerMapsTokenizerTransformerAndVAEToInferenceRoles() throws {
        let tokenizer = try plan(reference: "owner/tokenizer", file: "tokenizer.gguf", byte: 1)
        let transformer = try plan(reference: "owner/transformer", file: "transformer.gguf", byte: 2)
        let vae = try plan(reference: "owner/vae", file: "vae.safetensors", byte: 3)

        let composed = try AdvancedModelComposer.compose(
            tokenizer: tokenizer,
            transformer: transformer,
            vae: vae
        )

        XCTAssertEqual(composed.descriptor?.id, .advancedCustom)
        XCTAssertEqual(composed.descriptor?.requirements.map(\.role), [.textEncoder, .diffusionModel, .vae])
        XCTAssertEqual(composed.files.map(\.path), [
            "advanced/tokenizer/tokenizer.gguf",
            "advanced/transformer/transformer.gguf",
            "advanced/vae/vae.safetensors"
        ])
        XCTAssertEqual(composed.revision.reference, AdvancedModelComposer.compositeReference)
    }

    func testComposerRejectsAmbiguousRepositoriesInsteadOfChoosingUnexpectedWeights() throws {
        let ambiguous = try plan(
            reference: "owner/tokenizer",
            files: [("one.gguf", 1), ("two.gguf", 2)]
        )
        let transformer = try plan(reference: "owner/transformer", file: "transformer.gguf", byte: 2)
        let vae = try plan(reference: "owner/vae", file: "vae.safetensors", byte: 3)

        XCTAssertThrowsError(
            try AdvancedModelComposer.compose(tokenizer: ambiguous, transformer: transformer, vae: vae)
        ) { error in
            XCTAssertEqual(error as? AdvancedModelComposerError, .ambiguousRepository("Tokenizer"))
        }
    }

    func testSnapshotDescriptorMakesComposedModelSelectableAfterReload() throws {
        let tokenizer = try plan(reference: "owner/tokenizer", file: "tokenizer.gguf", byte: 1)
        let transformer = try plan(reference: "owner/transformer", file: "transformer.gguf", byte: 2)
        let vae = try plan(reference: "owner/vae", file: "vae.safetensors", byte: 3)
        let composed = try AdvancedModelComposer.compose(tokenizer: tokenizer, transformer: transformer, vae: vae)
        let descriptor = try XCTUnwrap(composed.descriptor)
        let snapshot = LocalModelSnapshot(
            reference: composed.revision.reference,
            commitSHA: composed.revision.commitSHA,
            folderName: "advanced",
            folderURL: URL(fileURLWithPath: "/tmp/advanced"),
            files: composed.files,
            license: composed.revision.license,
            compatibility: .unknownCustomRepository,
            descriptor: descriptor
        )

        XCTAssertEqual(ModelCatalog.compatibility(for: snapshot), .compatible(profile: descriptor.profile))
        let entry = try XCTUnwrap(ModelCatalog.catalogEntries(downloadedSnapshots: [snapshot]).last)
        XCTAssertEqual(entry.descriptor, descriptor)
    }

    @MainActor
    func testViewModelDownloadsThreeReferencesAsOneSelectableModel() async throws {
        let tokenizerReference = try ModelRepositoryReference("owner/tokenizer")
        let transformerReference = try ModelRepositoryReference("owner/transformer")
        let vaeReference = try ModelRepositoryReference("owner/vae")
        let downloader = StubModelDownloader()
        await downloader.setPlan(try plan(reference: tokenizerReference.id, file: "tokenizer.gguf", byte: 1), for: tokenizerReference)
        await downloader.setPlan(try plan(reference: transformerReference.id, file: "transformer.gguf", byte: 2), for: transformerReference)
        await downloader.setPlan(try plan(reference: vaeReference.id, file: "vae.safetensors", byte: 3), for: vaeReference)
        let viewModel = ImageGenerationViewModel(
            catalog: [],
            availabilityProvider: StubAvailabilityProvider(availabilityByID: [.advancedCustom: .available]),
            generator: StubGenerator(),
            safetyService: PassingSafetyService(),
            photoSaver: StubPhotoSaver(),
            downloader: downloader,
            modelStore: StubModelStore()
        )

        XCTAssertFalse(viewModel.canDownloadAdvancedModel)
        viewModel.tokenizerReferenceInput = tokenizerReference.id
        viewModel.transformerReferenceInput = transformerReference.id
        viewModel.vaeReferenceInput = vaeReference.id
        XCTAssertTrue(viewModel.canDownloadAdvancedModel)

        await viewModel.submitAdvancedModel()
        await waitUntil { !viewModel.operationLocked }

        let resolvedReferences = await downloader.resolvedReferences
        XCTAssertEqual(Set(resolvedReferences), Set([tokenizerReference, transformerReference, vaeReference]))
        XCTAssertEqual(resolvedReferences.count, 3)
        XCTAssertEqual(viewModel.downloadedSnapshots.count, 1)
        XCTAssertEqual(viewModel.catalog.last?.id, .advancedCustom)
        await viewModel.selectModel(.advancedCustom)
        XCTAssertEqual(viewModel.selectedModelID, .advancedCustom)
    }

    private func plan(reference: String, file: String, byte: Int64) throws -> ModelDownloadPlan {
        try plan(reference: reference, files: [(file, byte)])
    }

    private func plan(reference: String, files: [(String, Int64)]) throws -> ModelDownloadPlan {
        let reference = try ModelRepositoryReference(reference)
        let revision = try ResolvedModelRevision(
            reference: reference,
            commitSHA: String(repeating: "a", count: 40),
            license: "apache-2.0",
            totalSizeBytes: files.reduce(0) { $0 + $1.1 }
        )
        return ModelDownloadPlan(
            revision: revision,
            files: files.map { file, bytes in
                ModelDownloadFile(
                    path: file,
                    sizeBytes: bytes,
                    sha256: String(repeating: "b", count: 64),
                    downloadURL: URL(string: "https://huggingface.co/\(reference.id)/resolve/\(revision.commitSHA)/\(file)")!
                )
            }
        )
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
}
