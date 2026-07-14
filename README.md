# Mirage

Mirage is a native SwiftUI app for **iOS 26.0+** that runs text-to-image inference on-device. It presents the eight model families documented by [`haplollc/Mirage`](https://github.com/haplollc/Mirage), validates local model assets, generates one image at a time, reviews output on-device, and saves only after an explicit add-only Photos action.

## Current status

The feature implementation and test sources exist, but the app is **not release-verified**:

- Mirage package: exact version `0.2.0`.
- Catalog: eight fixed families, closed by default.
- ERNIE candidate: exact files, sizes, and SHA-256 values recorded; evaluation remains disabled.
- Model weights: not bundled or downloaded by the app.
- Xcode build/tests/launch: blocked because the Hermes-configured Xcode MCP server is not exposed in the current session.
- Physical-device quality, safety, memory, energy, thermal, and accessibility evaluation: not run.

No catalog model becomes selectable until all of its file, license, memory, safety, and evaluation gates pass.

## Requirements

- macOS with an iOS 26-capable Xcode release.
- iOS/iPadOS 26.0+ destination.
- Hermes Agent with its Xcode MCP server configured and exposed.
- An eligible physical device for real inference; candidate bundles are multi-gigabyte and may require 8 GB or more device memory.
- No API key, cloud account, analytics service, or remote inference endpoint.

## Detailed setup

### 1. Clone and inspect

```sh
git clone <repository-url> Mirage
cd Mirage
```

Read these release gates before provisioning a model:

- `.specify/memory/constitution.md`
- `specs/002-text-to-image/model-provisioning.md`
- `specs/002-text-to-image/privacy-assessment.md`
- `specs/002-text-to-image/implementation-evidence.md`

### 2. Generate intermediate project metadata

`project.yml` is the reproducible project source. It declares iOS 26.0, Swift 6 strict concurrency, bundle identifier `fr.dubertrand.Mirage`, the `MirageApp` Swift module, entitlements, privacy resources, unit/UI targets, and the exact package requirement.

If project metadata must be refreshed during development:

```sh
xcodegen generate
```

This is only an intermediate generation step. It is **not** final build or verification evidence.

### 3. Resolve the Swift package through Xcode MCP

Open the generated project using the Hermes-configured Xcode MCP server and verify:

1. `https://github.com/haplollc/Mirage.git` resolves exactly to `0.2.0`.
2. Product `Mirage` is linked only to the app target.
3. The customer-facing product and scheme remain `Mirage`; the Swift module is `MirageApp`.
4. Deployment is iOS 26.0 and Swift 6 strict concurrency is complete.
5. `PrivacyInfo.xcprivacy`, `Mirage.entitlements`, Photos purpose text, app sources, test resources, and both test targets have correct membership.

Do not substitute `xcodebuild`, command-line package resolution, or mcporter for this final Xcode MCP inspection.

### 4. Provision a reviewed development model

The app never downloads weights. The only candidate with recorded artifact metadata is ERNIE-Image-Turbo. Follow `specs/002-text-to-image/model-provisioning.md`; independently verify all three SHA-256 values and byte counts.

Place files inside the installed app container at:

```text
Library/Application Support/Mirage/Models/ernieImageTurbo/
├── ernie-image-turbo-Q3_K_M.gguf
├── ae.safetensors
└── Ministral-3-3B-Instruct-2512-Q4_K_M.gguf
```

Never place weights in the repository. `.gitignore` excludes `Models/`, GGUF, safetensors, Core ML, and related generated formats.

The ERNIE descriptor still has `evaluationApproved: false`. This is intentional: provisioning files alone must not enable an unevaluated model. Complete the physical-device evaluation and supply-chain review before changing that gate.

### 5. Build, test, and launch

Using Xcode MCP only:

1. Resolve diagnostics.
2. Build the `Mirage` scheme for an iOS 26 simulator.
3. Run `MirageTests` and `MirageUITests`, recording totals and justified environment-gated skips.
4. Launch representative iPhone and iPad destinations and inspect every empty, unavailable, generating, safety, result, refusal, error, and Photos state.
5. Repeat real inference, Photos, accessibility, memory, energy, and thermal validation on eligible physical devices.

If Xcode MCP is unavailable, stop and report the build/test/launch gate as blocked rather than claiming success.

## Privacy and security

- Prompts and generated pixels stay in memory unless the user explicitly saves.
- There is no generation history, cloud transport, telemetry, account, UserDefaults, pasteboard, or prompt logging.
- Model files are sandbox-contained, backup-excluded, protected, size-checked, and SHA-256 verified.
- Prompt policy and output analysis run locally and fail closed.
- Generated PNGs are structurally validated and must contain no GPS, EXIF, or TIFF metadata before saving.
- Photos permission is `.addOnly`; read access is never requested.
- The privacy manifest declares no tracking or collected data.

See `Documentation/SecurityAndPrivacy.md` and `specs/002-text-to-image/security-assessment.md` for boundaries and remaining runtime checks.

## Model catalog

1. Stable Diffusion 1.x / 2.x
2. SDXL / SDXL-Turbo
3. SD3 / SD3.5
4. FLUX.1 schnell / dev
5. Chroma1-HD
6. Qwen-Image
7. ERNIE-Image-Turbo
8. Z-Image-Turbo

Unavailable entries remain visible and explain their state; users cannot add arbitrary models.

## Repository structure

- `Mirage/Features/ImageGeneration/` — domain, resolver, inference, safety, Photos, state, and SwiftUI feature.
- `MirageTests/` — unit, security, performance, fake integration, and AI evaluation sources.
- `MirageUITests/` — accessible end-to-end state journeys.
- `Documentation/` — security, accessibility, and physical-device runbooks.
- `specs/002-text-to-image/` — specification, plan, contracts, tasks, provisioning, and evidence.
- `project.yml` — XcodeGen project source.

## Verification policy

All work is governed by `.specify/memory/constitution.md`. Final project browsing, package inspection, diagnostics, building, testing, launch, and physical-device evidence must come from the Hermes-configured Xcode MCP server. Static parser or stub typechecks are useful development checks but never replace that gate.