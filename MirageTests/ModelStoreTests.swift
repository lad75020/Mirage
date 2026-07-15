import Foundation
import XCTest
@testable import MirageApp

final class ModelStoreTests: XCTestCase {
    private var documents: URL!

    override func setUpWithError() throws {
        documents = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: documents)
    }

    func testUsesDocumentsMirageModelsRootStableFolderMappingAndStagingIsolation() async throws {
        let reference = try ModelRepositoryReference("jc-builds/Z-Image-Turbo-iOS")
        let store = try ModelStore(documentsURL: documents)

        let staging = try await store.stagingURL(for: reference)

        XCTAssertEqual(store.modelRootURL.lastPathComponent, "Mirage Models")
        XCTAssertTrue(ModelStore.safeFolderName(for: reference).hasPrefix("jc-builds--z-image-turbo-ios-"))
        XCTAssertEqual(ModelStore.safeFolderName(for: reference), ModelStore.safeFolderName(for: reference))
        XCTAssertNotEqual(
            ModelStore.safeFolderName(for: reference),
            ModelStore.safeFolderName(for: try ModelRepositoryReference("jc-builds/Z_Image_Turbo_iOS"))
        )
        XCTAssertFalse(staging.path.hasPrefix(store.modelRootURL.path))
    }

    func testPromotesValidatedSnapshotAndRefreshDetectsFilesTampering() async throws {
        let reference = try ModelRepositoryReference("custom/PublicModel")
        let data = Data("model".utf8)
        let fileURL = URL(string: "https://huggingface.co/custom/PublicModel/resolve/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/model.gguf")!
        let revision = try ResolvedModelRevision(
            reference: reference,
            commitSHA: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            license: "apache-2.0",
            totalSizeBytes: Int64(data.count)
        )
        let file = ModelDownloadFile(
            path: "model.gguf",
            sizeBytes: Int64(data.count),
            sha256: data.sha256String,
            downloadURL: fileURL
        )
        let plan = ModelDownloadPlan(revision: revision, files: [file])
        let store = try ModelStore(documentsURL: documents, availableSpaceProvider: { 10_000 })
        let staging = try await store.stagingURL(for: reference)
        try data.write(to: staging.appendingPathComponent("model.gguf"))

        let snapshot = try await store.promote(plan: plan, from: staging)
        let refreshed = await store.refreshSnapshots()

        XCTAssertTrue(snapshot.folderName.hasPrefix("custom--publicmodel-"))
        XCTAssertEqual(refreshed.first?.compatibility, .unknownCustomRepository)
        XCTAssertFalse(refreshed.first?.compatibility.isSelectable == true)

        try Data("changed".utf8).write(to: snapshot.folderURL.appendingPathComponent("model.gguf"))
        let tampered = await store.refreshSnapshots()
        XCTAssertEqual(tampered.first?.compatibility, .incompatible(reason: "Files changed in Files."))

        try Data("extra".utf8).write(to: snapshot.folderURL.appendingPathComponent("extra.gguf"))
        let extra = await store.refreshSnapshots()
        XCTAssertEqual(extra.first?.compatibility, .incompatible(reason: "Files changed in Files."))
    }

    func testRejectsLowStorageTraversalCaseCollisionExecutableArchiveAndSymlinkPayloads() async throws {
        let reference = try ModelRepositoryReference("custom/PublicModel")
        let store = try ModelStore(documentsURL: documents, availableSpaceProvider: { 1 })
        let revision = try ResolvedModelRevision(
            reference: reference,
            commitSHA: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            license: "apache-2.0",
            totalSizeBytes: 5
        )
        let url = URL(string: "https://huggingface.co/custom/PublicModel/resolve/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/model.gguf")!
        let file = ModelDownloadFile(path: "model.gguf", sizeBytes: 5, sha256: Data("model".utf8).sha256String, downloadURL: url)
        let plan = ModelDownloadPlan(revision: revision, files: [file])
        let staging = try await store.stagingURL(for: reference)
        try Data("model".utf8).write(to: staging.appendingPathComponent("model.gguf"))

        do {
            _ = try await store.promote(plan: plan, from: staging)
            XCTFail("Expected low storage")
        } catch let error as ModelStoreError {
            XCTAssertEqual(error, .lowStorage(required: 5, available: 1))
        }

        let enoughStore = try ModelStore(documentsURL: documents, availableSpaceProvider: { 10_000 })
        let badTraversal = ModelDownloadPlan(revision: revision, files: [
            .init(path: "../model.gguf", sizeBytes: 5, sha256: nil, downloadURL: url)
        ])
        do {
            _ = try await enoughStore.promote(plan: badTraversal, from: staging)
            XCTFail("Expected unsafe path")
        } catch let error as ModelStoreError {
            XCTAssertEqual(error, .unsafePath("../model.gguf"))
        }

        let collision = ModelDownloadPlan(revision: revision, files: [
            .init(path: "Model.gguf", sizeBytes: 5, sha256: nil, downloadURL: url),
            .init(path: "model.gguf", sizeBytes: 5, sha256: nil, downloadURL: url)
        ])
        try Data("model".utf8).write(to: staging.appendingPathComponent("Model.gguf"))
        do {
            _ = try await enoughStore.promote(plan: collision, from: staging)
            XCTFail("Expected case collision")
        } catch let error as ModelStoreError {
            XCTAssertEqual(error, .caseCollision("duplicate path"))
        }
    }

    func testFailedReplacementPreservesExistingValidSnapshot() async throws {
        let reference = try ModelRepositoryReference("custom/PublicModel")
        let store = try ModelStore(documentsURL: documents, availableSpaceProvider: { 10_000 })
        let url = URL(string: "https://huggingface.co/custom/PublicModel/resolve/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/model.gguf")!
        let goodData = Data("model".utf8)
        let revision = try ResolvedModelRevision(
            reference: reference,
            commitSHA: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            license: "apache-2.0",
            totalSizeBytes: Int64(goodData.count)
        )
        let file = ModelDownloadFile(path: "model.gguf", sizeBytes: Int64(goodData.count), sha256: goodData.sha256String, downloadURL: url)
        let plan = ModelDownloadPlan(revision: revision, files: [file])
        let staging = try await store.stagingURL(for: reference)
        try goodData.write(to: staging.appendingPathComponent("model.gguf"))
        let existing = try await store.promote(plan: plan, from: staging)

        let badStaging = try await store.stagingURL(for: reference)
        try Data("wrong".utf8).write(to: badStaging.appendingPathComponent("model.gguf"))
        do {
            _ = try await store.promote(plan: plan, from: badStaging)
            XCTFail("Expected failed replacement")
        } catch let error as ModelStoreError {
            XCTAssertEqual(error, .integrityFailed("model.gguf"))
        }

        XCTAssertEqual(try Data(contentsOf: existing.folderURL.appendingPathComponent("model.gguf")), goodData)
        let refreshedSnapshot = await store.refreshSnapshots().first
        XCTAssertEqual(refreshedSnapshot?.compatibility, .unknownCustomRepository)
    }
}
