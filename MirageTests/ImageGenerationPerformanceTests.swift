import Foundation
import Mirage
import XCTest
@testable import MirageApp

final class ImageGenerationPerformanceTests: XCTestCase {
    func testNativeEngineReleasesComponentWeightsBetweenGenerationPhases() {
        XCTAssertTrue(Mirage.releasesComponentWeightsAfterUse)
    }

    func testNativeEngineAdvertisesChromaSafeContextConfiguration() {
        XCTAssertTrue(Mirage.chromaUsesSafeDitMaskConfiguration)
    }

    func testCatalogAndPromptPolicyStayLightweight() {
        measure {
            for _ in 0..<1_000 {
                _ = ModelCatalog.descriptor(for: .ernieImageTurbo)
                _ = try? PromptSafetyPolicy.current.validatedPrompt("A studio portrait made of folded paper")
            }
        }
    }

    func testSecondAttemptStartsOnlyAfterAwaitedUnloadBoundary() async throws {
        let resolver = StubAvailabilityProvider(availabilityByID: [.ernieImageTurbo: .available])
        let driver = BoundaryEngineDriver()
        await driver.setGenerationDelay(.milliseconds(20))
        await driver.setUnloadDelay(.milliseconds(60))
        let service = MirageInferenceService(resolver: resolver, driver: driver)
        let descriptor = ModelDescriptor.testFixture()
        let first = GenerationRequestSnapshot(prompt: "First", modelID: descriptor.id, profile: descriptor.profile)
        let second = GenerationRequestSnapshot(prompt: "Second", modelID: descriptor.id, profile: descriptor.profile)

        async let firstResult = service.generate(request: first, descriptor: descriptor) { _ in }
        async let secondResult = service.generate(request: second, descriptor: descriptor) { _ in }
        _ = try await (firstResult, secondResult)

        let events = await driver.snapshot()
        XCTAssertEqual(events.count, 8)
        var completedRequestIDs = Set<String>()
        for offset in [0, 4] {
            XCTAssertTrue(events[offset].hasPrefix("load-"))
            XCTAssertTrue(events[offset + 1].hasPrefix("generate-"))
            let loadID = String(events[offset].dropFirst("load-".count))
            let generateID = String(events[offset + 1].dropFirst("generate-".count))
            XCTAssertEqual(loadID, generateID)
            completedRequestIDs.insert(loadID)
            XCTAssertEqual(events[offset + 2], "unload-start")
            XCTAssertEqual(events[offset + 3], "unload-end")
        }
        XCTAssertEqual(completedRequestIDs, Set([first.id.uuidString, second.id.uuidString]))
        let maximumLoadedEngines = await driver.maximumLoadedEngines
        let isLoaded = await driver.isLoaded
        XCTAssertEqual(maximumLoadedEngines, 1)
        XCTAssertFalse(isLoaded)
    }
}

private actor BoundaryEngineDriver: MirageEngineDriving {
    private(set) var events: [String] = []
    private(set) var maximumLoadedEngines = 0
    private(set) var isLoaded = false
    private var currentRequestID: UUID?
    private var generationDelay: Duration = .zero
    private var unloadDelay: Duration = .zero

    func setGenerationDelay(_ value: Duration) {
        generationDelay = value
    }

    func setUnloadDelay(_ value: Duration) {
        unloadDelay = value
    }

    func load(modelID: ModelID, files: ResolvedModelFiles) async throws {
        guard !isLoaded else { throw ImageGenerationFailure.modelLoadFailed }
        isLoaded = true
        maximumLoadedEngines = max(maximumLoadedEngines, 1)
        events.append("load-\(currentRequestID?.uuidString ?? "unknown")")
    }

    func unload() async {
        events.append("unload-start")
        if unloadDelay != .zero {
            try? await Task.sleep(for: unloadDelay)
        }
        isLoaded = false
        currentRequestID = nil
        events.append("unload-end")
    }

    func generate(
        request: GenerationRequestSnapshot,
        progress: @escaping @Sendable (GenerationProgress) -> Void
    ) async throws -> Data {
        currentRequestID = request.id
        if let lastIndex = events.indices.last, events[lastIndex] == "load-unknown" {
            events[lastIndex] = "load-\(request.id)"
        }
        events.append("generate-\(request.id)")
        progress(.init(requestID: request.id, completedStep: 1, totalSteps: request.profile.steps, elapsed: 0.1))
        if generationDelay != .zero {
            try? await Task.sleep(for: generationDelay)
        }
        return onePixelPNG
    }

    func snapshot() -> [String] { events }
}
