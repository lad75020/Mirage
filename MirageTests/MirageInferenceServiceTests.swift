import Foundation
import XCTest
@testable import MirageApp

private actor RecordingEngineDriver: MirageEngineDriving {
    private(set) var loadedModels: [ModelID] = []
    private(set) var generatedRequests: [GenerationRequestSnapshot] = []

    func load(modelID: ModelID, files: ResolvedModelFiles) async throws {
        loadedModels.append(modelID)
    }

    func unload() async {}

    func generate(
        request: GenerationRequestSnapshot,
        progress: @escaping @Sendable (GenerationProgress) -> Void
    ) async throws -> Data {
        generatedRequests.append(request)
        progress(.init(requestID: request.id, completedStep: 1, totalSteps: request.profile.steps, elapsed: 0.1))
        return onePixelPNG
    }

    func loadCount() -> Int { loadedModels.count }
    func generationCount() -> Int { generatedRequests.count }
}

final class MirageInferenceServiceTests: XCTestCase {
    func testReusesEngineForSameModelAndReloadsForSwitch() async throws {
        let files = ResolvedModelFiles(diffusionModel: URL(fileURLWithPath: "/tmp/model.gguf"))
        let resolver = StubAvailabilityProvider(
            availabilityByID: [.ernieImageTurbo: .available, .zImageTurbo: .available],
            resolvedFiles: files
        )
        let driver = RecordingEngineDriver()
        let service = MirageInferenceService(resolver: resolver, driver: driver)
        let ernie = ModelDescriptor.testFixture(id: .ernieImageTurbo)
        let zImage = ModelDescriptor.testFixture(id: .zImageTurbo)

        for descriptor in [ernie, ernie, zImage] {
            let request = GenerationRequestSnapshot(
                prompt: "A calm lake",
                modelID: descriptor.id,
                profile: descriptor.profile
            )
            _ = try await service.generate(request: request, descriptor: descriptor) { _ in }
        }

        let loadCount = await driver.loadCount()
        let generationCount = await driver.generationCount()
        XCTAssertEqual(loadCount, 2)
        XCTAssertEqual(generationCount, 3)
    }

    func testReportsRequestScopedProgressAndPNGDimensions() async throws {
        let resolver = StubAvailabilityProvider(
            availabilityByID: [.ernieImageTurbo: .available]
        )
        let driver = RecordingEngineDriver()
        let service = MirageInferenceService(resolver: resolver, driver: driver)
        let descriptor = ModelDescriptor.testFixture()
        let request = GenerationRequestSnapshot(
            prompt: "A calm lake",
            modelID: descriptor.id,
            profile: descriptor.profile
        )
        let progressRecorder = ProgressRecorder()

        let image = try await service.generate(request: request, descriptor: descriptor) { value in
            Task { await progressRecorder.append(value) }
        }

        XCTAssertEqual(image.requestID, request.id)
        XCTAssertEqual(image.modelID, descriptor.id)
        XCTAssertEqual(image.width, 1)
        XCTAssertEqual(image.height, 1)
        await Task.yield()
        let firstProgress = await progressRecorder.first()
        XCTAssertEqual(firstProgress?.requestID, request.id)
    }
}

private actor ProgressRecorder {
    private var values: [GenerationProgress] = []
    func append(_ value: GenerationProgress) { values.append(value) }
    func first() -> GenerationProgress? { values.first }
}
