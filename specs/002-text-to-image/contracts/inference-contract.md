# Inference and Service Contract

**Feature**: `002-text-to-image`
**Package**: `https://github.com/haplollc/Mirage.git` exact `0.2.0`

This contract isolates the SwiftUI feature from the package's native engine, global progress callback, file system, memory query, safety analyzer, and Photos framework. Names are implementation targets; signatures may receive syntax-only adjustments required by Xcode diagnostics without changing semantics.

## Package adapter contract

```swift
protocol ImageGenerating: Sendable {
    func generate(
        _ input: GenerationInput,
        progress: @escaping @Sendable (GenerationProgress) -> Void
    ) async throws -> GeneratedImagePayload

    func unload() async
}

struct GeneratedImagePayload: Sendable, Equatable {
    let pngData: Data
    let pixelWidth: Int
    let pixelHeight: Int
}
```

`MirageInferenceService` is an actor implementing `ImageGenerating`.

### Required semantics

- Resolve the selected descriptor and model files inside the service boundary.
- Reuse an existing `Engine` only when its descriptor ID matches.
- Before loading a different model, clear the package callback, release the previous engine, and re-run availability/memory gates.
- Construct package `ModelFiles` using only resolver-produced local URLs.
- Install `Mirage.setProgressCallback` immediately before generation; bridge sampler-thread values without touching UI state.
- Clear the callback in `defer` on success, failure, or task invalidation.
- Call `Engine.generate(_:)` exactly once per accepted request.
- Encode the returned image with the package's PNG helper or equivalent metadata-free ImageIO path.
- Never expose the package engine, native context, raw error text, or local file paths outside the service.
- Maintain busy state until native generation actually returns. Swift task cancellation must not be represented as native cancellation.

## Model catalog contract

```swift
protocol ModelCatalogProviding: Sendable {
    var descriptors: [ModelDescriptor] { get }
    func descriptor(id: ModelID) -> ModelDescriptor?
}
```

The ordered descriptor IDs are fixed:

```text
stable-diffusion
sdxl
sd3
flux1
chroma1-hd
qwen-image
ernie-image-turbo
z-image-turbo
```

The provider always returns all eight. Availability is computed separately and never removes an entry.

## Model file resolver contract

```swift
protocol ModelFileResolving: Sendable {
    func availability(for descriptor: ModelDescriptor) async -> ModelAvailability
    func resolve(for descriptor: ModelDescriptor) async throws -> ResolvedModelFiles
}

struct ResolvedModelFiles: Sendable {
    let diffusionModel: URL
    let vae: URL?
    let textEncoder: URL?
}
```

### Required semantics

- Root all resolution under the app's `Application Support/Models` directory.
- Reject absolute filenames, separators, traversal, symlinks escaping the root, wrong file types, missing files, size mismatch, and hash mismatch.
- Require license, device, profile, safety, package-version, and evaluation approval.
- Exclude the model root from backup and use appropriate file protection.
- Return typed availability/errors; do not expose paths or hashes to user-facing messages.

## Memory gate contract

```swift
protocol AvailableMemoryProviding: Sendable {
    func availableBytes() -> UInt64
}
```

A load passes only when:

```text
available == unknown
OR
available >= max(
  diffusionFileBytes + 1 GiB,
  descriptor.bundleBytes + descriptor.activationHeadroomBytes
)
```

The unknown value may be accepted only if the descriptor/device pair has separate conservative physical-device evidence. Otherwise return `insufficientMemory` rather than attempting a crash-prone load.

## Prompt safety contract

```swift
protocol PromptSafetyEvaluating: Sendable {
    func evaluate(_ prompt: String) async -> PromptSafetyDecision
}
```

### Required semantics

- Normalize without changing user intent; enforce 1–1,000 visible characters.
- Treat input as untrusted generation content only.
- Return `allowed(normalizedPrompt)` or a coarse recoverable refusal.
- Never emit hidden policy text, rewrite the prompt silently, or log the prompt.
- Maintain versioned fixtures for harmful content, injection/jailbreak text, stereotypes, representative bias, unsupported languages, and false positives.

## Output safety contract

```swift
protocol ImageSafetyEvaluating: Sendable {
    func evaluate(_ payload: GeneratedImagePayload) async -> SafetyResult
}
```

### Required semantics

- Confirm nonempty decodable PNG and expected dimensions before content analysis.
- Use on-device Sensitive Content Analysis where available.
- Fail closed for analyzer failure when policy requires review.
- Do not display or save refused/unreviewed output.
- Preserve the previous allowed image when the new output is refused or invalid.
- Do not persist analyzer details or generated pixels.

## Photo Library contract

```swift
protocol PhotoLibrarySaving: Sendable {
    func authorizationStatus() async -> PhotoAddAuthorization
    func savePNG(_ data: Data) async throws
}
```

### Required semantics

- Ask only for add-only authorization and only after explicit Save.
- Save exactly the current validated PNG once per accepted action.
- Do not request read access, enumerate assets, or attach prompt/model metadata.
- Return typed denied, restricted, encoding, and save failures.
- Keep the displayed image and allow recovery when save fails.

## View-model contract

`@MainActor @Observable final class ImageGenerationViewModel` owns:

- ordered visible descriptors and availability;
- selected model ID;
- prompt and validation message;
- one `ImageGenerationState`;
- one generation task token/request ID;
- current displayed PNG data;
- save outcome.

### SEND preconditions

SEND is accepted only when:

- trimmed prompt has 1–1,000 visible characters;
- the selected descriptor is available;
- no load, inference, safety review, or save transition conflicts;
- prompt safety returns allowed.

A request snapshots the selected model and prompt. Later UI edits cannot mutate an in-flight request.

## Typed error mapping

| Internal category | User-facing behavior |
|---|---|
| Missing/integrity-failed model assets | Keep selection visible, disable SEND, explain that model files are unavailable. |
| Unsupported device / insufficient memory | Disable that model and suggest another available model. |
| License/profile/safety not approved | Disable model as unavailable in this build. |
| Package model-load failure | Preserve prior image; offer Retry after rechecking availability. |
| Package generation failure | Preserve prior image and prompt; offer Retry. |
| Invalid image / PNG failure | Preserve prior image; report that the result could not be used. |
| Prompt refusal | Preserve prior image; allow prompt editing. |
| Output refusal | Do not display/save new image; preserve prior image. |
| Photos denied/restricted | Keep image; explain Settings recovery without claiming save. |
| Photos write failure | Keep image; allow another explicit Save attempt. |

No user-facing error contains native log text, filesystem paths, hashes, hidden safety instructions, or raw permission diagnostics.
