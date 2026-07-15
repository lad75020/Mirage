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

    func testMaliciousReferencesRedirectsPartialActivationAndGenerationDataExclusion() throws {
        XCTAssertThrowsError(try ModelRepositoryReference("https://evil.example/owner/model"))
        XCTAssertThrowsError(try ModelRepositoryReference("https://user:secret@huggingface.co/owner/model"))
        XCTAssertFalse(HuggingFaceModelDownloader.validateRedirect(
            from: URL(string: "https://huggingface.co/owner/model")!,
            to: URL(string: "http://huggingface.co/owner/model")!
        ))
        XCTAssertFalse(HuggingFaceModelDownloader.validateRedirect(
            from: URL(string: "https://huggingface.co/owner/model")!,
            to: URL(string: "https://example.com/owner/model")!
        ))

        let mirror = Mirror(reflecting: ModelDownloadFile(
            path: "model.gguf",
            sizeBytes: 1,
            sha256: nil,
            downloadURL: URL(string: "https://huggingface.co/owner/model/resolve/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/model.gguf")!
        ))
        let labels = Set(mirror.children.compactMap(\.label))
        XCTAssertFalse(labels.contains("prompt"))
        XCTAssertFalse(labels.contains("pngData"))
        XCTAssertFalse(labels.contains("credential"))
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
