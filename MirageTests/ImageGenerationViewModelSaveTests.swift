import Foundation
import XCTest
@testable import MirageApp

@MainActor
final class ImageGenerationViewModelSaveTests: XCTestCase {
    func testSaveIsHiddenBeforeResultAndReadyAfterResult() async {
        let descriptor = ModelDescriptor.testFixture()
        let resolver = StubAvailabilityProvider(availabilityByID: [descriptor.id: .available])
        let photoSaver = StubPhotoSaver()
        let viewModel = ImageGenerationViewModel(
            catalog: [descriptor],
            availabilityProvider: resolver,
            generator: StubGenerator(),
            safetyService: PassingSafetyService(),
            photoSaver: photoSaver
        )
        XCTAssertEqual(viewModel.saveState, .hidden)

        await viewModel.refreshAvailability()
        await viewModel.selectModel(descriptor.id)
        viewModel.prompt = "A blue glass bird"
        await viewModel.generate()
        XCTAssertEqual(viewModel.saveState, .ready)

        await viewModel.saveCurrentImage()
        XCTAssertEqual(viewModel.saveState, .saved)
        let saveCount = await photoSaver.saveCount()
        XCTAssertEqual(saveCount, 1)
    }

    func testSaveFailureKeepsGeneratedImage() async {
        let descriptor = ModelDescriptor.testFixture()
        let resolver = StubAvailabilityProvider(availabilityByID: [descriptor.id: .available])
        let photoSaver = ThrowingPhotoSaver()
        let viewModel = ImageGenerationViewModel(
            catalog: [descriptor],
            availabilityProvider: resolver,
            generator: StubGenerator(),
            safetyService: PassingSafetyService(),
            photoSaver: photoSaver
        )
        await viewModel.refreshAvailability()
        await viewModel.selectModel(descriptor.id)
        viewModel.prompt = "A blue glass bird"
        await viewModel.generate()
        let image = viewModel.state.currentImage

        await viewModel.saveCurrentImage()

        XCTAssertEqual(viewModel.saveState, .failed)
        XCTAssertEqual(viewModel.state.currentImage, image)
    }
}

private struct ThrowingPhotoSaver: PhotoLibrarySaving {
    func authorizationStatus() async -> PhotoAuthorizationState { .authorized }
    func savePNG(_ data: Data) async throws -> PhotoSaveResult {
        throw PhotoLibrarySaveError.writeFailed
    }
}
