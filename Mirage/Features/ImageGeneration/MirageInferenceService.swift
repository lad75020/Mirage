import Foundation
import ImageIO
import Mirage

public protocol MirageEngineDriving: Sendable {
    func load(modelID: ModelID, files: ResolvedModelFiles) async throws
    func unload() async
    func generate(
        request: GenerationRequestSnapshot,
        progress: @escaping @Sendable (GenerationProgress) -> Void
    ) async throws -> Data
}

public actor NativeMirageEngineDriver: MirageEngineDriving {
    private var engine: Engine?
    private let seedProvider: @Sendable () -> Int64

    public init() {
        seedProvider = {
            Int64.random(in: 1...999_999)
        }
    }

    init(seedProvider: @escaping @Sendable () -> Int64) {
        self.seedProvider = seedProvider
    }

    public func load(modelID: ModelID, files: ResolvedModelFiles) async throws {
        engine = try Engine(
            models: ModelFiles(
                diffusionModel: files.diffusionModel,
                vae: files.vae,
                textEncoder: files.textEncoder
            )
        )
    }

    public func unload() async {
        Mirage.setProgressCallback(nil)
        engine = nil
    }

    public func generate(
        request: GenerationRequestSnapshot,
        progress: @escaping @Sendable (GenerationProgress) -> Void
    ) async throws -> Data {
        guard let engine else { throw ImageGenerationFailure.modelLoadFailed }
        Mirage.setProgressCallback { step, total, elapsed in
            progress(
                GenerationProgress(
                    requestID: request.id,
                    completedStep: step,
                    totalSteps: total,
                    elapsed: elapsed
                )
            )
        }
        defer { Mirage.setProgressCallback(nil) }

        let image = try await engine.generate(makeNativeRequest(for: request))
        guard let pngData = image.pngData() else {
            throw ImageGenerationFailure.invalidImage
        }
        return pngData
    }

    func makeNativeRequest(for request: GenerationRequestSnapshot) -> GenerationRequest {
        GenerationRequest(
            prompt: request.prompt,
            negativePrompt: request.profile.negativePrompt,
            width: request.profile.width,
            height: request.profile.height,
            steps: request.profile.steps,
            cfgScale: request.profile.cfgScale,
            seed: seedProvider()
        )
    }
}

public actor MirageInferenceService: ImageGenerating {
    private let resolver: any ModelAvailabilityProviding
    private let driver: any MirageEngineDriving
    private var attemptInProgress = false
    private var attemptWaiters: [CheckedContinuation<Void, Never>] = []

    public init(
        resolver: any ModelAvailabilityProviding,
        driver: any MirageEngineDriving = NativeMirageEngineDriver()
    ) {
        self.resolver = resolver
        self.driver = driver
    }

    public func generate(
        request: GenerationRequestSnapshot,
        descriptor: ModelDescriptor,
        progress: @escaping @Sendable (GenerationProgress) -> Void
    ) async throws -> GeneratedImage {
        await acquireAttempt()
        defer { releaseAttempt() }

        let outcome: Result<GeneratedImage, ImageGenerationFailure>
        do {
            guard request.modelID == descriptor.id else {
                throw ImageGenerationFailure.modelUnavailable
            }
            try Task.checkCancellation()

            let files: ResolvedModelFiles
            do {
                files = try await resolver.resolve(descriptor)
            } catch {
                throw ImageGenerationFailure.modelUnavailable
            }

            do {
                try await driver.load(modelID: descriptor.id, files: files)
            } catch {
                throw ImageGenerationFailure.modelLoadFailed
            }

            let pngData: Data
            do {
                pngData = try await driver.generate(request: request, progress: progress)
            } catch let failure as ImageGenerationFailure {
                throw failure
            } catch {
                throw ImageGenerationFailure.generationFailed
            }
            try Task.checkCancellation()

            guard let source = CGImageSourceCreateWithData(pngData as CFData, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Int,
                  let height = properties[kCGImagePropertyPixelHeight] as? Int else {
                throw ImageGenerationFailure.invalidImage
            }
            outcome = .success(GeneratedImage(
                requestID: request.id,
                modelID: descriptor.id,
                pngData: pngData,
                width: width,
                height: height
            ))
        } catch is CancellationError {
            outcome = .failure(.cancelled)
        } catch let failure as ImageGenerationFailure {
            outcome = .failure(failure)
        } catch {
            outcome = .failure(.generationFailed)
        }

        // Awaited teardown is the barrier that prevents this attempt from
        // returning while the callback, Engine, or model memory remains live.
        await driver.unload()
        return try outcome.get()
    }

    private func acquireAttempt() async {
        guard attemptInProgress else {
            attemptInProgress = true
            return
        }
        await withCheckedContinuation { continuation in
            attemptWaiters.append(continuation)
        }
    }

    private func releaseAttempt() {
        guard !attemptWaiters.isEmpty else {
            attemptInProgress = false
            return
        }
        attemptWaiters.removeFirst().resume()
    }
}
