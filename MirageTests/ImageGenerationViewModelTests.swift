import XCTest
@testable import MirageApp

@MainActor
final class ImageGenerationViewModelTests: XCTestCase {
    func testValidPromptGeneratesOneImageAndRetainsPrompt() async {
        let descriptor = ModelDescriptor.testFixture()
        let resolver = StubAvailabilityProvider(availabilityByID: [descriptor.id: .available])
        let generator = StubGenerator()
        let viewModel = ImageGenerationViewModel(
            catalog: [descriptor],
            availabilityProvider: resolver,
            generator: generator,
            safetyService: PassingSafetyService(),
            photoSaver: StubPhotoSaver()
        )
        await viewModel.refreshAvailability()
        await viewModel.selectModel(descriptor.id)
        viewModel.prompt = "A quiet lake beneath the northern lights"

        await viewModel.generate()

        let requestCount = await generator.requestCount()
        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(viewModel.prompt, "A quiet lake beneath the northern lights")
        guard case .success(let image) = viewModel.state else {
            return XCTFail("Expected success")
        }
        XCTAssertEqual(image.modelID, descriptor.id)
        XCTAssertEqual(viewModel.saveState, .ready)
    }

    func testGeneratedImageDisplaysWithoutOutputSafetyReview() async {
        let descriptor = ModelDescriptor.testFixture()
        let resolver = StubAvailabilityProvider(availabilityByID: [descriptor.id: .available])
        let generator = StubGenerator()
        let viewModel = ImageGenerationViewModel(
            catalog: [descriptor],
            availabilityProvider: resolver,
            generator: generator,
            safetyService: OutputReviewFailingSafetyService(),
            photoSaver: StubPhotoSaver()
        )
        await viewModel.refreshAvailability()
        await viewModel.selectModel(descriptor.id)
        viewModel.prompt = "An unrestricted generated image"

        await viewModel.generate()

        guard case .success(let image) = viewModel.state else {
            return XCTFail("Expected generated image to display without output review")
        }
        XCTAssertEqual(image.pngData, onePixelPNG)
        XCTAssertEqual(viewModel.saveState, .ready)
    }

    func testBlankPromptDoesNotStartGeneration() async {
        let descriptor = ModelDescriptor.testFixture()
        let resolver = StubAvailabilityProvider(availabilityByID: [descriptor.id: .available])
        let generator = StubGenerator()
        let viewModel = ImageGenerationViewModel(
            catalog: [descriptor],
            availabilityProvider: resolver,
            generator: generator,
            safetyService: PassingSafetyService(),
            photoSaver: StubPhotoSaver()
        )
        await viewModel.refreshAvailability()
        await viewModel.selectModel(descriptor.id)
        viewModel.prompt = "   "

        await viewModel.generate()

        let requestCount = await generator.requestCount()
        XCTAssertEqual(requestCount, 0)
        XCTAssertEqual(viewModel.validationMessage, "Enter a description first.")
    }

    func testPreviousImageSurvivesGenerationFailure() async {
        let descriptor = ModelDescriptor.testFixture()
        let resolver = StubAvailabilityProvider(availabilityByID: [descriptor.id: .available])
        let generator = StubGenerator()
        let viewModel = ImageGenerationViewModel(
            catalog: [descriptor],
            availabilityProvider: resolver,
            generator: generator,
            safetyService: PassingSafetyService(),
            photoSaver: StubPhotoSaver()
        )
        await viewModel.refreshAvailability()
        await viewModel.selectModel(descriptor.id)
        viewModel.prompt = "First image"
        await viewModel.generate()
        let first = viewModel.state.currentImage

        await generator.setFailure(.generationFailed)
        viewModel.prompt = "Second image"
        await viewModel.generate()

        XCTAssertEqual(viewModel.state.currentImage, first)
        guard case .failed(.generationFailed, _) = viewModel.state else {
            return XCTFail("Expected recoverable failure")
        }
    }

    func testNoAutomaticSelectionAndSendRequiresExplicitSelection() async {
        let descriptor = ModelDescriptor.testFixture()
        let resolver = StubAvailabilityProvider(availabilityByID: [descriptor.id: .available])
        let generator = StubGenerator()
        let viewModel = ImageGenerationViewModel(
            catalog: [descriptor],
            availabilityProvider: resolver,
            generator: generator,
            safetyService: PassingSafetyService(),
            photoSaver: StubPhotoSaver()
        )

        await viewModel.refreshAvailability()
        viewModel.prompt = "A paper sculpture"

        XCTAssertNil(viewModel.selectedModelID)
        XCTAssertFalse(viewModel.canSend)
        await viewModel.generate()
        let requestCount = await generator.requestCount()
        XCTAssertEqual(requestCount, 0)
    }

    func testLogicalSelectionSurvivesUnloadAndNextSendReloads() async {
        let descriptor = ModelDescriptor.testFixture()
        let resolver = StubAvailabilityProvider(availabilityByID: [descriptor.id: .available])
        let generator = StubGenerator()
        let viewModel = ImageGenerationViewModel(
            catalog: [descriptor],
            availabilityProvider: resolver,
            generator: generator,
            safetyService: PassingSafetyService(),
            photoSaver: StubPhotoSaver()
        )
        await viewModel.refreshAvailability()
        await viewModel.selectModel(descriptor.id)
        viewModel.prompt = "A paper sculpture"

        await viewModel.generate()
        await viewModel.generate()

        XCTAssertEqual(viewModel.selectedModelID, descriptor.id)
        let requestCount = await generator.requestCount()
        XCTAssertEqual(requestCount, 2)
    }
}

private struct OutputReviewFailingSafetyService: ImageSafetyChecking {
    func validatePrompt(_ prompt: String) async throws -> String { prompt }

    func validateOutput(_ image: GeneratedImage) async throws -> GeneratedImage {
        throw ImageSafetyError.analysisUnavailable
    }
}

private extension StubGenerator {
    func setFailure(_ value: ImageGenerationFailure?) {
        failure = value
    }
}
