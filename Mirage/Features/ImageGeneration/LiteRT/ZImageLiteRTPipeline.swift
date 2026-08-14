#if os(iOS)
import Accelerate
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// On-device Z-Image-Turbo text-to-image pipeline over 13 LiteRT graphs.
///
/// Swift port of the verified reference host loop (diffusers ZImagePipeline):
/// tokenize -> embed_tokens -> qwen_enc (penultimate hidden) -> per-branch
/// caption embed/refine with host pad-token masking and per-branch RoPE ->
/// per step: patchify -> z_embx -> z_refx -> concat [x, cap] -> zc_main0..5
/// -> zc_final -> unpatchify -> flow-match Euler update -> VAE denorm+decode.
///
/// Graphs are loaded lazily one at a time; peak residency stays near the
/// largest single graph so the pipeline fits commodity-phone memory budgets.
actor ZImageLiteRTPipeline {
    enum PipelineError: Error, Equatable, Sendable {
        case missingComponent(String)
        case cancelled
        case imageEncodingFailed
    }

    // Architecture constants (Z-Image transformer config).
    private static let axesDims = [32, 48, 48]
    private static let ropeTheta = 256.0
    private static let tScale: Float = 1000.0
    private static let frequencyEmbedSize = 256
    private static let capTokens = 32
    private static let qwenTokens = 64
    private static let imageTokens = 256
    private static let hiddenDim = 3840
    private static let latentChannels = 16
    private static let latentSide = 32
    private static let patchSize = 2
    private static let vaeScaling: Float = 0.3611
    private static let vaeShift: Float = 0.1159
    private static let sigmaShift: Double = 3.0
    private static let outputSide = 256

    struct Request: Sendable {
        let prompt: String
        let negativePrompt: String?
        let steps: Int
        let guidance: Float
        let seed: UInt64
    }

    private let folderURL: URL
    private let threads: Int32
    private var graphs: [String: LiteRTGraph] = [:]
    private var hostTensors: SafetensorsFile?
    private var tokenizer: QwenTokenizer?

    init(folderURL: URL, threads: Int32 = 4) {
        self.folderURL = folderURL
        self.threads = threads
    }

    func unload() {
        graphs.removeAll()
        hostTensors = nil
        tokenizer = nil
    }

    func generate(
        _ request: Request,
        progress: @escaping @Sendable (Int, Int) -> Void
    ) throws -> Data {
        defer { unload() }
        let host = try loadHostAssets()
        let steps = max(1, request.steps)
        let useCFG = request.guidance > 0
        // Progress: 1 encode + steps + 1 decode.
        let totalUnits = steps + 2
        var completedUnits = 0

        // 1. Prompt encoding (qwen_enc is the largest graph; drop it right after).
        let positiveCaption = try encodePrompt(request.prompt, host: host)
        let negativeCaption = useCFG
            ? try encodePrompt(request.negativePrompt ?? "", host: host)
            : nil
        graphs.removeAll()
        completedUnits += 1
        progress(completedUnits, totalUnits)
        try Task.checkCancellation()

        // 2. Per-branch caption context + RoPE tables.
        let positiveBranch = try makeBranch(caption: positiveCaption, host: host)
        let negativeBranch = try negativeCaption.map { try makeBranch(caption: $0, host: host) }

        // 3. Flow-match Euler denoising.
        let sigmas = Self.shiftedSigmas(steps: steps)
        var latent = Self.gaussianLatent(seed: request.seed)
        for step in 0..<steps {
            try Task.checkCancellation()
            let timestepEmbedding = try Self.timestepEmbedding(
                t: Float(1.0 - sigmas[step]),
                host: host
            )
            let positive = try denoise(latent: latent, branch: positiveBranch, adaln: timestepEmbedding)
            var prediction = positive
            if let negativeBranch {
                let negative = try denoise(latent: latent, branch: negativeBranch, adaln: timestepEmbedding)
                for i in 0..<prediction.count {
                    prediction[i] = positive[i] + request.guidance * (positive[i] - negative[i])
                }
            }
            let dSigma = Float(sigmas[step + 1] - sigmas[step])
            for i in 0..<latent.count {
                latent[i] += dSigma * -prediction[i]
            }
            completedUnits += 1
            progress(completedUnits, totalUnits)
        }

        // 4. VAE decode (denormalize first).
        for i in 0..<latent.count {
            latent[i] = latent[i] / Self.vaeScaling + Self.vaeShift
        }
        let pixels = try graph("zvae.tflite").run([latent])
        graphs.removeAll()
        completedUnits += 1
        progress(completedUnits, totalUnits)
        return try Self.encodePNG(chwPixels: pixels, side: Self.outputSide)
    }

    // MARK: - Asset loading

    private struct HostAssets {
        let embedTokens: SafetensorsFile
        let tEmbedderW0: [Float]
        let tEmbedderB0: [Float]
        let tEmbedderW2: [Float]
        let tEmbedderB2: [Float]
        let capPadToken: [Float]
        let tokenizer: QwenTokenizer
    }

    private var cachedHostAssets: HostAssets?

    private func loadHostAssets() throws -> HostAssets {
        if let cachedHostAssets { return cachedHostAssets }
        let tensorsURL = folderURL.appendingPathComponent("host_tensors.safetensors")
        let tokenizerURL = folderURL.appendingPathComponent("tokenizer.json")
        guard FileManager.default.fileExists(atPath: tensorsURL.path) else {
            throw PipelineError.missingComponent("host_tensors.safetensors")
        }
        guard FileManager.default.fileExists(atPath: tokenizerURL.path) else {
            throw PipelineError.missingComponent("tokenizer.json")
        }
        let file = try SafetensorsFile(url: tensorsURL)
        let assets = HostAssets(
            embedTokens: file,
            tEmbedderW0: try file.floatTensor("t_embedder.mlp.0.weight"),
            tEmbedderB0: try file.floatTensor("t_embedder.mlp.0.bias"),
            tEmbedderW2: try file.floatTensor("t_embedder.mlp.2.weight"),
            tEmbedderB2: try file.floatTensor("t_embedder.mlp.2.bias"),
            capPadToken: try file.floatTensor("cap_pad_token"),
            tokenizer: try QwenTokenizer(tokenizerJSONURL: tokenizerURL)
        )
        cachedHostAssets = assets
        return assets
    }

    private func graph(_ name: String) throws -> LiteRTGraph {
        if let existing = graphs[name] { return existing }
        let url = folderURL.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PipelineError.missingComponent(name)
        }
        let loaded = try LiteRTGraph(url: url, threads: threads)
        graphs[name] = loaded
        return loaded
    }

    // MARK: - Text encoding

    /// Returns the valid caption features [validCount * 2560], max 32 tokens.
    private func encodePrompt(_ prompt: String, host: HostAssets) throws -> [Float] {
        let (ids, validCount) = host.tokenizer.encodeForZImage(prompt: prompt, length: Self.qwenTokens)
        let embedDim = try host.embedTokens.shape(of: "embed_tokens.weight")[1]
        var inputEmbeds = [Float]()
        inputEmbeds.reserveCapacity(Self.qwenTokens * embedDim)
        for id in ids {
            inputEmbeds.append(contentsOf: try host.embedTokens.floatRows("embed_tokens.weight", row: id))
        }
        let encoded = try graph("qwen_enc.tflite").run([inputEmbeds])
        let usable = min(validCount, Self.capTokens)
        return Array(encoded[0..<(usable * embedDim)])
    }

    // MARK: - Branch preparation

    private struct Branch {
        let capContext: [Float]      // [32 * 3840] refined caption context
        let unifiedCos: [Float]      // [288 * 64]
        let unifiedSin: [Float]      // [288 * 64]
        let imageCos: [Float]        // [256 * 64]
        let imageSin: [Float]        // [256 * 64]
    }

    private func makeBranch(caption: [Float], host: HostAssets) throws -> Branch {
        let embedDim = 2560
        let validCount = caption.count / embedDim
        // Pad caption to 32 tokens by repeating the last valid token.
        var captionInput = caption
        if validCount < Self.capTokens {
            let lastRow = Array(caption[((validCount - 1) * embedDim)..<(validCount * embedDim)])
            for _ in validCount..<Self.capTokens {
                captionInput.append(contentsOf: lastRow)
            }
        }
        // Per-branch RoPE. Caption: valid ids (1..L,0,0), pad ids (0,0,0).
        var captionPositions = [SIMD3<Int32>](repeating: .zero, count: Self.capTokens)
        for index in 0..<validCount {
            captionPositions[index] = SIMD3(Int32(index + 1), 0, 0)
        }
        let (captionCos, captionSin) = Self.rope(positions: captionPositions)
        // Image: (33, h, w) row-major over the 16x16 token grid.
        var imagePositions = [SIMD3<Int32>]()
        imagePositions.reserveCapacity(Self.imageTokens)
        for h in 0..<16 {
            for w in 0..<16 {
                imagePositions.append(SIMD3(Int32(Self.capTokens + 1), Int32(h), Int32(w)))
            }
        }
        let (imageCos, imageSin) = Self.rope(positions: imagePositions)

        // Caption embed + refine, masking pad rows with cap_pad_token on the host.
        var capEmbedded = try graph("z_embc.tflite").run([captionInput])
        if validCount < Self.capTokens {
            for row in validCount..<Self.capTokens {
                for column in 0..<Self.hiddenDim {
                    capEmbedded[row * Self.hiddenDim + column] = host.capPadToken[column]
                }
            }
        }
        let capContext = try graph("z_refc.tflite").run([capEmbedded, captionCos, captionSin])
        return Branch(
            capContext: capContext,
            unifiedCos: imageCos + captionCos,
            unifiedSin: imageSin + captionSin,
            imageCos: imageCos,
            imageSin: imageSin
        )
    }

    // MARK: - Denoising

    /// One DiT evaluation: returns the velocity prediction in latent layout.
    private func denoise(latent: [Float], branch: Branch, adaln: [Float]) throws -> [Float] {
        var hidden = try graph("z_embx.tflite").run([Self.patchify(latent)])
        hidden = try graph("z_refx.tflite").run([hidden, branch.imageCos, branch.imageSin, adaln])
        hidden += branch.capContext
        for chunk in 0..<6 {
            hidden = try graph("zc_main\(chunk).tflite")
                .run([hidden, branch.unifiedCos, branch.unifiedSin, adaln])
        }
        let projected = try graph("zc_final.tflite").run([hidden, adaln])
        return Self.unpatchify(Array(projected[0..<(Self.imageTokens * 64)]))
    }

    // MARK: - Host math

    /// TimestepEmbedder: sinusoidal(256) -> Linear(1024) -> SiLU -> Linear(256).
    private static func timestepEmbedding(t: Float, host: HostAssets) throws -> [Float] {
        let half = frequencyEmbedSize / 2
        var embedding = [Float](repeating: 0, count: frequencyEmbedSize)
        let scaled = t * tScale
        for i in 0..<half {
            let frequency = exp(-logf(10_000) * Float(i) / Float(half))
            embedding[i] = cos(scaled * frequency)
            embedding[half + i] = sin(scaled * frequency)
        }
        let midSize = 1024
        var hiddenLayer = [Float](repeating: 0, count: midSize)
        vDSP_mmul(host.tEmbedderW0, 1, embedding, 1, &hiddenLayer, 1, vDSP_Length(midSize), 1, vDSP_Length(frequencyEmbedSize))
        for i in 0..<midSize {
            let value = hiddenLayer[i] + host.tEmbedderB0[i]
            hiddenLayer[i] = value / (1 + exp(-value))
        }
        var output = [Float](repeating: 0, count: frequencyEmbedSize)
        vDSP_mmul(host.tEmbedderW2, 1, hiddenLayer, 1, &output, 1, vDSP_Length(frequencyEmbedSize), 1, vDSP_Length(midSize))
        for i in 0..<frequencyEmbedSize {
            output[i] += host.tEmbedderB2[i]
        }
        return output
    }

    /// 3-axis RoPE tables (axes_dims 32/48/48 -> 16+24+24 = 64 cos/sin pairs).
    private static func rope(positions: [SIMD3<Int32>]) -> (cos: [Float], sin: [Float]) {
        let pairCounts = axesDims.map { $0 / 2 }
        let width = pairCounts.reduce(0, +)
        var cosTable = [Float](repeating: 0, count: positions.count * width)
        var sinTable = [Float](repeating: 0, count: positions.count * width)
        for (row, position) in positions.enumerated() {
            var column = 0
            for (axis, dim) in axesDims.enumerated() {
                let coordinate = Double(position[axis])
                for pair in 0..<(dim / 2) {
                    let frequency = 1.0 / pow(ropeTheta, Double(2 * pair) / Double(dim))
                    let angle = coordinate * frequency
                    cosTable[row * width + column] = Float(Foundation.cos(angle))
                    sinTable[row * width + column] = Float(Foundation.sin(angle))
                    column += 1
                }
            }
        }
        return (cosTable, sinTable)
    }

    /// linspace(1, 1/N, N) with static shift 3.0, terminal 0 appended.
    private static func shiftedSigmas(steps: Int) -> [Double] {
        var sigmas: [Double] = []
        for i in 0..<steps {
            let sigma = steps == 1 ? 1.0 : 1.0 - Double(i) * (1.0 - 1.0 / Double(steps)) / Double(steps - 1)
            sigmas.append(sigmaShift * sigma / (1.0 + (sigmaShift - 1.0) * sigma))
        }
        sigmas.append(0)
        return sigmas
    }

    /// Deterministic standard normal latent via SplitMix64 + Box-Muller.
    private static func gaussianLatent(seed: UInt64) -> [Float] {
        let count = latentChannels * latentSide * latentSide
        var state = seed &+ 0x9E37_79B9_7F4A_7C15
        func nextUniform() -> Double {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            z ^= z >> 31
            return (Double(z >> 11) + 0.5) / Double(1 << 53)
        }
        var values = [Float](repeating: 0, count: count)
        var index = 0
        while index < count {
            let u1 = nextUniform()
            let u2 = nextUniform()
            let radius = (-2.0 * log(u1)).squareRoot()
            values[index] = Float(radius * Foundation.cos(2.0 * .pi * u2))
            if index + 1 < count {
                values[index + 1] = Float(radius * Foundation.sin(2.0 * .pi * u2))
            }
            index += 2
        }
        return values
    }

    /// (16,32,32) latent -> (256,64) patch tokens (2x2 patches, row-major grid).
    private static func patchify(_ latent: [Float]) -> [Float] {
        let side = latentSide
        var tokens = [Float](repeating: 0, count: imageTokens * 64)
        for tokenH in 0..<16 {
            for tokenW in 0..<16 {
                let token = tokenH * 16 + tokenW
                for patchH in 0..<patchSize {
                    for patchW in 0..<patchSize {
                        for channel in 0..<latentChannels {
                            let sourceIndex = channel * side * side
                                + (tokenH * patchSize + patchH) * side
                                + (tokenW * patchSize + patchW)
                            let destinationIndex = token * 64
                                + (patchH * patchSize + patchW) * latentChannels
                                + channel
                            tokens[destinationIndex] = latent[sourceIndex]
                        }
                    }
                }
            }
        }
        return tokens
    }

    /// (256,64) tokens -> (16,32,32) latent. Inverse of `patchify`.
    private static func unpatchify(_ tokens: [Float]) -> [Float] {
        let side = latentSide
        var latent = [Float](repeating: 0, count: latentChannels * side * side)
        for tokenH in 0..<16 {
            for tokenW in 0..<16 {
                let token = tokenH * 16 + tokenW
                for patchH in 0..<patchSize {
                    for patchW in 0..<patchSize {
                        for channel in 0..<latentChannels {
                            let destinationIndex = channel * side * side
                                + (tokenH * patchSize + patchH) * side
                                + (tokenW * patchSize + patchW)
                            let sourceIndex = token * 64
                                + (patchH * patchSize + patchW) * latentChannels
                                + channel
                            latent[destinationIndex] = tokens[sourceIndex]
                        }
                    }
                }
            }
        }
        return latent
    }

    /// CHW float [-1,1] -> PNG data.
    private static func encodePNG(chwPixels: [Float], side: Int) throws -> Data {
        let pixelCount = side * side
        var rgba = [UInt8](repeating: 255, count: pixelCount * 4)
        for pixel in 0..<pixelCount {
            for channel in 0..<3 {
                let value = chwPixels[channel * pixelCount + pixel] / 2 + 0.5
                rgba[pixel * 4 + channel] = UInt8(max(0, min(255, (value * 255).rounded())))
            }
        }
        guard let provider = CGDataProvider(data: Data(rgba) as CFData),
              let cgImage = CGImage(
                  width: side,
                  height: side,
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: side * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: false,
                  intent: .defaultIntent
              ),
              let destinationData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(
                  destinationData, UTType.png.identifier as CFString, 1, nil
              ) else {
            throw PipelineError.imageEncodingFailed
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw PipelineError.imageEncodingFailed
        }
        return destinationData as Data
    }
}

#endif
