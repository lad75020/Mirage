import Foundation
import XCTest
@testable import MirageApp

private enum DriverEvent: Equatable {
    case load(ModelID)
    case generate(UUID)
    case unload
}

private actor RecordingEngineDriver: MirageEngineDriving {
    private(set) var events: [DriverEvent] = []
    var loadDelay: Duration = .zero
    var generationDelay: Duration = .zero
    var loadFailure: Error?
    var generationFailure: Error?
    var output = onePixelPNG

    func load(modelID: ModelID, files: ResolvedModelFiles) async throws {
        if loadDelay != .zero {
            try? await Task.sleep(for: loadDelay)
        }
        events.append(.load(modelID))
        if let loadFailure { throw loadFailure }
    }

    func unload() async {
        events.append(.unload)
    }

    func generate(
        request: GenerationRequestSnapshot,
        progress: @escaping @Sendable (GenerationProgress) -> Void
    ) async throws -> Data {
        events.append(.generate(request.id))
        progress(.init(requestID: request.id, completedStep: 1, totalSteps: request.profile.steps, elapsed: 0.1))
        if generationDelay != .zero {
            try? await Task.sleep(for: generationDelay)
        }
        if let generationFailure { throw generationFailure }
        return output
    }

    func snapshot() -> [DriverEvent] { events }
}

final class MirageInferenceServiceTests: XCTestCase {
    func testSelectionOrListingDoesNotLoadBeforeSend() async throws {
        let resolver = StubAvailabilityProvider(availabilityByID: [.ernieImageTurbo: .available])
        let driver = RecordingEngineDriver()
        _ = MirageInferenceService(resolver: resolver, driver: driver)

        let events = await driver.snapshot()
        XCTAssertTrue(events.isEmpty)
    }

    func testLoadsAndUnloadsOncePerSendAndReloadsNextSend() async throws {
        let resolver = StubAvailabilityProvider(availabilityByID: [.ernieImageTurbo: .available])
        let driver = RecordingEngineDriver()
        let service = MirageInferenceService(resolver: resolver, driver: driver)
        let descriptor = ModelDescriptor.testFixture()

        let first = GenerationRequestSnapshot(prompt: "A calm lake", modelID: descriptor.id, profile: descriptor.profile)
        let second = GenerationRequestSnapshot(prompt: "A calm lake", modelID: descriptor.id, profile: descriptor.profile)
        _ = try await service.generate(request: first, descriptor: descriptor) { _ in }
        _ = try await service.generate(request: second, descriptor: descriptor) { _ in }

        let events = await driver.snapshot()
        XCTAssertEqual(events, [
            .load(descriptor.id), .generate(first.id), .unload,
            .load(descriptor.id), .generate(second.id), .unload
        ])
    }

    func testSerializesCompetingAttempts() async throws {
        let resolver = StubAvailabilityProvider(availabilityByID: [.ernieImageTurbo: .available])
        let driver = RecordingEngineDriver()
        await driver.setGenerationDelay(.milliseconds(80))
        let service = MirageInferenceService(resolver: resolver, driver: driver)
        let descriptor = ModelDescriptor.testFixture()
        let first = GenerationRequestSnapshot(prompt: "First", modelID: descriptor.id, profile: descriptor.profile)
        let second = GenerationRequestSnapshot(prompt: "Second", modelID: descriptor.id, profile: descriptor.profile)

        async let firstResult = service.generate(request: first, descriptor: descriptor) { _ in }
        async let secondResult = service.generate(request: second, descriptor: descriptor) { _ in }
        _ = try await (firstResult, secondResult)

        let events = await driver.snapshot()
        XCTAssertEqual(events, [
            .load(descriptor.id), .generate(first.id), .unload,
            .load(descriptor.id), .generate(second.id), .unload
        ])
    }

    func testUnloadRunsAfterNativeFailureAndInvalidPNG() async throws {
        let resolver = StubAvailabilityProvider(availabilityByID: [.ernieImageTurbo: .available])
        let driver = RecordingEngineDriver()
        let service = MirageInferenceService(resolver: resolver, driver: driver)
        let descriptor = ModelDescriptor.testFixture()
        let request = GenerationRequestSnapshot(prompt: "A calm lake", modelID: descriptor.id, profile: descriptor.profile)

        await driver.setGenerationFailure(ImageGenerationFailure.generationFailed)
        do {
            _ = try await service.generate(request: request, descriptor: descriptor) { _ in }
            XCTFail("Expected generation failure")
        } catch ImageGenerationFailure.generationFailed {}

        await driver.setGenerationFailure(nil)
        await driver.setOutput(Data("not png".utf8))
        do {
            _ = try await service.generate(request: request, descriptor: descriptor) { _ in }
            XCTFail("Expected invalid image")
        } catch ImageGenerationFailure.invalidImage {}

        let events = await driver.snapshot()
        XCTAssertEqual(events.filter { $0 == .unload }.count, 2)
        XCTAssertEqual(events.last, .unload)
    }

    func testUnloadRunsAfterLoadFailureAndCancellationLateResult() async throws {
        let resolver = StubAvailabilityProvider(availabilityByID: [.ernieImageTurbo: .available])
        let driver = RecordingEngineDriver()
        let service = MirageInferenceService(resolver: resolver, driver: driver)
        let descriptor = ModelDescriptor.testFixture()
        let request = GenerationRequestSnapshot(prompt: "A calm lake", modelID: descriptor.id, profile: descriptor.profile)

        await driver.setLoadFailure(ImageGenerationFailure.modelLoadFailed)
        do {
            _ = try await service.generate(request: request, descriptor: descriptor) { _ in }
            XCTFail("Expected load failure")
        } catch ImageGenerationFailure.modelLoadFailed {}

        await driver.setLoadFailure(nil)
        await driver.setGenerationDelay(.milliseconds(80))
        let task = Task {
            try await service.generate(request: request, descriptor: descriptor) { _ in }
        }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch ImageGenerationFailure.cancelled {}

        let events = await driver.snapshot()
        XCTAssertEqual(events.filter { $0 == .unload }.count, 2)
        XCTAssertEqual(events.last, .unload)
    }
}

private extension RecordingEngineDriver {
    func setGenerationDelay(_ value: Duration) {
        generationDelay = value
    }

    func setGenerationFailure(_ value: Error?) {
        generationFailure = value
    }

    func setLoadFailure(_ value: Error?) {
        loadFailure = value
    }

    func setOutput(_ value: Data) {
        output = value
    }
}
