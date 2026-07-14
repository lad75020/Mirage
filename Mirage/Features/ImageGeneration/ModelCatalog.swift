import Foundation

public enum ModelCatalog {
    public static let packageVersion = "0.2.0"

    public static let entries: [ModelDescriptor] = [
        descriptor(
            .stableDiffusion,
            summary: "Established diffusion families for broad image generation.",
            profile: .init(width: 512, height: 512, steps: 28, cfgScale: 7)
        ),
        descriptor(
            .sdxl,
            summary: "High-resolution SDXL and distilled SDXL-Turbo pipelines.",
            profile: .init(width: 1024, height: 1024, steps: 24, cfgScale: 6)
        ),
        descriptor(
            .sd3,
            summary: "Stable Diffusion 3 and 3.5 transformer pipelines.",
            profile: .init(width: 1024, height: 1024, steps: 28, cfgScale: 5)
        ),
        descriptor(
            .flux,
            summary: "FLUX.1 schnell and dev family pipelines.",
            profile: .init(width: 1024, height: 1024, steps: 20, cfgScale: 3.5)
        ),
        descriptor(
            .chroma1HD,
            summary: "A high-resolution FLUX-derived creative model.",
            requirements: [
                .init(role: .diffusionModel, fileName: "Chroma1-HD-Q4_K_S.gguf", sha256: nil),
                .init(role: .vae, fileName: "ae.safetensors", sha256: nil),
                .init(role: .textEncoder, fileName: "t5xxl_fp16.safetensors", sha256: nil)
            ],
            profile: .init(width: 1024, height: 1024, steps: 28, cfgScale: 4),
            minimumMemory: 16_000_000_000
        ),
        descriptor(
            .qwenImage,
            summary: "Qwen image-generation family with strong prompt understanding.",
            profile: .init(width: 1024, height: 1024, steps: 24, cfgScale: 4)
        ),
        descriptor(
            .ernieImageTurbo,
            summary: "A few-step model optimized for photorealism and rendered text.",
            requirements: [
                .init(
                    role: .diffusionModel,
                    fileName: "ernie-image-turbo-Q3_K_M.gguf",
                    expectedByteCount: 3_909_632_704,
                    sha256: "3c1813fc1e0e904cc342e7b6791d0165e6dbb6aac30ad2924747b198bc435857"
                ),
                .init(
                    role: .vae,
                    fileName: "ae.safetensors",
                    expectedByteCount: 168_120_878,
                    sha256: "ca70d2202afe6415bdbcb8793ba8cd99fd159cfe6192381504d6c4d3036e0f04"
                ),
                .init(
                    role: .textEncoder,
                    fileName: "Ministral-3-3B-Instruct-2512-Q4_K_M.gguf",
                    expectedByteCount: 2_146_497_824,
                    sha256: "fd46fc371ff0509bfa8657ac956b7de8534d7d9baaa4947975c0648c3aa397f4"
                )
            ],
            profile: .init(
                width: 1024,
                height: 1024,
                steps: 8,
                cfgScale: 1,
                negativePrompt: safetyNegativePrompt
            ),
            minimumMemory: 7_000_000_000,
            licenseApproved: true
        ),
        descriptor(
            .zImageTurbo,
            summary: "A bilingual, few-step photorealistic image model.",
            requirements: [
                .init(role: .diffusionModel, fileName: "z-image-turbo-Q3_K_M.gguf", sha256: nil),
                .init(role: .vae, fileName: "ae.safetensors", sha256: nil),
                .init(role: .textEncoder, fileName: "Qwen3-4B-Instruct-2507-Q4_K_M.gguf", sha256: nil)
            ],
            profile: .init(
                width: 1024,
                height: 1024,
                steps: 9,
                cfgScale: 1,
                negativePrompt: safetyNegativePrompt
            ),
            minimumMemory: 8_000_000_000
        )
    ]

    public static func descriptor(for id: ModelID) -> ModelDescriptor? {
        entries.first { $0.id == id }
    }

    private static let safetyNegativePrompt = [
        "sexualized minor", "child sexual abuse", "explicit nudity", "pornographic",
        "graphic gore", "dismemberment", "hate symbol", "extremist propaganda"
    ].joined(separator: ", ")

    private static func descriptor(
        _ id: ModelID,
        summary: String,
        requirements: [ModelFileRequirement] = [],
        profile: GenerationProfile,
        minimumMemory: UInt64 = 0,
        licenseApproved: Bool = false,
        evaluationApproved: Bool = false
    ) -> ModelDescriptor {
        ModelDescriptor(
            id: id,
            familyName: id.displayName,
            summary: summary,
            packageVersion: packageVersion,
            requirements: requirements,
            profile: profile,
            minimumAvailableMemoryBytes: minimumMemory,
            licenseApproved: licenseApproved,
            evaluationApproved: evaluationApproved
        )
    }
}
