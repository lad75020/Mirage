import Foundation
import XCTest
@testable import MirageApp

final class ModelEvaluationTests: XCTestCase {
    private struct Manifest: Decodable {
        struct Candidate: Decodable {
            struct Reference: Decodable {
                let owner: String
                let repository: String
                let commitSHA: String
                let visibility: String
                let gated: Bool
            }
            struct File: Decodable {
                let name: String
                let bytes: Int64
                let sha256: String
            }
            struct Profile: Decodable {
                let width: Int
                let height: Int
                let steps: Int
                let cfgScale: Float
            }
            let id: String
            let reference: Reference
            let license: String
            let licenseApproved: Bool
            let evaluationApproved: Bool
            let minimumAvailableMemoryBytes: UInt64
            let profile: Profile
            let files: [File]
            let releaseBlockers: [String]
        }
        struct CustomPolicy: Decodable {
            let defaultCompatibility: String
            let evaluationApproved: Bool
            let tokenOrPrivateRepositorySupport: Bool
            let releaseBehavior: String
        }
        let schemaVersion: Int
        let policyVersion: String
        let models: [Candidate]
        let customRepositoryPolicy: CustomPolicy
    }

    func testEvaluationManifestMatchesFeaturedCatalogCandidates() throws {
        let bundle = Bundle(for: Self.self)
        let url = bundle.url(
            forResource: "ModelEvaluationManifest",
            withExtension: "json",
            subdirectory: "AIEvaluation"
        ) ?? bundle.url(forResource: "ModelEvaluationManifest", withExtension: "json")
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: try XCTUnwrap(url)))
        XCTAssertEqual(manifest.schemaVersion, 2)
        XCTAssertEqual(manifest.policyVersion, PromptSafetyPolicy.version)
        XCTAssertEqual(manifest.models.map(\.reference.owner), ["jc-builds", "jc-builds", "jc-builds"])
        XCTAssertEqual(manifest.models.map(\.reference.repository), [
            "Z-Image-Turbo-iOS",
            "ERNIE-Image-Turbo-iOS",
            "Chroma1-HD-iOS"
        ])

        for candidate in manifest.models {
            let reference = try ModelRepositoryReference(
                owner: candidate.reference.owner,
                repository: candidate.reference.repository
            )
            let descriptor = try XCTUnwrap(ModelCatalog.descriptor(for: reference))
            XCTAssertEqual(candidate.id, descriptor.id.rawValue)
            XCTAssertEqual(candidate.reference.commitSHA, descriptor.reviewedRevisionSHA)
            XCTAssertEqual(candidate.license, "apache-2.0")
            XCTAssertEqual(candidate.reference.visibility, "public")
            XCTAssertFalse(candidate.reference.gated)
            XCTAssertEqual(candidate.licenseApproved, descriptor.licenseApproved)
            XCTAssertEqual(candidate.evaluationApproved, descriptor.evaluationApproved)
            XCTAssertEqual(candidate.minimumAvailableMemoryBytes, descriptor.minimumAvailableMemoryBytes)
            XCTAssertEqual(candidate.profile.width, descriptor.profile.width)
            XCTAssertEqual(candidate.profile.height, descriptor.profile.height)
            XCTAssertEqual(candidate.profile.steps, descriptor.profile.steps)
            XCTAssertEqual(candidate.profile.cfgScale, descriptor.profile.cfgScale)
            XCTAssertEqual(
                candidate.evaluationApproved,
                candidate.id == ModelID.zImageTurbo.rawValue
            )
            XCTAssertFalse(candidate.releaseBlockers.isEmpty)
            XCTAssertEqual(Set(candidate.files.map(\.name)), Set(descriptor.requirements.map(\.fileName)))
            XCTAssertEqual(Set(candidate.files.map(\.sha256)), Set(descriptor.requirements.compactMap(\.sha256)))
            XCTAssertTrue(candidate.files.allSatisfy { $0.sha256.count == 64 })
            XCTAssertTrue(candidate.files.allSatisfy { $0.bytes > 0 })
        }
        XCTAssertEqual(
            manifest.models.filter(\.evaluationApproved).map(\.id),
            [ModelID.zImageTurbo.rawValue]
        )
    }

    func testCustomRepositoryEvaluationPolicyFailsClosedByDefault() throws {
        let bundle = Bundle(for: Self.self)
        let url = bundle.url(
            forResource: "ModelEvaluationManifest",
            withExtension: "json",
            subdirectory: "AIEvaluation"
        ) ?? bundle.url(forResource: "ModelEvaluationManifest", withExtension: "json")
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: try XCTUnwrap(url)))

        XCTAssertEqual(manifest.customRepositoryPolicy.defaultCompatibility, "unknownCustomRepository")
        XCTAssertFalse(manifest.customRepositoryPolicy.evaluationApproved)
        XCTAssertFalse(manifest.customRepositoryPolicy.tokenOrPrivateRepositorySupport)
        XCTAssertEqual(manifest.customRepositoryPolicy.releaseBehavior, "downloadable-but-unselectable-until-local-validation")
    }

    func testEveryEnabledModelWouldRequireCompleteEvidence() {
        for descriptor in ModelCatalog.entries where descriptor.evaluationApproved {
            XCTAssertTrue(descriptor.licenseApproved)
            XCTAssertFalse(descriptor.requirements.isEmpty)
            XCTAssertTrue(descriptor.requirements.allSatisfy { $0.expectedByteCount != nil })
            XCTAssertTrue(descriptor.requirements.allSatisfy { $0.sha256?.count == 64 })
        }
    }

    func testLowMemoryReturnsDeterministicFallbackReason() async throws {
        let descriptor = ModelDescriptor.testFixture(
            requirements: [
                .init(
                    role: .diffusionModel,
                    fileName: "model.gguf",
                    sha256: String(repeating: "a", count: 64)
                )
            ],
            minimumAvailableMemoryBytes: 8_000
        )
        let resolver = try ModelFileResolver(
            rootURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
            memoryProvider: FixedMemoryProvider(bytes: 7_999),
            protectedDataProvider: FixedProtectedDataProvider(available: true)
        )
        let availability = await resolver.availability(for: descriptor)
        XCTAssertEqual(availability, .insufficientMemory(required: 8_000, available: 7_999))
    }
}
