import XCTest
@testable import MirageApp

final class ModelCatalogTests: XCTestCase {
    func testCatalogListsAllSupportedFamiliesInDocumentedOrder() {
        XCTAssertEqual(ModelCatalog.entries.map(\.id), ModelID.allCases)
        XCTAssertEqual(ModelCatalog.entries.count, 8)
        XCTAssertEqual(ModelCatalog.entries.map(\.packageVersion), Array(repeating: "0.2.0", count: 8))
        XCTAssertTrue(ModelCatalog.entries.allSatisfy { $0.minimumOSMajorVersion == 26 })
        XCTAssertTrue(ModelCatalog.entries.allSatisfy { $0.profileApproved })
        XCTAssertTrue(ModelCatalog.entries.allSatisfy { $0.safetyPolicyVersion == PromptSafetyPolicy.version })
    }

    func testEveryEntryFailsClosedUntilCompleteEvidenceExists() {
        for descriptor in ModelCatalog.entries {
            XCTAssertFalse(
                descriptor.requirements.isEmpty
                    && descriptor.licenseApproved
                    && descriptor.evaluationApproved,
                "\(descriptor.familyName) must not become eligible without a complete file manifest"
            )
        }
    }

    func testTurboProfilesUseBoundedSquareOutput() throws {
        for id in [ModelID.zImageTurbo, .ernieImageTurbo] {
            let descriptor = try XCTUnwrap(ModelCatalog.descriptor(for: id))
            XCTAssertEqual(descriptor.profile.width, 1024)
            XCTAssertEqual(descriptor.profile.height, 1024)
            XCTAssertTrue((1...12).contains(descriptor.profile.steps))
            XCTAssertEqual(descriptor.profile.cfgScale, 1)
        }
    }
}
