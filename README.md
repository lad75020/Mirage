# Mirage

Mirage is a native SwiftUI app for **iOS 26.0+** that downloads supported public Hugging Face text-to-image model snapshots, runs inference on device through `haplollc/Mirage` `0.2.0`, shows one generated image above the prompt, and saves only after an explicit add-only Photos action.

## Current status

- Featured repositories: `jc-builds/Z-Image-Turbo-iOS`, `jc-builds/ERNIE-Image-Turbo-iOS`, and `jc-builds/Chroma1-HD-iOS`.
- Custom sources: public unauthenticated Hugging Face `owner/repository` or `https://huggingface.co/owner/repository` references only.
- Storage: promoted downloads are visible in Files at `Documents/Mirage Models`.
- Inference: native model load occurs only for an explicit selected SEND attempt, then unloads after every attempt.
- Runtime state: the exact reviewed `jc-builds/Z-Image-Turbo-iOS` revision and hash set is enabled in all builds. ERNIE, Chroma, and custom repositories remain fail-closed. Physical-device soak, Instruments, and legal/release evidence are still pending.

## Requirements

- macOS with an iOS 26-capable Xcode release.
- iOS/iPadOS 26.0+ simulator for deterministic UI/unit work.
- Eligible physical iPhone/iPad hardware for real multi-GB download, load, generation, memory, energy, thermal, Files, and Photos evidence.
- Hermes Agent with its Xcode MCP server configured and exposed for final verification.
- No API key, Hugging Face token, account, analytics service, or remote inference endpoint.

## Installation and deployment

### 1. Clone and inspect

```sh
git clone <repository-url> Mirage
cd Mirage
```

Review:

- `specs/002-text-to-image/plan.md`
- `specs/002-text-to-image/model-provisioning.md`
- `specs/002-text-to-image/privacy-assessment.md`
- `specs/002-text-to-image/security-assessment.md`
- `specs/002-text-to-image/implementation-evidence.md`

### 2. Generate project metadata when needed

`project.yml` is the reproducible Xcode project source. It declares iOS 26.0, Swift 6 strict concurrency, bundle identifier `fr.dubertrand.Mirage`, app module `MirageApp`, package `https://github.com/haplollc/Mirage.git` exact `0.2.0`, entitlements, privacy resources, Files sharing, unit tests, and UI tests.

```sh
xcodegen generate
```

This is intermediate metadata generation only. It is not final build, test, package, or target-membership evidence.

### 3. Verify package and app configuration through XcodeMCP

Use the Hermes-configured Xcode MCP server to inspect the open project:

1. Package URL is `https://github.com/haplollc/Mirage.git`.
2. Resolved package version is exactly `0.2.0`.
3. App product and scheme remain `Mirage`; Swift module is `MirageApp`.
4. App and test deployment target is iOS 26.0.
5. Swift strict concurrency is complete.
6. `Mirage.entitlements` contains only the two memory entitlements.
7. `PrivacyInfo.xcprivacy` declares no tracking and no collected data.
8. `NSPhotoLibraryAddUsageDescription` exists.
9. `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` are enabled.
10. App, tests, UI tests, resources, and privacy files have expected target membership.

Do not use `xcodebuild` as constitutional final evidence.

### 4. Build and run deterministic tests through XcodeMCP

Required before claiming implementation verification:

1. Build the `Mirage` scheme.
2. Run focused unit/security/download/model tests.
3. Run UI tests and require a concrete XcodeMCP pass/fail result.
4. Record totals and blockers in `specs/002-text-to-image/implementation-evidence.md`.

Current verification: XcodeMCP BuildProject succeeded; the Z-Image compatibility and manifest tests both passed; Issue Navigator showed 0 errors. The CLI unit suite passed 68 tests with 1 approved-bundle integration skip and 0 failures, and the arm64 Release simulator build succeeded. XcodeMCP UI tests previously returned `No result`, so UI verification remains blocked.

### 5. Download a featured model in the app

From the one-page UI:

1. Choose one featured repository:
   - `jc-builds/Z-Image-Turbo-iOS`
   - `jc-builds/ERNIE-Image-Turbo-iOS`
   - `jc-builds/Chroma1-HD-iOS`
2. Press Download.
3. Confirm the app shows the canonical repository, immutable commit SHA, license, and total size before transfer.
4. Confirm the transfer shows byte progress.
5. Cancel once during a test run and verify the staging data is cleaned up and the model is not selectable.
6. Retry and let the download finish.
7. Confirm validation completes before the snapshot is marked downloaded.

Download policy:

- Metadata cap: 2 MiB.
- Files per snapshot: 24.
- Size per file: 16 GiB.
- Size per snapshot: 24 GiB.
- Allowed file types: `.gguf` and `.safetensors`.
- Required integrity: LFS SHA-256 for every file.
- Allowed hosts: `huggingface.co`, `cdn-lfs.huggingface.co`, `cdn-lfs-us-1.huggingface.co`, `cdn-lfs-eu-1.huggingface.co`, `cdn-lfs.hf.co`, and `cas-bridge.xethub.hf.co`.

### 6. Verify model files in Files

After a successful download, inspect the app container through Files:

```text
Files > On My iPhone > Mirage > Mirage Models
```

Each model uses a stable safe folder such as:

```text
jc-builds--z-image-turbo-ios-<digest>
```

Verify:

1. The folder contains only expected `.gguf`/`.safetensors` files and `.mirage-snapshot.json`.
2. No prompt, generated image, credential, token, log, fixture, or Photo data appears in the folder.
3. `.mirage-snapshot.json` records owner, repository, immutable commit SHA, folder name, license, file names, sizes, and hashes.
4. File sizes match the manifest in `MirageTests/AIEvaluation/ModelEvaluationManifest.json`.
5. SHA-256 hashes match the manifest.
6. Editing, deleting, adding, or renaming a file in Files causes app refresh to mark the snapshot incompatible instead of loading it.

### 7. Verify featured artifact metadata

Expected featured revisions:

| Repository | Commit | License | Profile | Evaluation |
|---|---|---|---|---|
| `jc-builds/Z-Image-Turbo-iOS` | `97ae389b962ee927d83c1911be743c8d82c11674` | Apache-2.0 | 1024 x 1024, 9 steps, CFG 1.0 | true |
| `jc-builds/ERNIE-Image-Turbo-iOS` | `f23d470af1a57a64aa034d0770e74f99aac6135f` | Apache-2.0 | 1024 x 1024, 8 steps, CFG 1.0 | false |
| `jc-builds/Chroma1-HD-iOS` | `722a672dca0d2ec5ff39dea561ae0df62bf49995` | Apache-2.0 | 1024 x 1024, 28 steps, CFG 4.0 | false |

Only the exact reviewed Z-Image snapshot is compatible and selectable after download. ERNIE, Chroma, and custom snapshots remain unavailable. Runtime enablement does not replace the pending physical-device and legal release evidence.

### 8. Verify custom repository handling

Use only a public Hugging Face model reference:

```text
owner/repository
https://huggingface.co/owner/repository
```

Expected behavior:

1. Malformed, non-Hugging-Face, credentialed, query/fragment, private, and gated sources are rejected.
2. Public custom repositories may download after explicit confirmation.
3. Custom snapshots remain unselectable by default as `unknownCustomRepository`.
4. No token, password, or private model credential is requested or stored.

### 9. Verify inference lifecycle on physical device

For the enabled Z-Image descriptor:

1. Select a compatible downloaded model explicitly.
2. Confirm listing and downloading did not load native weights.
3. Press **SEND** with a valid 1...1000 character prompt.
4. Confirm one load begins for that selected attempt.
5. Confirm one generation request runs.
6. Confirm the result is reviewed before display.
7. Confirm the model unloads after success, failure, refused output, interruption, and invalid output.
8. Confirm a second attempt starts only after the previous unload completes.
9. Record load time, generation time, post-unload memory, energy, thermal state, device, OS, commit SHA, file hashes, and Photos save result.
10. Repeat at least 20 cycles per enabled featured model/device class.

A Z-Image download was reported successful by the user, but no independently captured physical-device generation, 20-cycle evaluation, Instruments trace, or legal/release approval exists in the current evidence.

## Privacy and security

- Prompts and generated pixels remain on device.
- Model metadata/download requests send only repository/revision/protocol data needed for the explicit download.
- No remote inference, telemetry, accounts, tracking, analytics, or prompt logging.
- No prompts, generated images, credentials, or private repository data in URLs, model folders, logs, fixtures, or evidence.
- Download staging is cleaned on cancellation/failure.
- Promoted snapshots are integrity-checked and Files-visible.
- Custom snapshots fail closed unless compatibility is proven.
- Photos permission is add-only and requested only from Save.

## Repository structure

- `Mirage/Features/ImageGeneration/` - model download, store, resolver, inference, safety, Photos, state, and SwiftUI feature.
- `MirageTests/` - unit, security, performance, fake integration, and AI evaluation tests.
- `MirageUITests/` - UI journey tests.
- `Documentation/` - security, accessibility, and physical-device runbooks.
- `specs/002-text-to-image/` - specification, plan, contracts, tasks, provisioning, evidence, and traceability.
- `project.yml` - XcodeGen project source.

## Verification policy

Final project browsing, package inspection, diagnostics, building, testing, launch, UI, accessibility, and physical-device evidence must come from the Hermes-configured Xcode MCP server. Static parser checks, JSON checks, text searches, and CLI fallbacks are useful development checks but do not replace that gate.
