import Foundation

/// `MirageEngineDriving` implementation backed by the on-device LiteRT
/// (.tflite) Z-Image pipeline instead of the native GGUF engine.
///
/// Load is deferred: graphs stream in one at a time during generate so peak
/// memory stays near the largest single graph, and everything unloads when
/// the attempt completes (matching the app's load -> generate -> unload
/// lifecycle contract).
///
/// The LiteRT runtime ships iOS-only binaries, so this driver is compiled
/// only for iOS. macOS routes everything through the native GGUF engine.
#if os(iOS)
public actor LiteRTEngineDriver: MirageEngineDriving {
    private var pipeline: ZImageLiteRTPipeline?
    private let seedProvider: @Sendable () -> UInt64

    public init() {
        seedProvider = { UInt64.random(in: 1...999_999) }
    }

    init(seedProvider: @escaping @Sendable () -> UInt64) {
        self.seedProvider = seedProvider
    }

    public func load(modelID: ModelID, files: ResolvedModelFiles) async throws {
        pipeline = ZImageLiteRTPipeline(
            folderURL: files.folderURL,
            threads: Int32(max(2, min(6, ProcessInfo.processInfo.activeProcessorCount)))
        )
    }

    public func unload() async {
        await pipeline?.unload()
        pipeline = nil
    }

    public func generate(
        request: GenerationRequestSnapshot,
        progress: @escaping @Sendable (GenerationProgress) -> Void
    ) async throws -> Data {
        guard let pipeline else { throw ImageGenerationFailure.modelLoadFailed }
        let started = Date()
        let requestID = request.id
        return try await pipeline.generate(
            ZImageLiteRTPipeline.Request(
                prompt: request.prompt,
                negativePrompt: request.profile.negativePrompt,
                steps: request.profile.steps,
                guidance: request.profile.cfgScale > 1 ? request.profile.cfgScale - 1 : 0,
                seed: seedProvider()
            ),
            progress: { completed, total in
                progress(
                    GenerationProgress(
                        requestID: requestID,
                        completedStep: completed,
                        totalSteps: total,
                        elapsed: Date().timeIntervalSince(started)
                    )
                )
            }
        )
    }
}
#endif

/// Routes generation to the LiteRT driver for `.tflite` pipelines and to the
/// native GGUF engine for everything else, chosen per descriptor.
///
/// LiteRT is iOS-only; on other platforms everything routes to the native
/// engine and `.tflite` pipelines are unsupported.
public actor RoutingEngineDriver: MirageEngineDriving {
    private let nativeDriver: any MirageEngineDriving
    #if os(iOS)
    private let liteRTDriver: any MirageEngineDriving
    #endif
    private var activeDriver: (any MirageEngineDriving)?

    #if os(iOS)
    public init(
        nativeDriver: any MirageEngineDriving = NativeMirageEngineDriver(),
        liteRTDriver: any MirageEngineDriving = LiteRTEngineDriver()
    ) {
        self.nativeDriver = nativeDriver
        self.liteRTDriver = liteRTDriver
    }
    #else
    public init(nativeDriver: any MirageEngineDriving = NativeMirageEngineDriver()) {
        self.nativeDriver = nativeDriver
    }
    #endif

    public func load(modelID: ModelID, files: ResolvedModelFiles) async throws {
        #if os(iOS)
        let driver: any MirageEngineDriving =
            files.diffusionModel.pathExtension.lowercased() == "tflite"
                ? liteRTDriver
                : nativeDriver
        #else
        let driver: any MirageEngineDriving = nativeDriver
        #endif
        activeDriver = driver
        try await driver.load(modelID: modelID, files: files)
    }

    public func unload() async {
        await activeDriver?.unload()
        activeDriver = nil
    }

    public func generate(
        request: GenerationRequestSnapshot,
        progress: @escaping @Sendable (GenerationProgress) -> Void
    ) async throws -> Data {
        guard let activeDriver else { throw ImageGenerationFailure.modelLoadFailed }
        return try await activeDriver.generate(request: request, progress: progress)
    }
}
