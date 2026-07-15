import CoreGraphics
import Foundation
import ImageIO
import SensitiveContentAnalysis

public enum ImageSafetyError: Error, Equatable, Sendable {
    case invalidPrompt
    case refusedPrompt
    case invalidImage
    case analysisUnavailable
    case sensitiveOutput
}

public struct PromptSafetyPolicy: Sendable {
    public static let version = "2026-07-14"
    public static let current = PromptSafetyPolicy()

    private let injectionPhrases = [
        "ignore previous instructions",
        "reveal the hidden system prompt",
        "reveal hidden policy",
        "bypass safety",
        "bypass safeguards",
        "bypass its safeguards",
        "disable safeguards"
    ]
    private let explicitPhrases = [
        "child sexual abuse",
        "sexualized explicit depiction of a minor",
        "sexualised explicit depiction of a minor",
        "graphic dismemberment",
        "exposed organs",
        "extremist propaganda praising"
    ]

    public init() {}

    public func validatedPrompt(_ input: String) throws -> String {
        let prompt = input
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, prompt.count <= 1_000 else {
            throw ImageSafetyError.invalidPrompt
        }
        let normalized = prompt.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
        guard !injectionPhrases.contains(where: normalized.contains),
              !explicitPhrases.contains(where: normalized.contains) else {
            throw ImageSafetyError.refusedPrompt
        }
        return prompt
    }
}

public struct AppleSensitivityAnalyzer: ImageSensitivityAnalyzing {
    public init() {}

    public func isSensitive(pngData: Data) async throws -> Bool {
        guard let source = CGImageSourceCreateWithData(pngData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ImageSafetyError.invalidImage
        }
        let analyzer = SCSensitivityAnalyzer()
        guard analyzer.analysisPolicy != .disabled else {
            throw ImageSafetyError.analysisUnavailable
        }
        do {
            return try await analyzer.analyzeImage(image).isSensitive
        } catch {
            throw ImageSafetyError.analysisUnavailable
        }
    }
}

public actor ImageSafetyService: ImageSafetyChecking {
    private static let pngSignature = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    private let analyzer: any ImageSensitivityAnalyzing
    private let policy: PromptSafetyPolicy

    public init(
        analyzer: any ImageSensitivityAnalyzing = AppleSensitivityAnalyzer(),
        policy: PromptSafetyPolicy = .current
    ) {
        self.analyzer = analyzer
        self.policy = policy
    }

    public func validatePrompt(_ prompt: String) async throws -> String {
        try policy.validatedPrompt(prompt)
    }

    public func validateOutput(_ image: GeneratedImage) async throws -> GeneratedImage {
        guard image.pngData.count <= 64 * 1_024 * 1_024,
              image.pngData.starts(with: Self.pngSignature),
              let source = CGImageSourceCreateWithData(image.pngData as CFData, nil),
              CGImageSourceGetCount(source) == 1,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width == image.width,
              height == image.height,
              (1...4_096).contains(width),
              (1...4_096).contains(height) else {
            throw ImageSafetyError.invalidImage
        }
        do {
            if try await analyzer.isSensitive(pngData: image.pngData) {
                throw ImageSafetyError.sensitiveOutput
            }
        } catch let error as ImageSafetyError {
            throw error
        } catch {
            throw ImageSafetyError.analysisUnavailable
        }
        return image
    }
}
