import Foundation
import XCTest
@testable import MirageApp

final class ModelAssetSecurityTests: XCTestCase {
    func testCatalogFailsClosedWithoutReviewedHashes() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let resolver = try ModelFileResolver(
            rootURL: root,
            memoryProvider: FixedMemoryProvider(bytes: .max),
            protectedDataProvider: FixedProtectedDataProvider(available: true)
        )

        for descriptor in ModelCatalog.entries where !descriptor.requirements.isEmpty {
            let availability = await resolver.availability(for: descriptor)
            XCTAssertFalse(availability.isAvailable)
        }
    }

    func testGitIgnoreExcludesCommonModelWeightFormats() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let contents = try String(contentsOf: root.appendingPathComponent(".gitignore"), encoding: .utf8)
        for pattern in ["*.gguf", "*.safetensors", "Models/"] {
            XCTAssertTrue(contents.contains(pattern), "Missing model exclusion: \(pattern)")
        }
    }
}
