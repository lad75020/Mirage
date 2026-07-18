import Foundation

public struct ModelCatalogEntry: Identifiable, Equatable, Sendable {
    public let reference: ModelRepositoryReference
    public let descriptor: ModelDescriptor?
    public let snapshot: LocalModelSnapshot?

    public var id: String { reference.id }
    public var compatibility: ModelCompatibility {
        snapshot?.compatibility ?? .unknownCustomRepository
    }

    public init(
        reference: ModelRepositoryReference,
        descriptor: ModelDescriptor?,
        snapshot: LocalModelSnapshot?
    ) {
        self.reference = reference
        self.descriptor = descriptor
        self.snapshot = snapshot
    }
}

public enum ModelCatalog {
    public static let packageVersion = "0.2.0"

    public static let zImageReference = try! ModelRepositoryReference(owner: "jc-builds", repository: "Z-Image-Turbo-iOS")
    public static let ernieReference = try! ModelRepositoryReference(owner: "jc-builds", repository: "ERNIE-Image-Turbo-iOS")
    public static let chromaReference = try! ModelRepositoryReference(owner: "jc-builds", repository: "Chroma1-HD-iOS")

    public static let featuredReferences: [ModelRepositoryReference] = [
        zImageReference,
        ernieReference,
        chromaReference
    ]

    public static let entries: [ModelDescriptor] = [
        descriptor(
            .zImageTurbo,
            reference: zImageReference,
            reviewedRevisionSHA: "97ae389b962ee927d83c1911be743c8d82c11674",
            summary: "A bilingual, few-step photorealistic image model.",
            requirements: [
                .init(
                    role: .textEncoder,
                    fileName: "Qwen3-4B-Instruct-2507-Q4_K_M.gguf",
                    expectedByteCount: 2_497_281_120,
                    sha256: "3605803b982cb64aead44f6c1b2ae36e3acdb41d8e46c8a94c6533bc4c67e597"
                ),
                .init(
                    role: .vae,
                    fileName: "ae.safetensors",
                    expectedByteCount: 335_304_388,
                    sha256: "afc8e28272cd15db3919bacdb6918ce9c1ed22e96cb12c4d5ed0fba823529e38"
                ),
                .init(
                    role: .diffusionModel,
                    fileName: "z-image-turbo-Q3_K_M.gguf",
                    expectedByteCount: 4_186_161_216,
                    sha256: "7070b605165c372833c21c6bd45e73b242cf0db261b4d5436039363f3dbd4e0e"
                )
            ],
            profile: .init(width: 1024, height: 1024, steps: 9, cfgScale: 1, negativePrompt: safetyNegativePrompt),
            minimumMemory: 6_000_000_000,
            licenseApproved: true,
            evaluationApproved: true
        ),
        descriptor(
            .ernieImageTurbo,
            reference: ernieReference,
            reviewedRevisionSHA: "f23d470af1a57a64aa034d0770e74f99aac6135f",
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
            profile: .init(width: 1024, height: 1024, steps: 8, cfgScale: 1, negativePrompt: safetyNegativePrompt),
            minimumMemory: 7_000_000_000,
            licenseApproved: true,
            evaluationApproved: true
        ),
        descriptor(
            .chroma1HD,
            reference: chromaReference,
            reviewedRevisionSHA: "722a672dca0d2ec5ff39dea561ae0df62bf49995",
            summary: "A high-resolution FLUX-derived creative model.",
            requirements: [
                .init(
                    role: .diffusionModel,
                    fileName: "Chroma1-HD-Q4_K_S.gguf",
                    expectedByteCount: 5_432_053_920,
                    sha256: "4443db48850a45bb7f163a0582ea0e9f9d449db1aa56632c8572515e8e83acc8"
                ),
                .init(
                    role: .vae,
                    fileName: "ae.safetensors",
                    expectedByteCount: 335_304_388,
                    sha256: "afc8e28272cd15db3919bacdb6918ce9c1ed22e96cb12c4d5ed0fba823529e38"
                ),
                .init(
                    role: .textEncoder,
                    fileName: "t5xxl_fp16.safetensors",
                    expectedByteCount: 9_787_841_024,
                    sha256: "6e480b09fae049a72d2a8c5fbccb8d3e92febeb233bbe9dfe7256958a9167635"
                )
            ],
            profile: .init(width: 1024, height: 1024, steps: 28, cfgScale: 4, negativePrompt: safetyNegativePrompt),
            minimumMemory: 16_000_000_000,
            licenseApproved: true,
            evaluationApproved: true
        )
    ]

    public static func descriptor(for id: ModelID) -> ModelDescriptor? {
        entries.first { $0.id == id }
    }

    public static func descriptor(for reference: ModelRepositoryReference) -> ModelDescriptor? {
        entries.first { $0.repository == reference }
    }

    public static func catalogEntries(downloadedSnapshots: [LocalModelSnapshot] = []) -> [ModelCatalogEntry] {
        var seen = Set<ModelRepositoryReference>()
        let featured = featuredReferences.map { reference -> ModelCatalogEntry in
            seen.insert(reference)
            return ModelCatalogEntry(
                reference: reference,
                descriptor: descriptor(for: reference),
                snapshot: downloadedSnapshots.first { $0.reference == reference }
            )
        }
        let custom = downloadedSnapshots
            .filter { !seen.contains($0.reference) }
            .map { snapshot in
                ModelCatalogEntry(
                    reference: snapshot.reference,
                    descriptor: snapshot.descriptor,
                    snapshot: snapshot
                )
            }
        return featured + custom
    }

    public static func compatibility(for snapshot: LocalModelSnapshot) -> ModelCompatibility {
        // Built-in catalog evidence is authoritative for featured repositories so
        // an app update can approve an existing verified download without requiring
        // users to delete and redownload a snapshot with stale embedded metadata.
        guard let descriptor = descriptor(for: snapshot.reference) ?? snapshot.descriptor,
              descriptor.reviewedRevisionSHA == snapshot.commitSHA,
              descriptor.licenseApproved,
              descriptor.evaluationApproved,
              descriptor.requirements.allSatisfy({ requirement in
                  snapshot.files.contains {
                      $0.path == requirement.fileName
                          && $0.sizeBytes == requirement.expectedByteCount
                          && $0.sha256 == requirement.sha256
                  }
              }) else {
            return .unknownCustomRepository
        }
        return .compatible(profile: descriptor.profile)
    }

    private static let safetyNegativePrompt = [
        "sexualized minor", "child sexual abuse", "explicit nudity", "pornographic",
        "graphic gore", "dismemberment", "hate symbol", "extremist propaganda"
    ].joined(separator: ", ")

    private static func descriptor(
        _ id: ModelID,
        reference: ModelRepositoryReference,
        reviewedRevisionSHA: String,
        summary: String,
        requirements: [ModelFileRequirement],
        profile: GenerationProfile,
        minimumMemory: UInt64,
        licenseApproved: Bool,
        evaluationApproved: Bool = false
    ) -> ModelDescriptor {
        ModelDescriptor(
            id: id,
            repository: reference,
            reviewedRevisionSHA: reviewedRevisionSHA,
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
