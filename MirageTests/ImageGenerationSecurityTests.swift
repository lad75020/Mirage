import Foundation
import XCTest
@testable import MirageApp

final class ImageGenerationSecurityTests: XCTestCase {
    func testFeatureSourceContainsNoPersistenceLoggingPasteboardOrRemoteTransport() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceRoot = projectRoot.appendingPathComponent("Mirage/Features/ImageGeneration", isDirectory: true)
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: sourceRoot, includingPropertiesForKeys: nil))
        let forbidden = ["UserDefaults", "UIPasteboard", "URLSession", "NWConnection", "print(", "Logger(", "os_log"]

        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let source = try String(contentsOf: url, encoding: .utf8)
            for symbol in forbidden {
                XCTAssertFalse(source.contains(symbol), "Forbidden boundary \(symbol) in \(url.lastPathComponent)")
            }
        }
    }

    func testPrivacyManifestDeclaresNoTrackingOrCollection() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let data = try Data(contentsOf: projectRoot.appendingPathComponent("Mirage/Resources/PrivacyInfo.xcprivacy"))
        let manifest = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
        XCTAssertEqual(manifest["NSPrivacyTracking"] as? Bool, false)
        XCTAssertTrue((manifest["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true)
        XCTAssertTrue((manifest["NSPrivacyTrackingDomains"] as? [Any])?.isEmpty == true)
    }

    func testPhotosPurposeTextIsAddOnlyAndNoReadPurposeIsDeclared() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let project = try String(contentsOf: projectRoot.appendingPathComponent("project.yml"), encoding: .utf8)
        XCTAssertTrue(project.contains("NSPhotoLibraryAddUsageDescription"))
        XCTAssertFalse(project.contains("NSPhotoLibraryUsageDescription"))
    }
}
