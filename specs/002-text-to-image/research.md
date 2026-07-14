# Research: Single-Page Text-to-Image Generation

**Feature**: `002-text-to-image`
**Date**: 2026-07-14

## 1. Swift Package Release and Provenance

**Decision**: Depend on `https://github.com/haplollc/Mirage.git` at exact version `0.2.0`.

**Rationale**:

- GitHub's latest-release endpoint identifies `0.2.0` as the current non-draft, non-prerelease release, published 2026-05-19.
- The tag resolves to commit `34b9bbf0b17a1aa42593d7e9d64ff55091944ec9`.
- Release `0.2.0` is the first release documented as end-to-end production-ready on iPhone and adds the progress callback required for multi-minute UI feedback.
- Its `Package.swift` downloads `sdcpp.xcframework.zip` from the same release with checksum `2754f948ff12e1c546f46e0dfa59f29627d468b1c30ba1783bdaa5d8948e5472`.
- Package and embedded stable-diffusion.cpp/ggml code are MIT-licensed. Model weights retain separate upstream licenses and require per-entry review.

**Alternatives considered**:

- `from: "0.2.0"`: permits future patch resolution but makes native-binary upgrades less explicit. Rejected in favor of exact reproducibility.
- README install example `from: "0.1.0"`: stale relative to the latest release and lacks the iPhone fixes/progress API. Rejected.
- A local package checkout or direct stable-diffusion.cpp integration: increases build complexity and bypasses the requested package. Rejected.

## 2. Module Name Collision

**Decision**: Keep the app product and scheme named `Mirage`, but change its Swift module name to `MirageApp`; import the package product/module as `Mirage`.

**Rationale**: The app target currently produces a Swift module named `Mirage`, exactly matching the package module. A distinct `PRODUCT_MODULE_NAME` avoids ambiguous self-import while preserving the customer-facing app name and existing scheme. Tests move from `@testable import Mirage` to `@testable import MirageApp`.

**Alternatives considered**:

- Rename the application or scheme: unnecessary user-visible churn.
- Fork or rename the package module: violates use of the latest upstream package and complicates upgrades.
- SPM module aliases: less transparent in the generated Xcode project and unnecessary for one collision.

## 3. Quick Start Integration Contract

**Decision**: Adapt the package Quick Start exactly at the service boundary:

1. Resolve three optional/required local file URLs into `ModelFiles(diffusionModel:vae:textEncoder:)`.
2. Create one `Engine` per active model and retain it; model loading is multi-GB I/O/GPU setup.
3. Install `Mirage.setProgressCallback` before generation, bridge sampler-thread callbacks to a `Sendable` progress stream, and clear the global callback in `defer`.
4. Call `Engine.generate(GenerationRequest)` with descriptor-owned width, height, steps, CFG scale, optional negative prompt, and random seed.
5. Convert the returned `CGImage` to PNG data, validate it, apply output safety analysis, then publish it to the MainActor UI.

**Rationale**: This matches the public API at tag `0.2.0`: one actor `Engine`, one serial `generate(_:)` method, a global progress callback, `CGImage` output, and `CGImage.pngData()`.

**Alternatives considered**:

- Constructing an engine per request: rejected because package documentation identifies model load as expensive and multi-GB.
- Keeping one engine for every catalog entry: rejected because simultaneous multi-GB residency is unsafe on iOS.
- Concurrent generation: rejected because the underlying native context and global callback require serialization.

## 4. Cancellation Semantics

**Decision**: Do not expose a Cancel button in this feature. Disable conflicting controls while native inference runs. If the owning Swift task is invalidated, ignore a late result but continue to represent the engine as busy until the native call returns.

**Rationale**: Package `0.2.0` exposes no cancellation API; `Engine.generate(_:)` wraps a synchronous native generation call. Claiming cancellation would be misleading and could permit a second request while native work is still active.

**Alternatives considered**:

- Swift task cancellation alone: cannot stop the native call.
- Destroying the engine from another task: unsafe and unsupported by the actor/native lifetime contract.

## 5. Fixed Supported-Model Catalog

**Decision**: List every family in the README Supported model families section, in source order:

1. Stable Diffusion 1.x / 2.x
2. SDXL / SDXL-Turbo
3. SD3 / SD3.5
4. FLUX.1 schnell / dev
5. Chroma1-HD
6. Qwen-Image
7. ERNIE-Image-Turbo
8. Z-Image-Turbo

Every entry is visible. An entry is enabled only when its complete file manifest, generation profile, license approval, device allowlist, memory budget, safety policy, and evaluation version are present and all runtime gates pass.

**Rationale**: The user explicitly requested this list. Visibility and availability are separate, matching the feature specification's unavailable-model behavior and preventing unsupported assets from crashing the app.

**Known mobile bundle profiles from linked upstream documentation**:

| Family | Files/profile evidence | Conservative decision |
|---|---|---|
| Z-Image-Turbo | `z-image-turbo-Q3_K_M.gguf`, `Qwen3-4B-Instruct-2507-Q4_K_M.gguf`, `ae.safetensors`; 1024², 9 steps, CFG 1.0; about 6.5 GB | Candidate for iPhone 16/17 Pro after license, memory, safety, and physical-device validation. |
| ERNIE-Image-Turbo | `ernie-image-turbo-Q3_K_M.gguf`, `Ministral-3-3B-Instruct-2512-Q4_K_M.gguf`, ERNIE-specific `ae.safetensors`; 1024², 8 steps, CFG 1.0; about 5.7–5.9 GB | Candidate for iPhone 16/17 Pro after validation. Do not substitute Flux VAE. |
| Chroma1-HD | `Chroma1-HD-Q4_K_S.gguf`, `t5xxl_fp16.safetensors`, Flux `ae.safetensors`; 1024², 28 steps, CFG 4.0; about 14.5 GB | Visible but unavailable on iPhone by default. Source documents conflict on iPhone feasibility; require fresh device evidence rather than optimistic enablement. |

The remaining families use descriptor manifests created from reviewed model cards and sd.cpp-compatible file sets. They remain unavailable until those artifacts exist; no filename or configuration is invented from the family label alone.

**Alternatives considered**:

- Show only three mirrored bundles: contradicts the requested list.
- Mark every family selectable based only on package support: unsafe because support does not provide files, licenses, memory capacity, or a validated generation profile.
- Download models from the picker: explicitly out of scope.

## 6. Model File Provisioning

**Decision**: Resolve models from `Application Support/Models/<descriptor-id>/`; exclude the directory from backup. Provisioning/distribution is outside this UI feature. Development and evaluation use preinstalled local bundles. Release enablement requires a separately approved asset-distribution decision.

**Rationale**: The feature forbids model download/import UI and remote inference. Multi-GB assets are unsuitable for ad hoc bundling without a deliberate App Store/background-assets strategy. Separating inference from distribution keeps the feature honest: absent assets produce an unavailable state.

**Alternatives considered**:

- Documents directory as shown in the minimal example: user-visible and backed up by default; rejected for managed model assets.
- Bundle all eight families: size and license constraints make this infeasible.
- Fetch directly from Hugging Face on first use: adds networking, consent, integrity, resume, storage, and licensing scope not specified.

## 7. iPhone Memory and Native Setup

**Decision**:

- Add `com.apple.developer.kernel.increased-memory-limit` and `com.apple.developer.kernel.extended-virtual-addressing`.
- Set `GGML_METAL_TENSOR_DISABLE=1` and `GGML_METAL_FUSION_DISABLE=1` before any Metal/package probe.
- Keep one engine resident.
- Gate model load using descriptor total bytes, activation headroom, and `os_proc_available_memory()`; reject before load when the approved budget is not available.
- Validate all enabled families on physical devices outside the debugger for performance evidence.

**Rationale**: These are explicit release `0.2.0` iPhone requirements. Package documentation reports roughly 30 seconds for SDXL-Turbo 512² and three to five minutes for turbo 1024² generations on recent Pro iPhones, excluding first load. Simulator is not a benchmark environment.

**Alternatives considered**:

- Attempt load and catch failure: jetsam can terminate the process before Swift recovery.
- Multiple cached engines: violates mobile memory budgets.

## 8. Safety and Output Validation

**Decision**: Use layered, local controls:

1. Validate and normalize the 1–1,000-character prompt; keep it separate from trusted configuration.
2. Apply a reviewed, versioned prompt safety policy with a recoverable refusal.
3. Pass a descriptor-owned SFW negative prompt where the bundle provides one.
4. Validate output dimensions, channels, and PNG encoding.
5. Run Apple's on-device Sensitive Content Analysis before display/save; block sensitive results with a nonjudgmental explanation.
6. Evaluate violence, hate, illegal activity, impersonation, private-data reproduction, stereotypes, demographic bias, jailbreak/injection attempts, and false positives using versioned fixtures. Categories not covered by the platform analyzer remain release-evaluation gates.

**Rationale**: The Mirage package is an inference engine, not a complete moderation system. ERNIE and Z model bundles recommend negative prompts and explicitly warn that negative prompts are not binary enforcement. The app must validate before showing or saving output.

**Alternatives considered**:

- Trust model output: violates the constitution and bundle warnings.
- Remote moderation: violates on-device privacy.
- Keyword-only filtering: insufficient as the sole control; retained only as one transparent, tested layer.

## 9. Swift Concurrency Architecture

**Decision**: `@MainActor @Observable ImageGenerationViewModel` coordinates UI state. `actor MirageInferenceService` owns the package engine and callback lifecycle. Cross-actor values are immutable `Sendable` descriptors, requests, progress, typed failures, and PNG `Data`.

**Rationale**: This matches Swift 6 strict concurrency, package actor isolation, and UI ownership. It avoids mutating view state from the package's sampler thread and avoids exposing native handles to the UI.

**Alternatives considered**:

- Store `Engine` directly in a SwiftUI view: difficult lifecycle/error/test management and encourages MainActor blocking.
- Detached tasks and unchecked sendability: unnecessary and constitutionally disallowed without justification.

## 10. UI/UX and Accessibility

**Decision**: Use a minimal single-column AI-native page with a result card, model menu, multiline prompt, full-width SEND action, and result-associated Save action. Use native SF typography, semantic colors/materials, SF Symbols, 44-point targets, safe areas, scrolling, keyboard avoidance, visible focus, and adaptive width.

**Rationale**: The UI-UX design search recommended minimal single-column structure, immediate progress, and minimal chrome. Its custom web fonts and fixed black/gold palette conflict with native iOS, Dynamic Type, semantic colors, and the project constitution, so the plan retains the structure but uses HIG-compliant styling.

**Accessibility decisions**:

- All controls have labels, values, hints, and correct selected/disabled traits.
- Progress exposes step/total and throttled announcements rather than speaking every callback.
- The image is labeled "AI-generated image" rather than decorative.
- Dynamic Type uses system styles and vertical fallbacks; no essential text truncates.
- Status never relies on color, animation, or position alone.
- Test VoiceOver order, Accessibility XXXL, Reduce Motion, Increase Contrast, Reduce Transparency, dark/light modes, external keyboard, rotation, and iPad multitasking widths.

## 11. Photo Library Saving and Privacy

**Decision**: Request Photos add-only authorization on the first Save action, encode a fresh PNG from the validated result, and create one asset without prompt/model metadata. Abstract authorization and saving for deterministic tests.

**Rationale**: The user requires saving but not reading/browsing the library. Add-only is least privilege. Re-encoding without metadata prevents prompt/model leakage.

**Alternatives considered**:

- Request full Photo Library access: unnecessary.
- Request permission at launch: lacks user context and violates progressive permission guidance.
- Persist images locally before save: unnecessary retention.

## 12. Verification Authority

**Decision**: Use the Hermes-configured Xcode MCP server for final package resolution, project browsing, source membership, diagnostics, builds, tests, launch, accessibility inspection, and physical-device inference evidence. If unavailable or failing, report a blocker and do not use command-line Xcode tools as final proof.

**Rationale**: This is non-negotiable under the Mirage constitution.

## Sources

- haplollc/Mirage README, tag 0.2.0: https://github.com/haplollc/Mirage/blob/0.2.0/README.md
- haplollc/Mirage latest release: https://github.com/haplollc/Mirage/releases/tag/0.2.0
- haplollc/Mirage Package.swift, tag 0.2.0: https://github.com/haplollc/Mirage/blob/0.2.0/Package.swift
- haplollc/Mirage public Swift API, tag 0.2.0: https://github.com/haplollc/Mirage/blob/0.2.0/Sources/Mirage/Mirage.swift
- haplollc/Mirage example app, tag 0.2.0: https://github.com/haplollc/Mirage/blob/0.2.0/Examples/MirageExampleApp.swift
- Z-Image-Turbo iOS bundle: https://huggingface.co/jc-builds/Z-Image-Turbo-iOS
- ERNIE-Image-Turbo iOS bundle: https://huggingface.co/jc-builds/ERNIE-Image-Turbo-iOS
- Chroma1-HD iOS bundle: https://huggingface.co/jc-builds/Chroma1-HD-iOS
- Apple Sensitive Content Analysis: https://developer.apple.com/documentation/sensitivecontentanalysis
- Apple Photos authorization: https://developer.apple.com/documentation/photos/phphotolibrary/requestauthorization(for:handler:)
- XcodeGen project specification: https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md
