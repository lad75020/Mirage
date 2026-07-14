import XCTest
@testable import MirageApp

final class AppMetadataTests: XCTestCase {
    func testScaffoldMetadataIdentifiesMirage() {
        XCTAssertEqual(AppMetadata.name, "Mirage")
        XCTAssertFalse(AppMetadata.tagline.isEmpty)
        XCTAssertEqual(AppMetadata.status, "iOS scaffold ready")
    }
}
