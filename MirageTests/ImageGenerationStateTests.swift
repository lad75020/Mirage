import Foundation
import XCTest
@testable import MirageApp

final class ImageGenerationStateTests: XCTestCase {
    func testBusyStatesRetainPreviousResult() {
        let image = GeneratedImage(
            requestID: UUID(),
            modelID: .ernieImageTurbo,
            pngData: onePixelPNG,
            width: 1,
            height: 1
        )
        let requestID = UUID()

        let loading = ImageGenerationState.loadingModel(requestID: requestID, previousResult: image)
        let generating = ImageGenerationState.generating(
            requestID: requestID,
            progress: .init(requestID: requestID, completedStep: 2, totalSteps: 8, elapsed: 1),
            previousResult: image
        )
        let reviewing = ImageGenerationState.reviewingSafety(requestID: requestID, previousResult: image)

        XCTAssertTrue(loading.isBusy)
        XCTAssertEqual(loading.currentImage, image)
        XCTAssertEqual(generating.currentImage, image)
        XCTAssertEqual(generating.progress?.fractionCompleted, 0.25)
        XCTAssertEqual(reviewing.currentImage, image)
    }

    func testFailureAndRefusalRetainPreviousResult() {
        let image = GeneratedImage(
            requestID: UUID(),
            modelID: .ernieImageTurbo,
            pngData: onePixelPNG,
            width: 1,
            height: 1
        )

        XCTAssertEqual(
            ImageGenerationState.failed(.generationFailed, previousResult: image).currentImage,
            image
        )
        XCTAssertEqual(
            ImageGenerationState.refused("Try another description.", previousResult: image).currentImage,
            image
        )
    }

    func testReadyAndSuccessAreNotBusy() {
        let image = GeneratedImage(
            requestID: UUID(),
            modelID: .ernieImageTurbo,
            pngData: onePixelPNG,
            width: 1,
            height: 1
        )

        XCTAssertFalse(ImageGenerationState.ready.isBusy)
        XCTAssertFalse(ImageGenerationState.success(image).isBusy)
        XCTAssertEqual(ImageGenerationState.success(image).currentImage, image)
    }
}
