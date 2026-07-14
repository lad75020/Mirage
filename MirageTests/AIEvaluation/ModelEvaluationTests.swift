import Foundation
import XCTest
@testable import MirageApp

final class ModelEvaluationTests: XCTestCase {
    private struct Manifest: Decodable {
        struct Candidate: Decodable {
            struct File: Decodable {
                let name: String
                let bytes: Int64
                let sha256: String
            }
            let id: String
            let licenseApproved: Bool
            let evaluationApproved: Bool
            let minimumAvailableMemoryBytes: UInt64
            let files: [File]
            let releaseBlockers: [String]
        }
        let schemaVersion: Int
        let policyVersion: String
        let models: [Candidate]
    }

    func testEvaluationManifestMatchesClosedCatalogCandidate() throws {
        let bundle = Bundle(for: Self.self)
        let url = bundle.url(
            forResource: "ModelEvaluationManifest",
            withExtension: "json",
            subdirectory: "AIEvaluation"
        ) ?? bundle.url(forResource: "ModelEvaluationManifest", withExtension: "json")
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: try XCTUnwrap(url)))
        XCTAssertEqual(manifest.schemaVersion, 1)
        XCTAssertEqual(manifest.policyVersion, PromptSafetyPolicy.version)

        let candidate = try XCTUnwrap(manifest.models.first { $0.id == ModelID.ernieImageTurbo.rawValue })
        let descriptor = try XCTUnwrap(ModelCatalog.descriptor(for: .ernieImageTurbo))
        XCTAssertEqual(candidate.licenseApproved, descriptor.licenseApproved)
        XCTAssertEqual(candidate.evaluationApproved, descriptor.evaluationApproved)
        XCTAssertEqual(candidate.minimumAvailableMemoryBytes, descriptor.minimumAvailableMemoryBytes)
        XCTAssertFalse(candidate.evaluationApproved)
        XCTAssertFalse(candidate.releaseBlockers.isEmpty)
        XCTAssertEqual(Set(candidate.files.map(\.name)), Set(descriptor.requirements.map(\.fileName)))
        XCTAssertEqual(candidate.files.map(\.sha256), descriptor.requirements.compactMap(\.sha256))
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
