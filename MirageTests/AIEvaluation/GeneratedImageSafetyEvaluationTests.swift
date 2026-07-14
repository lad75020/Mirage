import Foundation
import XCTest
@testable import MirageApp

final class GeneratedImageSafetyEvaluationTests: XCTestCase {
    func testMalformedAndOversizedOutputFailClosed() async {
        let service = ImageSafetyService(analyzer: StubOutputAnalyzer())
        let malformed = GeneratedImage(
            requestID: UUID(),
            modelID: .ernieImageTurbo,
            pngData: Data("not an image".utf8),
            width: 1,
            height: 1
        )
        await XCTAssertThrowsErrorAsync { try await service.validateOutput(malformed) }
    }

    func testAnalyzerFailureFailsClosed() async {
        let service = ImageSafetyService(analyzer: StubOutputAnalyzer(shouldThrow: true))
        let image = GeneratedImage(
            requestID: UUID(),
            modelID: .ernieImageTurbo,
            pngData: onePixelPNG,
            width: 1,
            height: 1
        )
        await XCTAssertThrowsErrorAsync { try await service.validateOutput(image) }
    }
}

private struct StubOutputAnalyzer: ImageSensitivityAnalyzing {
    let shouldThrow: Bool

    init(shouldThrow: Bool = false) {
        self.shouldThrow = shouldThrow
    }

    func isSensitive(pngData: Data) async throws -> Bool {
        if shouldThrow { throw ImageSafetyError.analysisUnavailable }
        return false
    }
}
