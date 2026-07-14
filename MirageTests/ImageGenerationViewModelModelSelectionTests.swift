import XCTest
@testable import MirageApp

@MainActor
final class ImageGenerationViewModelModelSelectionTests: XCTestCase {
    func testSelectsFirstAvailableModelAndSnapshotsExactChoice() async {
        let unavailable = ModelDescriptor.testFixture(id: .stableDiffusion)
        let available = ModelDescriptor.testFixture(id: .ernieImageTurbo)
        let resolver = StubAvailabilityProvider(
            availabilityByID: [
                unavailable.id: .configurationIncomplete,
                available.id: .available
            ]
        )
        let generator = StubGenerator()
        let viewModel = ImageGenerationViewModel(
            catalog: [unavailable, available],
            availabilityProvider: resolver,
            generator: generator,
            safetyService: PassingSafetyService(),
            photoSaver: StubPhotoSaver()
        )

        await viewModel.refreshAvailability()
        XCTAssertEqual(viewModel.selectedModelID, available.id)

        viewModel.prompt = "A paper sculpture"
        await viewModel.generate()
        let firstRequest = await generator.requests.first
        XCTAssertEqual(firstRequest?.modelID, available.id)
    }

    func testUnavailableModelCannotBeSelected() async {
        let available = ModelDescriptor.testFixture(id: .ernieImageTurbo)
        let unavailable = ModelDescriptor.testFixture(id: .zImageTurbo)
        let resolver = StubAvailabilityProvider(
            availabilityByID: [available.id: .available, unavailable.id: .licenseNotApproved]
        )
        let viewModel = ImageGenerationViewModel(
            catalog: [available, unavailable],
            availabilityProvider: resolver,
            generator: StubGenerator(),
            safetyService: PassingSafetyService(),
            photoSaver: StubPhotoSaver()
        )
        await viewModel.refreshAvailability()

        viewModel.selectModel(unavailable.id)

        XCTAssertEqual(viewModel.selectedModelID, available.id)
        XCTAssertFalse(viewModel.availability(for: unavailable.id).isAvailable)
    }
}
