import Darwin
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
        let verification = try VerifiedDownloadManifest(plan: plan, rootURL: staging)
        try JSONEncoder().encode(verification).write(
            to: staging.appendingPathComponent(VerifiedDownloadManifest.fileName),
            options: [.atomic]
        )

        let snapshot = try await store.promote(plan: plan, from: staging)
        let refreshed = await store.refreshSnapshots()

        XCTAssertFalse(FileManager.default.fileExists(atPath: staging.path))
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: snapshot.folderURL.appendingPathComponent(VerifiedDownloadManifest.fileName).path
            )
        )

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

    func testPersistsDownloadedCompositeDescriptorAcrossRefresh() async throws {
        let reference = AdvancedModelComposer.compositeReference
        let data = Data("composite".utf8)
        let fileURL = URL(string: "https://huggingface.co/custom/PublicModel/resolve/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/model.gguf")!
        let file = ModelDownloadFile(
            path: "advanced/model.gguf",
            sizeBytes: Int64(data.count),
            sha256: data.sha256String,
            downloadURL: fileURL
        )
        let profile = GenerationProfile(width: 512, height: 512, steps: 4, cfgScale: 1)
        let descriptor = ModelDescriptor(
            id: .advancedCustom,
            repository: reference,
            reviewedRevisionSHA: String(repeating: "a", count: 40),
            familyName: "Advanced Custom Model",
            summary: "Composite persistence fixture.",
            packageVersion: ModelCatalog.packageVersion,
            requirements: [
                .init(role: .diffusionModel, fileName: file.path, expectedByteCount: file.sizeBytes, sha256: file.sha256),
                .init(role: .vae, fileName: file.path, expectedByteCount: file.sizeBytes, sha256: file.sha256),
                .init(role: .textEncoder, fileName: file.path, expectedByteCount: file.sizeBytes, sha256: file.sha256)
            ],
            profile: profile,
            minimumAvailableMemoryBytes: 0,
            licenseApproved: true,
            evaluationApproved: true
        )
        let revision = try ResolvedModelRevision(
            reference: reference,
            commitSHA: descriptor.reviewedRevisionSHA!,
            license: "apache-2.0",
            totalSizeBytes: file.sizeBytes
        )
        let plan = ModelDownloadPlan(revision: revision, files: [file], descriptor: descriptor)
        let store = try ModelStore(documentsURL: documents, availableSpaceProvider: { 10_000 })
        let staging = try await store.stagingURL(for: reference)
        let stagedFile = staging.appendingPathComponent(file.path)
        try FileManager.default.createDirectory(at: stagedFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: stagedFile)

        _ = try await store.promote(plan: plan, from: staging)
        let refreshed = await store.refreshSnapshots().first

        XCTAssertEqual(refreshed?.descriptor, descriptor)
        XCTAssertEqual(refreshed?.compatibility, .compatible(profile: profile))
        XCTAssertEqual(ModelCatalog.catalogEntries(downloadedSnapshots: refreshed.map { [$0] } ?? []).last?.descriptor, descriptor)
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

    func testRefreshSnapshotsValidatesLargeSnapshotWithoutExcessiveFootprint() async throws {
        let reference = try ModelRepositoryReference("custom/LargeValidationFixture")
        let store = try ModelStore(documentsURL: documents)
        let folderName = ModelStore.safeFolderName(for: reference)
        let folderURL = store.modelRootURL.appendingPathComponent(folderName, isDirectory: true)
        let modelURL = folderURL.appendingPathComponent("model.gguf")
        let modelSize = Int64(256 * 1_024 * 1_024)
        let expectedHash = "a6d72ac7690f53be6ae46ba88506bd97302a093f7108472bd9efc3cefda06484"
        let file = ModelDownloadFile(
            path: "model.gguf",
            sizeBytes: modelSize,
            sha256: expectedHash,
            downloadURL: URL(string: "https://huggingface.co/custom/LargeValidationFixture/resolve/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/model.gguf")!
        )

        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try createSparseZeroFilledFile(at: modelURL, byteCount: modelSize)
        let metadata = SnapshotMetadataFixture(
            owner: reference.owner,
            repository: reference.repository,
            commitSHA: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            folderName: folderName,
            license: "apache-2.0",
            files: [file]
        )
        try JSONEncoder().encode(metadata).write(
            to: folderURL.appendingPathComponent(".mirage-snapshot.json"),
            options: [.atomic]
        )

        let baselineFootprint = try currentProcessFootprint()
        let sampler = ProcessFootprintSampler()
        let samplingTask = Task.detached(priority: .userInitiated) {
            try await sampler.samplePeak()
        }
        await sampler.waitUntilStarted()

        let snapshots = await store.refreshSnapshots()

        await sampler.stop()
        let peakFootprint = try await samplingTask.value
        let footprintGrowth = max(0, peakFootprint - baselineFootprint)

        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots.first?.reference, reference)
        XCTAssertEqual(snapshots.first?.files, [file])
        XCTAssertEqual(snapshots.first?.compatibility, .unknownCustomRepository)
        XCTAssertLessThan(
            footprintGrowth,
            Int64(96 * 1_024 * 1_024),
            "Refreshing a valid 256 MiB snapshot should not retain per-chunk read buffers. Growth: \(footprintGrowth) bytes."
        )
    }
}

private struct SnapshotMetadataFixture: Encodable {
    let owner: String
    let repository: String
    let commitSHA: String
    let folderName: String
    let license: String?
    let files: [ModelDownloadFile]
    let descriptor: ModelDescriptor? = nil
}

private actor ProcessFootprintSampler {
    private var isSampling = true
    private var started = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []

    func samplePeak() async throws -> Int64 {
        started = true
        startWaiters.forEach { $0.resume() }
        startWaiters.removeAll()

        var peak = try currentProcessFootprint()
        while isSampling {
            peak = max(peak, try currentProcessFootprint())
            await Task.yield()
        }
        return peak
    }

    func waitUntilStarted() async {
        guard !started else { return }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func stop() {
        isSampling = false
    }
}

private enum ProcessFootprintError: Error {
    case taskInfo(kern_return_t)
}

private func currentProcessFootprint() throws -> Int64 {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to: &info) { pointer in
        pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    guard result == KERN_SUCCESS else {
        throw ProcessFootprintError.taskInfo(result)
    }
    return Int64(info.phys_footprint)
}

private func createSparseZeroFilledFile(at url: URL, byteCount: Int64) throws {
    precondition(byteCount > 0)
    FileManager.default.createFile(atPath: url.path, contents: nil)
    let handle = try FileHandle(forWritingTo: url)
    defer { try? handle.close() }
    try handle.seek(toOffset: UInt64(byteCount - 1))
    try handle.write(contentsOf: Data([0]))
}
