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

    public init() {}

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
        engine = nil
        Mirage.setProgressCallback(nil)
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

        let image = try await engine.generate(
            .init(
                prompt: request.prompt,
                negativePrompt: request.profile.negativePrompt,
                width: request.profile.width,
                height: request.profile.height,
                steps: request.profile.steps,
                cfgScale: request.profile.cfgScale
            )
        )
        guard let pngData = image.pngData() else {
            throw ImageGenerationFailure.invalidImage
        }
        return pngData
    }
}

public actor MirageInferenceService: ImageGenerating {
    private let resolver: any ModelAvailabilityProviding
    private let driver: any MirageEngineDriving
    private var loadedModelID: ModelID?

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
        guard request.modelID == descriptor.id else {
            throw ImageGenerationFailure.modelUnavailable
        }
        if Task.isCancelled { throw ImageGenerationFailure.cancelled }

        let files: ResolvedModelFiles
        do {
            files = try await resolver.resolve(descriptor)
        } catch {
            throw ImageGenerationFailure.modelUnavailable
        }

        if loadedModelID != descriptor.id {
            await driver.unload()
            do {
                try await driver.load(modelID: descriptor.id, files: files)
                loadedModelID = descriptor.id
            } catch {
                loadedModelID = nil
                throw ImageGenerationFailure.modelLoadFailed
            }
        }

        let pngData: Data
        do {
            pngData = try await driver.generate(request: request, progress: progress)
        } catch let failure as ImageGenerationFailure {
            throw failure
        } catch {
            throw ImageGenerationFailure.generationFailed
        }
        if Task.isCancelled { throw ImageGenerationFailure.cancelled }
        guard let source = CGImageSourceCreateWithData(pngData as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            throw ImageGenerationFailure.invalidImage
        }
        return GeneratedImage(
            requestID: request.id,
            modelID: descriptor.id,
            pngData: pngData,
            width: width,
            height: height
        )
    }
}
