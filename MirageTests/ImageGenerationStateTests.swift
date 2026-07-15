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

    func testDownloadValidationLoadingTeardownCancellationAndTamperingStates() throws {
        let reference = try ModelRepositoryReference("jc-builds/Z-Image-Turbo-iOS")
        let progress = ModelDownloadProgress(completedBytes: 25, totalBytes: 100)

        XCTAssertTrue(ImageGenerationState.resolvingDownload(reference).isBusy)
        XCTAssertTrue(ImageGenerationState.downloadingModel(reference, progress).isBusy)
        XCTAssertEqual(ImageGenerationState.downloadingModel(reference, progress).statusText, "Downloading 25%…")
        XCTAssertTrue(ImageGenerationState.validatingDownload(reference).isBusy)
        XCTAssertFalse(ImageGenerationState.modelLoaded(reference).isBusy)
        XCTAssertFalse(ImageGenerationState.modelUnloaded(reference).isBusy)
        XCTAssertFalse(ImageGenerationState.downloadCancelled(reference).isBusy)
        XCTAssertFalse(ImageGenerationState.filesTampered(reference).isBusy)
    }
}
