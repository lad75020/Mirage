# Implementation Plan: Single-Page Text-to-Image Generation

**Branch**: `main` (feature identifier `002-text-to-image`) | **Date**: 2026-07-14 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/002-text-to-image/spec.md`

**Propagated**: 2026-07-14 — Updated from spec.md refinement for featured and custom Hugging Face downloads, Files-accessible storage, selection-triggered lazy loading, and mandatory post-generation unloading.

## Summary

~~Replace the scaffold landing page with one adaptive SwiftUI image-generation page that lists all eight package model families from a fixed pre-provisioned catalog.~~ The fixed eight-family catalog is superseded by three featured Hugging Face repositories plus compatible public repository references entered by the user.

The adaptive page now supports explicit downloads of `jc-builds/Z-Image-Turbo-iOS`, `jc-builds/ERNIE-Image-Turbo-iOS`, and `jc-builds/Chroma1-HD-iOS`, plus a validated custom `owner/repository` or full `huggingface.co` model URL. Downloads resolve an immutable revision, stage and validate files atomically, and promote each complete model into its own folder under the app's Files-visible Documents model directory. The page then accepts a bounded prompt, invokes one on-device inference at a time, displays the validated result above the prompt, and saves an explicitly requested PNG to Photos.

Inference continues to use haplollc/Mirage `0.2.0` and its Quick Start contract, but ~~the app retains one multi-gigabyte `Engine` for reuse~~ the refined lifecycle loads only after an explicit user selection and destroys the engine after every native generation attempt. Prompt and generated pixels never enter the model-download request.

## Technical Context

**Language/Version**: Swift 6 language mode with strict concurrency, compiled by Xcode 26.x

**UI Framework**: SwiftUI on iOS 26.0+

**Apple Frameworks**: SwiftUI, Observation, Foundation, CoreGraphics, ImageIO, Photos, SensitiveContentAnalysis, OS, and XCTest/XCUITest

**Third-Party Dependencies**: `https://github.com/haplollc/Mirage.git`, exact stable release `0.2.0`, product `Mirage`, MIT-licensed. The package embeds stable-diffusion.cpp/ggml Metal through a release XCFramework whose published SHA-256 is `2754f948ff12e1c546f46e0dfa59f29627d468b1c30ba1783bdaa5d8948e5472`. Exact pinning prevents an unreviewed native binary or API update.

**Storage**: ~~Model bundles are non-user-browsable app assets under `Application Support/Models/<model-id>/`.~~ Downloaded snapshots are user-visible files under `Documents/Mirage Models/<repository-folder>/`, with staging outside the promoted folder, destination containment, safe filenames, available-space checks, immutable revision metadata, integrity/compatibility state, and appropriate data protection. Prompts and generated results remain in memory; the only durable generated output is an explicitly saved metadata-free PNG in Photos.

**Testing**: XCTest for repository-reference parsing, featured sources, download state, HTTPS/redirect policy, cancellation/recovery, immutable revisions, atomic staging, Files storage, integrity/compatibility, lazy load/unload, inference, safety, and Photos; XCUITest for featured/custom download journeys, accessibility, Files visibility, generation, and saving; physical-device evaluation for quality, safety, resources, and deterministic unloading

**Target Platform**: iOS 26.0+ on iPhone and iPad; physical Apple-silicon devices are required for inference, memory, energy, and thermal evidence. Simulator is limited to UI, catalog, and mocked-service tests.

**Project Type**: Native iOS application

**Performance Goals**: Acknowledge download, selection, and SEND actions promptly; report byte progress when the server provides content length; keep downloads resumable without exposing partial models; start model loading only after explicit selection; permit one load and one inference at a time; release engine/model memory after every attempt before another operation is accepted; preserve responsive scrolling and input during multi-GB transfer and multi-minute inference.

**AI/ML Strategy**: On-device diffusion through haplollc/Mirage `0.2.0`, which wraps stable-diffusion.cpp and ggml-metal. Featured descriptors bind the three exact `jc-builds` repositories to reviewed profiles; custom repository snapshots remain unusable until local file/architecture/package/device checks identify a supported profile. Repository code is never executed. The app passes the prompt only as `GenerationRequest.prompt`, applies approved safety policy, validates output, and performs on-device sensitive-content analysis before display.

**Privacy/Security**: No remote inference, telemetry, accounts, tracking, or prompt logging. Explicit public model downloads use HTTPS and only send repository/revision and protocol metadata to official Hugging Face service/CDN endpoints. References, redirects, snapshot metadata, filenames, and bytes are untrusted; tests cover traversal, symlink escape, archive bombs, executable payloads, case collisions, partial activation, Files tampering, and cleanup. Photos remains add-only and user initiated.

**Scale/Scope**: One adaptive page; three featured repository entries; any number of user-entered public repository references limited by device storage; one selected model; at most one transient engine; one load and one inference at a time; one displayed image; one explicit save operation. Typical model snapshots range from several to more than fourteen GB.

## Constitution Check

*GATE: Passed before research and re-checked after design.*

- [x] Uses Swift, SwiftUI, Swift 6 strict concurrency, and iOS 26.0+.
- [x] Uses native frameworks first. The Mirage package is the user-mandated inference dependency and is justified because Apple frameworks do not provide equivalent support for the requested sd.cpp-compatible model families.
- [x] Uses an actor-isolated inference service, a package-provided `Engine` actor, a `@MainActor` view model, `Sendable` value contracts, task ownership, and typed errors.
- [x] Performs on-device inference, local asset and memory eligibility checks, explicit unavailable states, one-engine resource bounds, model/version pinning, and physical-device evaluation.
- [x] Limits network use to explicit public Hugging Face model downloads, resolves immutable revisions, validates untrusted snapshots, stages atomically, and exposes promoted models through the user-requested Files folder.
- [x] Treats the prompt as untrusted generation content, exposes no autonomous tools, applies reviewed safety policy and negative prompts, validates output before display, and tests misuse, injection, bias, refusal, and false-positive paths.
- [x] Minimizes data, requests Photos add-only access, excludes prompt/result logging, protects local assets, defines deletion/release behavior, and includes MASVS/MASTG checks.
- [x] Includes unit, integration, UI, accessibility, safety/evaluation, degraded-state, and physical-device verification.
- [x] Reserves final project browsing, package resolution inspection, source membership, diagnostics, build, test, launch, and device verification for the Hermes-configured Xcode MCP server.

**Post-refinement re-check**: Passed conditionally. The refined network and Files scope requires privacy-manifest/configuration reconciliation plus physical-device download, storage, tampering, lazy-load, and unload evidence. A custom model may be downloaded but remains unavailable for generation until compatibility and runtime safety gates pass.

## Project Structure

### Documentation for This Feature

```text
specs/002-text-to-image/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── inference-contract.md
│   └── ui-contract.md
└── tasks.md                 # generated by /speckit-tasks
```

### Mirage Source Layout

```text
Mirage/
├── MirageApp.swift
├── AppMetadata.swift
├── ContentView.swift
├── Features/
│   └── ImageGeneration/
│       ├── ImageGenerationView.swift
│       ├── ImageGenerationViewModel.swift
│       ├── ImageGenerationState.swift
│       ├── ModelCatalog.swift
│       ├── ModelRepositoryReference.swift
│       ├── ModelDownload.swift
│       ├── HuggingFaceModelDownloader.swift
│       ├── ModelStore.swift
│       ├── ModelDescriptor.swift
│       ├── ModelFileResolver.swift
│       ├── MirageInferenceService.swift
│       ├── ImageSafetyService.swift
│       └── PhotoLibrarySaver.swift
├── Resources/
│   └── PrivacyInfo.xcprivacy
└── Mirage.entitlements

MirageTests/
├── AppMetadataTests.swift
├── ImageGenerationViewModelTests.swift
├── ModelCatalogTests.swift
├── ModelRepositoryReferenceTests.swift
├── HuggingFaceModelDownloaderTests.swift
├── ModelStoreTests.swift
├── ModelFileResolverTests.swift
├── MirageInferenceServiceTests.swift
├── ImageSafetyServiceTests.swift
├── PhotoLibrarySaverTests.swift
└── AIEvaluation/
    ├── PromptSafetyFixtures.json
    └── ModelEvaluationManifest.json

MirageUITests/
└── ImageGenerationJourneyTests.swift
```

**Structure Decision**: Keep the existing app entry and root view in place. ~~Do not add repositories, persistence, or networking.~~ Add small actor/protocol boundaries for canonical repository references, Hugging Face snapshot downloading, atomic Files-backed model storage, compatibility resolution, and load lifecycle; retain the existing inference, safety, memory, and Photos boundaries. Do not add accounts, remote inference, databases, navigation stacks, or executable plugin loading.

## Dependency and Build Configuration

1. Raise the app and test deployment targets from iOS 18.0 to iOS 26.0.
2. Add a remote Swift package named `MirageInference` at exact version `0.2.0`, and link its `Mirage` product to the app target.
3. Keep the app product and scheme named `Mirage`, but set the app Swift module name to `MirageApp` so app code can unambiguously `import Mirage`; update tests to `@testable import MirageApp`.
4. Add increased-memory-limit and extended-virtual-addressing entitlements required by the package's iPhone integration guidance.
5. Set `GGML_METAL_TENSOR_DISABLE=1` and `GGML_METAL_FUSION_DISABLE=1` in `MirageApp.init()` before any package or Metal initialization.
6. Add the Photo Library add usage description and a privacy manifest declaring no tracking or collected data; declare only actually used required-reason APIs.
7. Intermediate XcodeGen regeneration is permitted after `project.yml` changes, but it is not final evidence. Xcode MCP must inspect resolved package `0.2.0`, target membership, entitlements, build settings, and schemes before completion.
8. Enable the app's Documents container in Files with `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace`, and verify that only the dedicated `Mirage Models` subtree is used for downloaded model data.
9. Reconcile the privacy manifest, App Store privacy disclosure, and any network-security configuration with explicit public Hugging Face downloads; do not add credentials, background unrestricted networking, or arbitrary source domains.

## Model Sources, Downloads, and Availability

~~All eight package families are always listed in README order as a fixed catalog:~~

| ID | User-facing family | Architecture | README example | Initial availability rule |
|---|---|---|---|---|
| ~~`stable-diffusion`~~ | ~~Stable Diffusion 1.x / 2.x~~ | ~~UNet latent diffusion~~ | ~~`sd-v1-5.gguf`~~ | ~~Fixed entry removed.~~ |
| ~~`sdxl`~~ | ~~SDXL / SDXL-Turbo~~ | ~~Two-stage UNet latent diffusion~~ | ~~`sd-xl-base-1.0.gguf`~~ | ~~Fixed entry removed.~~ |
| ~~`sd3`~~ | ~~SD3 / SD3.5~~ | ~~MMDiT~~ | ~~`sd3.5-medium.gguf`~~ | ~~Fixed entry removed.~~ |
| ~~`flux1`~~ | ~~FLUX.1 schnell / dev~~ | ~~Rectified-flow DiT~~ | ~~`flux1-schnell-Q4_K.gguf`~~ | ~~Fixed entry removed.~~ |
| ~~`chroma1-hd`~~ | ~~Chroma1-HD~~ | ~~FLUX-derived 8.9B~~ | ~~`chroma1-hd.gguf`~~ | ~~Replaced by the featured repository below.~~ |
| ~~`qwen-image`~~ | ~~Qwen-Image~~ | ~~DiT 1.1B~~ | ~~`qwen-image-2512.gguf`~~ | ~~Fixed entry removed.~~ |
| ~~`ernie-image-turbo`~~ | ~~ERNIE-Image-Turbo~~ | ~~Turbo-distilled DiT~~ | ~~`ernie-image-turbo.gguf`~~ | ~~Replaced by the featured repository below.~~ |
| ~~`z-image-turbo`~~ | ~~Z-Image-Turbo~~ | ~~S3-DiT 6B~~ | ~~`z-image-turbo-Q3_K_M.gguf`~~ | ~~Replaced by the featured repository below.~~ |

The featured source list is exact and ordered:

1. `jc-builds/Z-Image-Turbo-iOS`
2. `jc-builds/ERNIE-Image-Turbo-iOS`
3. `jc-builds/Chroma1-HD-iOS`

Users may also enter a public `owner/repository` identifier or full `huggingface.co` model URL. The parser canonicalizes only Hugging Face model repositories, rejects credentials and unrelated domains, resolves the requested/default revision to an immutable commit, and records source/revision without prompt or generated-image data.

Download state is `notDownloaded`, `resolving`, `awaitingConfirmation(size, license)`, `downloading(bytes)`, `validating`, `downloaded`, `cancelled`, or `failed(recoverableReason)`. Files first enter a private staging area; validation then atomically promotes a snapshot to `Documents/Mirage Models/<safe-repository-folder>/`. Partial or unsafe snapshots never appear as selectable models.

Compatibility is distinct from download completion. Featured models use reviewed manifests/profiles. Custom snapshots may persist in Files but remain unselectable until the installed Mirage package recognizes required assets and architecture, device/memory gates pass, and runtime safety policy is available.

## Inference and Concurrency Design

- `@MainActor ImageGenerationViewModel` owns the prompt, selection, visible state, displayed PNG data, save feedback, and one generation task.
- `actor MirageInferenceService` owns at most one transient `Engine`, its descriptor ID, and progress callback lifecycle. Explicit selection validates the downloaded snapshot and begins lazy loading; merely listing or downloading never loads weights.
- The service follows Quick Start: create `ModelFiles(diffusionModel:vae:textEncoder:)`, create one `Engine` for the selected model, install `Mirage.setProgressCallback`, call `engine.generate(GenerationRequest)`, and use a teardown barrier to clear the callback and release the engine after every native attempt before another selection/load/generation is accepted.
- The package callback runs on a sampler thread. It yields `Sendable` progress values to the service stream; only the MainActor view model mutates UI.
- One request at a time is mandatory because both the app contract and package/global callback require serialization.
- Convert the returned `CGImage` to immutable PNG `Data` before handing the result to view state or Photos. Do not add unchecked sendability unless Xcode diagnostics prove it necessary and the risk is documented.
- The package does not expose native cancellation. A Swift task cancellation may discard a late result but cannot claim to stop native inference. No cancel control is shown in this feature; interruption behavior is explicit and tested.
- Preserve the previous validated image until a newer result passes structural and safety checks.
- If native work cannot be cancelled, the UI remains busy until it returns; teardown still runs for success, native failure, discarded late result, and interruption paths.

## UI and Interaction Design

Use a minimal, single-column, AI-native composition adapted to Apple HIG rather than the web-oriented custom fonts and fixed palette suggested by the generic design search:

1. A centered result card at the top, square by default, showing the previous image, empty guidance, model loading, determinate step progress, safety review, or recoverable error.
2. A labeled model area immediately below the result. It shows the three featured repositories with Download/Progress/Downloaded/Unavailable states, lists downloaded snapshots, and provides a labeled custom Hugging Face reference field and explicit Download action.
3. A labeled multiline prompt field with 1–1,000 character enforcement and a secondary character count.
4. A full-width bordered-prominent **SEND** button with at least a 44-point target. It is disabled for invalid input, unavailable selection, engine load, generation, or safety review.
5. A labeled Save button associated with the result card only after a validated image is displayed.

Use SF system text styles, semantic colors/materials, the existing app tint, SF Symbols, visible focus, and standard spacing. Do not use custom web fonts, emoji icons, hardcoded black/white/gold, heavy chrome, decorative motion, or color-only status. The entire page scrolls, respects safe areas and keyboard avoidance, constrains readable width on iPad, and adapts to accessibility Dynamic Type with `ViewThatFits` or vertical fallbacks.

Progress is both visual and semantic: announce download start/completion/failure, model loading once, then denoising milestones without speaking every callback; expose transfer bytes/total when known and generation step/total. Preserve focus, custom reference, and prompt text on errors. External keyboard users retain logical tab order plus Command-Return for SEND and Command-S for Save.

## AI, Prompt, and Security Design

**Availability and Fallback**: Every featured source is visible; user-entered sources appear after validation/download. Selection requires an atomically promoted snapshot, supported files/architecture, compatible device, sufficient memory, and a validated profile. Downloaded-but-incompatible models remain visible and Files-accessible with a concise reason. No cloud inference fallback exists.

**Prompt Trust Boundaries**: The 1–1,000-character normalized user string is passed only to `GenerationRequest.prompt`. Trusted model configuration and negative prompts remain separate immutable descriptor data. No prompt content becomes environment configuration, path data, logs, hidden instructions, or a capability request.

**Tool Authorization**: The inference path exposes no tools. Photo saving is a separate explicit button, requires a validated displayed image and add-only Photos authorization, and cannot be invoked by model output.

**Data Lifecycle**: Prompt, inference progress, and result remain memory-only. Downloaded model snapshots and source/revision/integrity metadata persist in `Documents/Mirage Models` for Files access. Download staging is removed after cancellation/failure. Engine/model memory is released after every generation attempt. Saving writes a fresh PNG without prompt/model metadata. Network traffic is limited to explicit Hugging Face model downloads; no telemetry or analytics is introduced.

**Threat Model and Runtime Assessment**: Test malformed/non-Hugging-Face references, redirect escape, immutable-revision mismatch, traversal, symlinks, archive bombs, duplicate/case-colliding paths, executable payloads, oversized/partial files, low storage, Files tampering, low-memory loads, repeated actions, stale callbacks, sensitive logging, prompt abuse, unsafe outputs, and Photos denial/revocation. Runtime review confirms prompts/results/credentials are absent from model folders, logs, defaults, pasteboard, and network traffic, and confirms engine teardown.

**Evaluation Plan**: For every enabled featured revision, record repository commit, file hashes, license, profile, device/OS, download/storage behavior, load time, generation time, unload completion, peak memory before/after teardown, thermal state, energy, structural validity, sensitive-content outcome, and bias/safety review. Run at least 20 consecutive attempts per enabled featured model/device class. Custom models receive structural/package/device/runtime-safety gates but no release quality endorsement.

## Xcode MCP Verification Plan

**Affected Schemes**: `Mirage` app/test scheme and the new `MirageUITests` scheme or test target if introduced

**Destinations**: Current iOS 26 simulator for UI/mocked tests; iPhone 16 Pro and/or iPhone 17 Pro-class physical devices for each enabled model; representative iPad hardware for adaptive UI and any model allowed there

**Required Evidence**:

- Browse every changed source/resource through Xcode MCP and confirm app/test target membership.
- Inspect resolved package identity, exact `0.2.0` version, `Mirage` product linkage, binary artifact, app module name, deployment target, entitlements, Info.plist usage text, and privacy manifest.
- Inspect Files exposure keys, dedicated Documents model path, network/privacy declarations, downloader/store source membership, and the absence of embedded credentials or arbitrary-domain exceptions.
- Resolve all Swift 6 concurrency and package integration diagnostics.
- Build and run unit, integration, UI, accessibility, privacy, and safety/evaluation tests through Xcode MCP.
- Launch through Xcode MCP and verify all single-page states on iPhone and iPad.
- Run featured and custom-reference download flows plus real selection/load/generation/unload/save flows, and collect transfer recovery, Files visibility, memory-release, thermal, energy, and timing evidence on eligible physical devices.

**Blocker Policy**: If the Hermes-configured Xcode MCP server is unavailable or fails, stop and report the blocker. Do not substitute `xcodebuild`, command-line project inspection, or XcodeGen output as final evidence.

## Complexity Tracking

No constitutional exception is requested. Complexity increases from a fixed local catalog to a secure downloader, Files-backed model store, dynamic compatibility state, and deterministic engine lifecycle. These boundaries are justified directly by FR-018 through FR-026 and remain isolated behind small `Sendable` protocols/actors; arbitrary code execution, authenticated repositories, cloud inference, and databases remain excluded.
