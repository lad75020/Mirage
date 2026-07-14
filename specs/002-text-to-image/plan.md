# Implementation Plan: Single-Page Text-to-Image Generation

**Branch**: `main` (feature identifier `002-text-to-image`) | **Date**: 2026-07-14 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/002-text-to-image/spec.md`

## Summary

Replace the scaffold landing page with one adaptive SwiftUI image-generation page. The page lists all eight model families documented by haplollc/Mirage, accepts a bounded prompt, invokes one on-device inference at a time, reports live denoising progress, displays the validated result above the prompt, and saves an explicitly requested PNG to the Photo Library.

Inference uses the exact latest stable haplollc/Mirage Swift package release at planning time, `0.2.0`, following its Quick Start contract: construct `ModelFiles`, create and retain one `Engine` for the active model, install a worker-thread progress callback, and call `Engine.generate(_:)`. The app keeps only one multi-gigabyte engine resident, resolves model assets from app-managed local storage, and exposes unavailable catalog entries with actionable reasons. No model download UI or remote inference is introduced.

## Technical Context

**Language/Version**: Swift 6 language mode with strict concurrency, compiled by Xcode 26.x

**UI Framework**: SwiftUI on iOS 26.0+

**Apple Frameworks**: SwiftUI, Observation, Foundation, CoreGraphics, ImageIO, Photos, SensitiveContentAnalysis, OS, and XCTest/XCUITest

**Third-Party Dependencies**: `https://github.com/haplollc/Mirage.git`, exact stable release `0.2.0`, product `Mirage`, MIT-licensed. The package embeds stable-diffusion.cpp/ggml Metal through a release XCFramework whose published SHA-256 is `2754f948ff12e1c546f46e0dfa59f29627d468b1c30ba1783bdaa5d8948e5472`. Exact pinning prevents an unreviewed native binary or API update.

**Storage**: Model bundles are local app-managed files under `Application Support/Models/<model-id>/`, excluded from backup and protected appropriately. Prompts and generated results remain in memory. The only durable user output is an explicitly saved metadata-free PNG in Photos.

**Testing**: XCTest for catalog, validation, state, inference adapter, safety, and Photo Library abstractions; XCUITest for the single-page journeys and accessibility; model evaluation fixtures for quality, safety, bias, resource, and fallback tests

**Target Platform**: iOS 26.0+ on iPhone and iPad; physical Apple-silicon devices are required for inference, memory, energy, and thermal evidence. Simulator is limited to UI, catalog, and mocked-service tests.

**Project Type**: Native iOS application

**Performance Goals**: Acknowledge accepted SEND actions within 500 ms; surface step progress from the first package callback; load a model once and reuse it; keep one engine resident; reject loads that fail file, compatibility, license, or available-memory gates; never exceed the descriptor's approved memory budget; preserve responsive scrolling and input during multi-minute inference.

**AI/ML Strategy**: On-device diffusion through haplollc/Mirage `0.2.0`, which wraps stable-diffusion.cpp and ggml-metal. The fixed catalog covers eight documented model families. Each enabled catalog entry supplies validated model-file URLs and a generation profile. The app passes the user prompt only as `GenerationRequest.prompt`, applies an approved model-specific negative prompt, structurally validates the result, and runs on-device sensitive-content analysis before display.

**Privacy/Security**: No remote inference, telemetry, accounts, tracking, or prompt logging. Model files are app-managed and non-user-browsable in this feature. Photos uses add-only authorization requested on Save. Safety policy, model assets, licenses, prompt/result handling, temporary files, and memory are included in MASVS/MASTG review and authorized runtime assessment.

**Scale/Scope**: One page; eight visible model-family entries; one selected model; one active or cached engine; one in-flight request; one displayed image; one explicit save operation. Typical model bundles range from several to more than fourteen GB, so availability is descriptor- and device-specific.

## Constitution Check

*GATE: Passed before research and re-checked after design.*

- [x] Uses Swift, SwiftUI, Swift 6 strict concurrency, and iOS 26.0+.
- [x] Uses native frameworks first. The Mirage package is the user-mandated inference dependency and is justified because Apple frameworks do not provide equivalent support for the requested sd.cpp-compatible model families.
- [x] Uses an actor-isolated inference service, a package-provided `Engine` actor, a `@MainActor` view model, `Sendable` value contracts, task ownership, and typed errors.
- [x] Performs on-device inference, local asset and memory eligibility checks, explicit unavailable states, one-engine resource bounds, model/version pinning, and physical-device evaluation.
- [x] Treats the prompt as untrusted generation content, exposes no autonomous tools, applies reviewed safety policy and negative prompts, validates output before display, and tests misuse, injection, bias, refusal, and false-positive paths.
- [x] Minimizes data, requests Photos add-only access, excludes prompt/result logging, protects local assets, defines deletion/release behavior, and includes MASVS/MASTG checks.
- [x] Includes unit, integration, UI, accessibility, safety/evaluation, degraded-state, and physical-device verification.
- [x] Reserves final project browsing, package resolution inspection, source membership, diagnostics, build, test, launch, and device verification for the Hermes-configured Xcode MCP server.

**Post-design re-check**: Passed. No unresolved clarification or constitutional exception remains. Model entries that lack an approved, complete local bundle or device budget remain visible but unavailable rather than bypassing licensing, safety, or memory gates.

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

**Structure Decision**: Keep the existing app entry and root view in place. Add one feature folder with concrete UI, state, catalog, inference, safety, and Photo Library boundaries. Do not add repositories, navigation layers, persistence, networking, or package targets. Test through small protocols around the package engine, safety analyzer, model-file access, memory query, and Photos authorization.

## Dependency and Build Configuration

1. Raise the app and test deployment targets from iOS 18.0 to iOS 26.0.
2. Add a remote Swift package named `MirageInference` at exact version `0.2.0`, and link its `Mirage` product to the app target.
3. Keep the app product and scheme named `Mirage`, but set the app Swift module name to `MirageApp` so app code can unambiguously `import Mirage`; update tests to `@testable import MirageApp`.
4. Add increased-memory-limit and extended-virtual-addressing entitlements required by the package's iPhone integration guidance.
5. Set `GGML_METAL_TENSOR_DISABLE=1` and `GGML_METAL_FUSION_DISABLE=1` in `MirageApp.init()` before any package or Metal initialization.
6. Add the Photo Library add usage description and a privacy manifest declaring no tracking or collected data; declare only actually used required-reason APIs.
7. Intermediate XcodeGen regeneration is permitted after `project.yml` changes, but it is not final evidence. Xcode MCP must inspect resolved package `0.2.0`, target membership, entitlements, build settings, and schemes before completion.

## Model Catalog and Availability

All eight families are always listed in README order:

| ID | User-facing family | Architecture | README example | Initial availability rule |
|---|---|---|---|---|
| `stable-diffusion` | Stable Diffusion 1.x / 2.x | UNet latent diffusion | `sd-v1-5.gguf` | Enable only with a complete, licensed, validated local manifest. |
| `sdxl` | SDXL / SDXL-Turbo | Two-stage UNet latent diffusion | `sd-xl-base-1.0.gguf` | Prefer validated SDXL-Turbo mobile profile; otherwise unavailable. |
| `sd3` | SD3 / SD3.5 | MMDiT | `sd3.5-medium.gguf` | Enable only with complete auxiliary assets and physical-device budget. |
| `flux1` | FLUX.1 schnell / dev | Rectified-flow DiT | `flux1-schnell-Q4_K.gguf` | Prefer schnell; license and memory approval required. |
| `chroma1-hd` | Chroma1-HD | FLUX-derived 8.9B | `chroma1-hd.gguf` | Listed but disabled on iPhone unless current hardware evidence passes; 14.5 GB bundle is conservatively treated as unsupported by default. |
| `qwen-image` | Qwen-Image | DiT 1.1B | `qwen-image-2512.gguf` | Enable only after Tongyi license and complete bundle review. |
| `ernie-image-turbo` | ERNIE-Image-Turbo | Turbo-distilled DiT | `ernie-image-turbo.gguf` | Candidate mobile profile: 1024², 8 steps, CFG 1.0, approximately 5.7–5.9 GB bundle. |
| `z-image-turbo` | Z-Image-Turbo | S3-DiT 6B | `z-image-turbo-Q3_K_M.gguf` | Candidate mobile profile: 1024², 9 steps, CFG 1.0, approximately 6.5 GB bundle. |

Each descriptor contains the exact diffusion/VAE/text-encoder filenames, generation profile, bundle byte count, activation headroom, device allowlist, license status, safety negative prompt, and evaluation version. A family is selectable only when every required field, file, legal approval, and runtime gate passes. Catalog presence never implies compatibility.

## Inference and Concurrency Design

- `@MainActor ImageGenerationViewModel` owns the prompt, selection, visible state, displayed PNG data, save feedback, and one generation task.
- `actor MirageInferenceService` owns at most one `Engine`, its descriptor ID, and progress callback lifecycle. Selecting a model does not load it; SEND resolves files, gates memory, unloads a different engine, and lazily creates the package engine.
- The service follows Quick Start: create `ModelFiles(diffusionModel:vae:textEncoder:)`, retain one `Engine`, install `Mirage.setProgressCallback`, call `engine.generate(GenerationRequest)`, and clear the global callback in `defer`.
- The package callback runs on a sampler thread. It yields `Sendable` progress values to the service stream; only the MainActor view model mutates UI.
- One request at a time is mandatory because both the app contract and package/global callback require serialization.
- Convert the returned `CGImage` to immutable PNG `Data` before handing the result to view state or Photos. Do not add unchecked sendability unless Xcode diagnostics prove it necessary and the risk is documented.
- The package does not expose native cancellation. A Swift task cancellation may discard a late result but cannot claim to stop native inference. No cancel control is shown in this feature; interruption behavior is explicit and tested.
- Preserve the previous validated image until a newer result passes structural and safety checks.

## UI and Interaction Design

Use a minimal, single-column, AI-native composition adapted to Apple HIG rather than the web-oriented custom fonts and fixed palette suggested by the generic design search:

1. A centered result card at the top, square by default, showing the previous image, empty guidance, model loading, determinate step progress, safety review, or recoverable error.
2. A labeled model menu immediately below the result. It lists all eight families, shows a checkmark for selection, disables unavailable entries, and exposes a short status below the control.
3. A labeled multiline prompt field with 1–1,000 character enforcement and a secondary character count.
4. A full-width bordered-prominent **SEND** button with at least a 44-point target. It is disabled for invalid input, unavailable selection, engine load, generation, or safety review.
5. A labeled Save button associated with the result card only after a validated image is displayed.

Use SF system text styles, semantic colors/materials, the existing app tint, SF Symbols, visible focus, and standard spacing. Do not use custom web fonts, emoji icons, hardcoded black/white/gold, heavy chrome, decorative motion, or color-only status. The entire page scrolls, respects safe areas and keyboard avoidance, constrains readable width on iPad, and adapts to accessibility Dynamic Type with `ViewThatFits` or vertical fallbacks.

Progress is both visual and semantic: announce model loading once, then denoising milestones without speaking every callback; expose current step/total and an ETA only after enough samples exist. Preserve focus and prompt text on errors. External keyboard users receive logical tab order plus Command-Return for SEND and Command-S for Save when those actions are available.

## AI, Prompt, and Security Design

**Availability and Fallback**: Every catalog item is visible. Selection requires complete local assets, approved license, compatible device, sufficient available memory, and a validated profile. Missing or incompatible entries show a concise reason. The page remains useful for reviewing/editing the prompt and choosing another model; no cloud fallback exists.

**Prompt Trust Boundaries**: The 1–1,000-character normalized user string is passed only to `GenerationRequest.prompt`. Trusted model configuration and negative prompts remain separate immutable descriptor data. No prompt content becomes environment configuration, path data, logs, hidden instructions, or a capability request.

**Tool Authorization**: The inference path exposes no tools. Photo saving is a separate explicit button, requires a validated displayed image and add-only Photos authorization, and cannot be invoked by model output.

**Data Lifecycle**: Prompt, progress, and result remain memory-only. Temporary PNG bytes are released when replaced or the session ends. Models reside in app-managed Application Support, are excluded from backup, and are not user content. Saving writes a fresh PNG with no prompt/model metadata. No network request, telemetry, or analytics is introduced.

**Threat Model and Runtime Assessment**: Test traversal/path substitution in model manifests, malformed/oversized files, low-memory loads, native errors, repeated SEND, stale callbacks, sensitive logging, prompt abuse, unsafe outputs, Photos denial/revocation, and protected-data access. Authorized Objection/Frida review confirms prompts/results are absent from UserDefaults, logs, pasteboard, and unprotected files and that only intended entitlements/resources ship.

**Evaluation Plan**: For every enabled descriptor, record package/tag, model hashes, licenses, prompt corpus version, dimensions, steps, CFG, seed policy, device/OS, load time, generation time, peak available-memory delta, thermal state, energy, structural validity, sensitive-content outcome, and demographic/safety review. Run at least 20 consecutive attempts per enabled model/device class before release. Simulator results do not satisfy inference or performance gates.

## Xcode MCP Verification Plan

**Affected Schemes**: `Mirage` app/test scheme and the new `MirageUITests` scheme or test target if introduced

**Destinations**: Current iOS 26 simulator for UI/mocked tests; iPhone 16 Pro and/or iPhone 17 Pro-class physical devices for each enabled model; representative iPad hardware for adaptive UI and any model allowed there

**Required Evidence**:

- Browse every changed source/resource through Xcode MCP and confirm app/test target membership.
- Inspect resolved package identity, exact `0.2.0` version, `Mirage` product linkage, binary artifact, app module name, deployment target, entitlements, Info.plist usage text, and privacy manifest.
- Resolve all Swift 6 concurrency and package integration diagnostics.
- Build and run unit, integration, UI, accessibility, privacy, and safety/evaluation tests through Xcode MCP.
- Launch through Xcode MCP and verify all single-page states on iPhone and iPad.
- Run real model load/generation/save flows and collect memory, thermal, energy, and timing evidence on eligible physical devices.

**Blocker Policy**: If the Hermes-configured Xcode MCP server is unavailable or fails, stop and report the blocker. Do not substitute `xcodebuild`, command-line project inspection, or XcodeGen output as final evidence.

## Complexity Tracking

No constitutional violation is requested. The sole third-party runtime dependency is user-mandated, exact-pinned, MIT-licensed, on-device, and isolated behind a small adapter. The model catalog, safety, Photos, and state boundaries each correspond directly to testable feature requirements.
