import Foundation
import XCTest
@testable import MirageApp

final class MirageInferenceServiceIntegrationTests: XCTestCase {
    func testRealPackageGenerationWhenApprovedModelsAreProvisioned() async throws {
        guard let directory = ProcessInfo.processInfo.environment["MIRAGE_TEST_MODELS_DIR"],
              !directory.isEmpty else {
            throw XCTSkip("Set MIRAGE_TEST_MODELS_DIR to an approved local model bundle")
        }
        let root = URL(fileURLWithPath: directory, isDirectory: true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.path))
        throw XCTSkip("Populate reviewed hashes in ModelCatalog before enabling real-model integration")
    }
}
