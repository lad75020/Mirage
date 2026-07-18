import XCTest
@testable import MirageApp

final class ModelCatalogTests: XCTestCase {
    func testFeaturedCatalogListsThreePublicRepositoriesInDocumentedOrder() {
        XCTAssertEqual(
            ModelCatalog.featuredReferences.map(\.id),
            [
                "jc-builds/Z-Image-Turbo-iOS",
                "jc-builds/ERNIE-Image-Turbo-iOS",
                "jc-builds/Chroma1-HD-iOS"
            ]
        )
        XCTAssertEqual(ModelCatalog.entries.map(\.repository?.id), ModelCatalog.featuredReferences.map(\.id))
        XCTAssertEqual(ModelCatalog.entries.map(\.packageVersion), Array(repeating: "0.2.0", count: 3))
    }

    func testFeaturedMetadataEncodesReviewedRevisionsLicensesFilesAndHashes() throws {
        let z = try XCTUnwrap(ModelCatalog.descriptor(for: .zImageTurbo))
        XCTAssertEqual(z.reviewedRevisionSHA, "97ae389b962ee927d83c1911be743c8d82c11674")
        XCTAssertTrue(z.licenseApproved)
        XCTAssertEqual(z.requirements.map(\.fileName), [
            "Qwen3-4B-Instruct-2507-Q4_K_M.gguf",
            "ae.safetensors",
            "z-image-turbo-Q3_K_M.gguf"
        ])
        XCTAssertEqual(z.requirements.map(\.expectedByteCount), [2_497_281_120, 335_304_388, 4_186_161_216])
        XCTAssertEqual(z.requirements.map(\.sha256), [
            "3605803b982cb64aead44f6c1b2ae36e3acdb41d8e46c8a94c6533bc4c67e597",
            "afc8e28272cd15db3919bacdb6918ce9c1ed22e96cb12c4d5ed0fba823529e38",
            "7070b605165c372833c21c6bd45e73b242cf0db261b4d5436039363f3dbd4e0e"
        ])

        let ernie = try XCTUnwrap(ModelCatalog.descriptor(for: .ernieImageTurbo))
        XCTAssertEqual(ernie.reviewedRevisionSHA, "f23d470af1a57a64aa034d0770e74f99aac6135f")
        XCTAssertTrue(ernie.licenseApproved)

        let chroma = try XCTUnwrap(ModelCatalog.descriptor(for: .chroma1HD))
        XCTAssertEqual(chroma.reviewedRevisionSHA, "722a672dca0d2ec5ff39dea561ae0df62bf49995")
        XCTAssertTrue(chroma.licenseApproved)
        XCTAssertEqual(chroma.requirements.map(\.expectedByteCount), [5_432_053_920, 335_304_388, 9_787_841_024])
    }

    func testAllFeaturedModelsAreEvaluationApproved() {
        XCTAssertTrue(ModelCatalog.entries.allSatisfy(\.evaluationApproved))
    }

    func testZImageUsesMemorySafeRuntimeThreshold() throws {
        let descriptor = try XCTUnwrap(ModelCatalog.descriptor(for: .zImageTurbo))
        XCTAssertEqual(descriptor.minimumAvailableMemoryBytes, 6_000_000_000)
    }

    func testDocumentedZImageSnapshotIsCompatibleAndSelectable() throws {
        let descriptor = try XCTUnwrap(ModelCatalog.descriptor(for: .zImageTurbo))
        let reference = try XCTUnwrap(descriptor.repository)
        let revision = try XCTUnwrap(descriptor.reviewedRevisionSHA)
        let snapshot = LocalModelSnapshot(
            reference: reference,
            commitSHA: revision,
            folderName: ModelStore.safeFolderName(for: reference),
            folderURL: URL(fileURLWithPath: "/tmp/Mirage Models")
                .appendingPathComponent(ModelStore.safeFolderName(for: reference)),
            files: descriptor.requirements.map { requirement in
                ModelDownloadFile(
                    path: requirement.fileName,
                    sizeBytes: requirement.expectedByteCount ?? 0,
                    sha256: requirement.sha256,
                    downloadURL: URL(
                        string: "https://huggingface.co/\(reference.id)/resolve/\(revision)/\(requirement.fileName)"
                    )!
                )
            },
            license: "apache-2.0",
            compatibility: .unknownCustomRepository
        )

        XCTAssertTrue(descriptor.evaluationApproved)
        XCTAssertEqual(
            ModelCatalog.compatibility(for: snapshot),
            .compatible(profile: descriptor.profile)
        )
        XCTAssertTrue(ModelCatalog.compatibility(for: snapshot).isSelectable)
    }

    func testFeaturedCatalogApprovalSupersedesStaleSnapshotDescriptor() throws {
        let approved = try XCTUnwrap(ModelCatalog.descriptor(for: .ernieImageTurbo))
        let staleDescriptor = ModelDescriptor(
            id: approved.id,
            repository: approved.repository,
            reviewedRevisionSHA: approved.reviewedRevisionSHA,
            familyName: approved.familyName,
            summary: approved.summary,
            packageVersion: approved.packageVersion,
            requirements: approved.requirements,
            profile: approved.profile,
            minimumAvailableMemoryBytes: approved.minimumAvailableMemoryBytes,
            licenseApproved: approved.licenseApproved,
            evaluationApproved: false,
            minimumOSMajorVersion: approved.minimumOSMajorVersion,
            supportedDeviceIdentifiers: approved.supportedDeviceIdentifiers,
            profileApproved: approved.profileApproved,
            safetyPolicyVersion: approved.safetyPolicyVersion
        )
        let snapshot = LocalModelSnapshot(
            reference: try XCTUnwrap(approved.repository),
            commitSHA: try XCTUnwrap(approved.reviewedRevisionSHA),
            folderName: "featured-stale-descriptor",
            folderURL: URL(fileURLWithPath: "/tmp/featured-stale-descriptor"),
            files: approved.requirements.map {
                ModelDownloadFile(
                    path: $0.fileName,
                    sizeBytes: $0.expectedByteCount ?? 0,
                    sha256: $0.sha256,
                    downloadURL: URL(fileURLWithPath: "/tmp/\($0.fileName)")
                )
            },
            license: "apache-2.0",
            compatibility: .unknownCustomRepository,
            descriptor: staleDescriptor
        )

        XCTAssertEqual(ModelCatalog.compatibility(for: snapshot), .compatible(profile: approved.profile))
    }

    func testCustomDownloadedSnapshotsAreIncludedButClosedByDefault() throws {
        let reference = try ModelRepositoryReference("somebody/Public-Compatible-Later")
        let snapshot = LocalModelSnapshot(
            reference: reference,
            commitSHA: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            folderName: "somebody--public-compatible-later",
            folderURL: URL(fileURLWithPath: "/tmp/somebody--public-compatible-later"),
            files: [],
            license: "apache-2.0",
            compatibility: .unknownCustomRepository
        )

        let entries = ModelCatalog.catalogEntries(downloadedSnapshots: [snapshot])
        XCTAssertEqual(entries.last?.reference, reference)
        XCTAssertEqual(entries.last?.compatibility, .unknownCustomRepository)
        XCTAssertFalse(entries.last?.compatibility.isSelectable == true)
    }
}
