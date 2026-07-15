import CryptoKit
import Foundation

public enum AdvancedModelComposerError: Error, Equatable, Sendable {
    case missingModelFile(String)
    case ambiguousRepository(String)
    case incompatibleModelFile(String)
}

public enum AdvancedModelComposer {
    public static let compositeReference = try! ModelRepositoryReference(
        owner: "mirage-user",
        repository: "advanced-composite"
    )

    public static func compose(
        tokenizer: ModelDownloadPlan,
        transformer: ModelDownloadPlan,
        vae: ModelDownloadPlan
    ) throws -> ModelDownloadPlan {
        let inputs: [(label: String, folder: String, role: ModelFileRole, plan: ModelDownloadPlan)] = [
            ("Tokenizer", "tokenizer", .textEncoder, tokenizer),
            ("Transformer", "transformer", .diffusionModel, transformer),
            ("VAE", "vae", .vae, vae)
        ]

        var files: [ModelDownloadFile] = []
        var requirements: [ModelFileRequirement] = []
        for input in inputs {
            let source = try singleModelFile(in: input.plan, label: input.label, role: input.role)
            let path = "advanced/\(input.folder)/\(URL(fileURLWithPath: source.path).lastPathComponent)"
            files.append(
                ModelDownloadFile(
                    path: path,
                    sizeBytes: source.sizeBytes,
                    sha256: source.sha256,
                    downloadURL: source.downloadURL
                )
            )
            requirements.append(
                ModelFileRequirement(
                    role: input.role,
                    fileName: path,
                    expectedByteCount: source.sizeBytes,
                    sha256: source.sha256
                )
            )
        }

        let commitSHA = compositeCommitSHA(plans: inputs.map(\.plan))
        let revision = try ResolvedModelRevision(
            reference: compositeReference,
            commitSHA: commitSHA,
            license: combinedLicense(plans: inputs.map(\.plan)),
            totalSizeBytes: files.reduce(0) { $0 + $1.sizeBytes }
        )
        let descriptor = ModelDescriptor(
            id: .advancedCustom,
            repository: compositeReference,
            reviewedRevisionSHA: commitSHA,
            familyName: ModelID.advancedCustom.displayName,
            summary: "User-composed Tokenizer, Transformer, and VAE model.",
            packageVersion: ModelCatalog.packageVersion,
            requirements: requirements,
            profile: GenerationProfile(width: 1024, height: 1024, steps: 20, cfgScale: 7),
            minimumAvailableMemoryBytes: 0,
            licenseApproved: true,
            evaluationApproved: true
        )
        return ModelDownloadPlan(revision: revision, files: files, descriptor: descriptor)
    }

    private static func singleModelFile(
        in plan: ModelDownloadPlan,
        label: String,
        role: ModelFileRole
    ) throws -> ModelDownloadFile {
        let candidates = plan.files.filter { file in
            let ext = URL(fileURLWithPath: file.path).pathExtension.lowercased()
            switch role {
            case .vae:
                return ext == "safetensors"
            case .diffusionModel, .textEncoder:
                return ext == "gguf" || ext == "safetensors"
            }
        }
        guard !candidates.isEmpty else { throw AdvancedModelComposerError.missingModelFile(label) }
        guard candidates.count == 1 else { throw AdvancedModelComposerError.ambiguousRepository(label) }
        guard candidates[0].sha256?.count == 64 else {
            throw AdvancedModelComposerError.incompatibleModelFile(label)
        }
        return candidates[0]
    }

    private static func compositeCommitSHA(plans: [ModelDownloadPlan]) -> String {
        let identity = plans
            .map { "\($0.revision.reference.id)@\($0.revision.commitSHA)" }
            .joined(separator: "|")
        return SHA256.hash(data: Data(identity.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
            .prefix(40)
            .description
    }

    private static func combinedLicense(plans: [ModelDownloadPlan]) -> String? {
        let licenses = plans.compactMap(\.revision.license)
        guard licenses.count == plans.count else { return nil }
        return Set(licenses).sorted().joined(separator: "+")
    }
}
