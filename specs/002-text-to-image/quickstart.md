# Quickstart: Implementing Single-Page Text-to-Image

**Feature**: `002-text-to-image`
**Authoritative plan**: [plan.md](plan.md)

This quickstart translates the upstream haplollc/Mirage Quick Start into Mirage app integration steps. It is not a substitute for the package README, model cards, constitution, or Xcode MCP verification gate.

## 1. Confirm the reviewed dependency

Use the remote package:

- URL: `https://github.com/haplollc/Mirage.git`
- Exact version: `0.2.0`
- Product/module: `Mirage`
- Release commit: `34b9bbf0b17a1aa42593d7e9d64ff55091944ec9`
- Binary checksum published by the tag: `2754f948ff12e1c546f46e0dfa59f29627d468b1c30ba1783bdaa5d8948e5472`

Add it to `project.yml` as an exact remote package and link product `Mirage` to the app target. Keep app product/scheme `Mirage`, set `PRODUCT_MODULE_NAME` to `MirageApp`, and update tests to `@testable import MirageApp` so app code can `import Mirage` without a module-name collision.

Raise app and test deployment targets to iOS 26.0 before package integration.

## 2. Configure required iPhone runtime settings

Add app entitlements:

- `com.apple.developer.kernel.increased-memory-limit`
- `com.apple.developer.kernel.extended-virtual-addressing`

In `MirageApp.init()`, before any Metal or inference object exists, set:

- `GGML_METAL_TENSOR_DISABLE=1`
- `GGML_METAL_FUSION_DISABLE=1`

These are upstream `0.2.0` iPhone integration requirements, not optional tuning.

Add:

- `NSPhotoLibraryAddUsageDescription` with an add-only Photo Library explanation;
- `PrivacyInfo.xcprivacy` with no tracking/collection and only actual required-reason APIs;
- app/test/UI-test source membership through project configuration.

## 3. Define the fixed model catalog

Create eight visible `ModelDescriptor` entries, in README order:

1. Stable Diffusion 1.x / 2.x
2. SDXL / SDXL-Turbo
3. SD3 / SD3.5
4. FLUX.1 schnell / dev
5. Chroma1-HD
6. Qwen-Image
7. ERNIE-Image-Turbo
8. Z-Image-Turbo

Do not infer auxiliary files or settings from the family name. An entry becomes selectable only when it has:

- exact diffusion, VAE, and text-encoder filenames where required;
- approved SHA-256 hashes and upstream licenses;
- a validated generation profile;
- device and memory evidence;
- a safety negative prompt/policy version;
- passing evaluation evidence.

Keep absent or unsupported entries visible but disabled with a concise reason.

## 4. Provision local model files

Resolve models under:

```text
Application Support/Models/<model-id>/
```

Exclude this directory from backup and prevent path traversal/symlink escape. Model download/import UI is not part of this feature. For development and physical-device evaluation, provision reviewed files before launch.

Known candidate bundles:

### Z-Image-Turbo

```text
z-image-turbo-Q3_K_M.gguf
Qwen3-4B-Instruct-2507-Q4_K_M.gguf
ae.safetensors
```

Candidate profile: 1024 × 1024, 9 steps, CFG 1.0. Use the reviewed Mirage/package safety-negative-prompt policy; the cited Z bundle does not define a separate safety prompt file.

### ERNIE-Image-Turbo

```text
ernie-image-turbo-Q3_K_M.gguf
Ministral-3-3B-Instruct-2512-Q4_K_M.gguf
ae.safetensors                # ERNIE-specific VAE; not Flux VAE
safety_negative_prompt.txt
```

Candidate profile: 1024 × 1024, 8 steps, CFG 1.0.

### Chroma1-HD

```text
Chroma1-HD-Q4_K_S.gguf
t5xxl_fp16.safetensors
ae.safetensors
```

Candidate profile: 1024 × 1024, 28 steps, CFG 4.0. Keep unavailable on iPhone until fresh physical-device evidence satisfies the conservative memory gate.

## 5. Implement the upstream Quick Start behind an actor

Create `actor MirageInferenceService` and `import Mirage` there. For the selected descriptor:

1. Resolve and verify local files.
2. Check available memory before creating the engine.
3. Build package `ModelFiles` from diffusion, optional VAE, and optional text-encoder URLs.
4. Reuse an existing `Engine` for the same descriptor; otherwise unload the old engine and create one new `Engine`.
5. Install `Mirage.setProgressCallback` and bridge callback values from the sampler thread into `Sendable` progress events.
6. Call `engine.generate(.init(prompt:negativePrompt:width:height:steps:cfgScale:seed:))` using the descriptor profile.
7. Clear the global callback in `defer`.
8. Convert the returned `CGImage` to immutable PNG `Data`.

Do not create the engine inside the SwiftUI view, create an engine per SEND, keep multiple engines, or mutate UI state from the progress callback.

Package `0.2.0` has no reliable native cancellation. Keep controls disabled until generation returns; do not show a Cancel button or claim that cancelling a Swift task stopped native work.

## 6. Validate prompt and output locally

Before inference:

- trim and validate 1–1,000 visible characters;
- run the versioned prompt safety policy;
- keep trusted negative prompt/configuration separate from user text;
- never log or persist the prompt.

After inference and before display:

- verify PNG encoding and expected dimensions;
- run on-device Sensitive Content Analysis;
- refuse blocked/unreviewed output without displaying or saving it;
- preserve the previous allowed image when a new result fails.

No remote moderation or inference is permitted.

## 7. Build the one-page SwiftUI flow

Use [contracts/ui-contract.md](contracts/ui-contract.md):

- result card first;
- model menu listing all eight families;
- multiline labeled prompt and character count;
- full-width **SEND** button;
- determinate step progress where available;
- Save button only for a validated image.

Use system text styles, semantic colors, SF Symbols, 44-point targets, scrolling, safe areas, keyboard avoidance, VoiceOver labels/values, Dynamic Type fallbacks, and reduced-motion behavior. The generated image is not decorative; label it as AI-generated.

## 8. Save with least privilege

On explicit Save:

1. Request Photo Library add-only authorization if needed.
2. Save the current validated PNG exactly once.
3. Add no prompt, model, or private generation metadata.
4. Confirm success accessibly.
5. On denied/restricted/failure, preserve the image and show recovery guidance.

Do not request Photo Library read access or enumerate user assets.

## 9. Test before final verification

Add deterministic tests for:

- ordered eight-family catalog and disabled reasons;
- model path/hash/license/device/memory gates;
- prompt validation and safety fixtures;
- one-request/one-engine state transitions;
- progress callback bridging and stale callback rejection;
- failure/refusal preserving a previous image;
- PNG structural/safety validation;
- Photos add-only authorization and save outcomes;
- VoiceOver semantics, Dynamic Type, keyboard actions, and all page states.

Run real model evaluation on eligible physical iPhone/iPad hardware for every enabled descriptor. Record package/model hashes, model profile, device, OS, load/generation timing, memory, energy, thermal behavior, quality, safety, bias, and 20-attempt stability evidence.

## 10. Complete only through Xcode MCP

Use the Xcode MCP server configured directly in Hermes Agent to:

- inspect package resolution at exact `0.2.0`;
- browse changed files and target membership;
- inspect deployment target, module name, entitlements, Info.plist, privacy manifest, and schemes;
- resolve Swift 6 diagnostics;
- build/test app, unit, and UI-test targets;
- launch and verify the page on iPhone and iPad;
- verify physical-device model generation and Photos save.

If Xcode MCP is unavailable or fails, report a verification blocker. Do not use command-line Xcode tools or generated project text as final evidence.

## Primary sources

- https://github.com/haplollc/Mirage/blob/0.2.0/README.md
- https://github.com/haplollc/Mirage/releases/tag/0.2.0
- https://github.com/haplollc/Mirage/blob/0.2.0/Package.swift
- https://github.com/haplollc/Mirage/blob/0.2.0/Sources/Mirage/Mirage.swift
- https://github.com/haplollc/Mirage/blob/0.2.0/Examples/MirageExampleApp.swift
- https://huggingface.co/jc-builds/Z-Image-Turbo-iOS
- https://huggingface.co/jc-builds/ERNIE-Image-Turbo-iOS
- https://huggingface.co/jc-builds/Chroma1-HD-iOS
