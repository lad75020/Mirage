# Inference, Download, and Service Contract

**Feature**: `002-text-to-image`
**Package**: `https://github.com/haplollc/Mirage.git` exact `0.2.0`

This contract isolates SwiftUI from repository parsing, Hugging Face metadata/downloads, Files-visible model storage, native inference, output safety, memory gates, and Photos.

## Model source contract

```swift
struct ModelRepositoryReference: Hashable, Codable, Sendable {
    let owner: String
    let repository: String
}
```

Required semantics:

- Accept only public unauthenticated Hugging Face model repositories.
- Normalize `owner/repository` and `https://huggingface.co/owner/repository`.
- Reject credentials, tokens, query strings, fragments, ports, non-HTTPS URLs, non-Hugging-Face hosts, encoded path separators, malformed path components, private repositories, and gated repositories.
- Never place prompts, generated pixels, credentials, or private user data in repository URLs, folder names, logs, fixtures, or evidence.

## Download contract

```swift
protocol ModelDownloading: Sendable {
    func resolve(reference: ModelRepositoryReference) async throws -> ModelDownloadPlan
    func download(
        plan: ModelDownloadPlan,
        to stagingURL: URL,
        progress: @escaping @Sendable (ModelDownloadProgress) -> Void
    ) async throws
}
```

Required semantics:

- Request metadata from `https://huggingface.co/api/models/<owner>/<repository>?blobs=true`.
- Cap metadata at 2 MiB.
- Require public, ungated metadata; a 40-character immutable commit SHA; a nonempty license; positive file sizes; and 64-character LFS SHA-256 hashes.
- Select only safe relative `.gguf` and `.safetensors` paths.
- Enforce at most 24 files, at most 16 GiB per file, and at most 24 GiB per snapshot.
- Use HTTPS and default server trust handling.
- Allow redirects only to `huggingface.co`, `cdn-lfs.huggingface.co`, `cdn-lfs-us-1.huggingface.co`, `cdn-lfs-eu-1.huggingface.co`, `cdn-lfs.hf.co`, and `cas-bridge.xethub.hf.co`.
- Stream file downloads to staging and report byte progress when expected size is known.
- Verify size and SHA-256 for every file before returning.
- Remove staging data on cancellation or failure; never mark partial bytes as usable.

## Model store contract

```swift
protocol ModelSnapshotStoring: Sendable {
    var modelRootURL: URL { get }
    func stagingURL(for reference: ModelRepositoryReference) async throws -> URL
    func discardStagingURL(_ url: URL) async
    func validateCanStore(plan: ModelDownloadPlan) async throws
    func promote(plan: ModelDownloadPlan, from stagingURL: URL) async throws -> LocalModelSnapshot
    func refreshSnapshots() async -> [LocalModelSnapshot]
    func availableBytes() async -> Int64
}
```

Required semantics:

- Root promoted snapshots under `Documents/Mirage Models`.
- Keep staging outside the promoted model folder.
- Use stable safe repository folder names with a digest.
- Validate available storage before and during promotion.
- Enforce containment, safe filenames, extension allowlist, file count, byte count, SHA-256, case-collision checks, symlink rejection, executable rejection, archive rejection, hidden-file rejection except `.mirage-snapshot.json`, and unexpected-file rejection.
- Write snapshot metadata with source, immutable revision, folder name, license, file list, sizes, and hashes.
- Promote atomically through a replacement directory and remove staging on success.
- On Files edits/removals, refresh compatibility and fail closed instead of loading stale or tampered files.

## Catalog contract

```swift
enum ModelCatalog {
    static let featuredReferences: [ModelRepositoryReference]
    static let entries: [ModelDescriptor]
    static func descriptor(for reference: ModelRepositoryReference) -> ModelDescriptor?
    static func catalogEntries(downloadedSnapshots: [LocalModelSnapshot]) -> [ModelCatalogEntry]
}
```

Featured references are exact and ordered:

1. `jc-builds/Z-Image-Turbo-iOS`
2. `jc-builds/ERNIE-Image-Turbo-iOS`
3. `jc-builds/Chroma1-HD-iOS`

Featured descriptors bind to the exact commits, Apache-2.0 license metadata, required files, byte counts, LFS SHA-256 hashes, and profiles recorded in `ModelEvaluationManifest.json`. The exact reviewed Z-Image snapshot is runtime-enabled; ERNIE and Chroma remain disabled. Custom snapshots are visible after download but default to `unknownCustomRepository` and are unselectable until local compatibility is proven.

## Model file resolver contract

```swift
protocol ModelAvailabilityProviding: Sendable {
    func availability(for descriptor: ModelDescriptor) async -> ModelAvailability
    func resolve(_ descriptor: ModelDescriptor) async throws -> ResolvedModelFiles
}
```

Required semantics:

- Resolve only from the Files-visible `Documents/Mirage Models/<safe-repository-folder>` root.
- Recheck protected data, license, evaluation approval, OS, device allowlist, profile, safety policy, memory, file presence, extension, symlink/executable flags, byte count, and SHA-256 before returning native file URLs.
- Return typed availability/errors; do not expose paths, hashes, prompts, native diagnostics, or hidden policy details to UI copy.

## Inference contract

```swift
protocol ImageGenerating: Sendable {
    func generate(
        request: GenerationRequestSnapshot,
        descriptor: ModelDescriptor,
        progress: @escaping @Sendable (GenerationProgress) -> Void
    ) async throws -> GeneratedImage
}
```

`MirageInferenceService` is an actor. Required semantics:

- Listing, resolving metadata, downloading, and catalog refresh must not load native weights.
- Accept generation only for an explicit logical selection and an available descriptor.
- Resolve files inside the service boundary immediately before native load.
- Serialize native attempts; do not allow competing loads or inference.
- Create package `ModelFiles(diffusionModel:vae:textEncoder:)` only from resolver-produced URLs.
- Load the native `Engine` after SEND begins the selected model attempt.
- Install `Mirage.setProgressCallback` before native generation and clear it on every path.
- Call `Engine.generate(_:)` exactly once per accepted request.
- Convert `CGImage` to immutable PNG `Data`, validate dimensions, and return a `GeneratedImage`.
- Await `driver.unload()` after success, native failure, invalid output, cancellation, or discarded late result before accepting the next attempt.
- Do not reuse an engine across attempts. Logical selection may remain visible after unload, but native model memory must not remain loaded.
- Do not claim native inference cancellation; package `0.2.0` does not expose a reliable cancellation API.

## Safety and Photos contracts

Prompt safety:

- Normalize and validate 1...1000 visible characters.
- Treat prompt text only as untrusted generation content.
- Never log or persist the prompt.

Output safety:

- Validate nonempty PNG data and expected dimensions.
- Run on-device Sensitive Content Analysis.
- Fail closed when analysis is required and unavailable.
- Preserve the previous allowed image on refusal or invalid output.

Photos:

- Request add-only authorization only after explicit Save.
- Save exactly the current validated PNG once per accepted action.
- Do not read Photos or attach prompt/model metadata.

## View-model contract

`@MainActor ImageGenerationViewModel` owns:

- featured and downloaded catalog entries;
- download states and pending confirmation;
- explicit selected model ID;
- prompt and validation message;
- one operation state;
- one generation task;
- one download task;
- current displayed PNG;
- save state.

SEND is accepted only when the prompt is valid, a compatible fully downloaded model is explicitly selected and available, no download/load/generation/safety operation conflicts, and prompt safety allows the request.

No user-facing error contains native log text, filesystem paths, hashes, hidden safety instructions, credentials, or raw permission diagnostics.
