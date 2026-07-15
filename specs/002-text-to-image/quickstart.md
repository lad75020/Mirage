# Quickstart: Implementing Single-Page Text-to-Image

**Feature**: `002-text-to-image`
**Authoritative plan**: [plan.md](plan.md)

This guide is for developers working in the current checkout. It documents the implemented public Hugging Face download lifecycle and the verification gates that still control release.

## 1. Confirm the reviewed dependency

Use:

- Package URL: `https://github.com/haplollc/Mirage.git`
- Exact version: `0.2.0`
- Product/module: `Mirage`
- Release commit: `34b9bbf0b17a1aa42593d7e9d64ff55091944ec9`
- Binary checksum: `2754f948ff12e1c546f46e0dfa59f29627d468b1c30ba1783bdaa5d8948e5472`

Keep the app product and scheme named `Mirage`, set app module name to `MirageApp`, and import the package as `Mirage`.

## 2. Configure app capabilities

`project.yml` must declare:

- iOS 26.0 app, unit test, and UI test targets;
- Swift 6 strict concurrency;
- `NSPhotoLibraryAddUsageDescription`;
- `UIFileSharingEnabled = YES`;
- `LSSupportsOpeningDocumentsInPlace = YES`;
- memory entitlements `com.apple.developer.kernel.increased-memory-limit` and `com.apple.developer.kernel.extended-virtual-addressing`;
- `PrivacyInfo.xcprivacy` with no tracking and no collected data.

`MirageApp.init()` must set `GGML_METAL_TENSOR_DISABLE=1` and `GGML_METAL_FUSION_DISABLE=1` before any package or Metal initialization.

## 3. Use the featured source list

The featured list is exact and ordered:

1. `jc-builds/Z-Image-Turbo-iOS`
2. `jc-builds/ERNIE-Image-Turbo-iOS`
3. `jc-builds/Chroma1-HD-iOS`

Custom input accepts only public unauthenticated Hugging Face model references:

```text
owner/repository
https://huggingface.co/owner/repository
```

Do not add token entry, private/gated repository support, non-Hugging-Face downloads, remote inference, or repository code execution.

## 4. Resolve metadata before download

For each repository:

1. Fetch `https://huggingface.co/api/models/<owner>/<repository>?blobs=true`.
2. Enforce the 2 MiB metadata cap.
3. Require public, ungated metadata.
4. Require a 40-character immutable commit SHA.
5. Require a nonempty license.
6. Select only safe relative `.gguf` and `.safetensors` files.
7. Require positive size and 64-character LFS SHA-256 for each selected file.
8. Enforce at most 24 files, 16 GiB per file, and 24 GiB per snapshot.
9. Show repository, immutable commit, size, and license to the user before transfer.

Official download and redirect hosts are limited to:

```text
huggingface.co
cdn-lfs.huggingface.co
cdn-lfs-us-1.huggingface.co
cdn-lfs-eu-1.huggingface.co
cdn-lfs.hf.co
cas-bridge.xethub.hf.co
```

## 5. Download and promote safely

Use `HuggingFaceModelDownloader` and `ModelStore`:

1. Create staging outside `Documents/Mirage Models`.
2. Stream each file to staging.
3. Report byte progress from file callbacks.
4. Verify final URL host, HTTP status, byte count, and SHA-256 for every file.
5. Remove staging on cancellation or failure.
6. Validate staged paths, file count, case collisions, symlinks, executable flags, archive extensions, unexpected files, hidden files, sizes, and hashes.
7. Promote atomically into:

```text
Documents/Mirage Models/<safe-repository-folder>/
```

8. Write `.mirage-snapshot.json` with source, commit, folder, license, files, sizes, and hashes.
9. Refresh snapshots after foregrounding or before selection so Files edits/removals invalidate compatibility.

## 6. Keep compatibility separate from download completion

Featured repositories bind to exact revisions and file hashes recorded in `MirageTests/AIEvaluation/ModelEvaluationManifest.json`. The exact reviewed Z-Image snapshot is runtime-enabled; ERNIE and Chroma remain fail-closed. Physical-device release evidence is still required for Z-Image.

Custom snapshots default to `unknownCustomRepository`. They may remain visible in Files but must be unselectable until local validation confirms supported files, architecture/profile, OS, device, memory, safety policy, and runtime behavior.

## 7. Generate with deterministic unload

`MirageInferenceService` is the only native inference boundary:

1. Accept SEND only for an explicit compatible logical selection and a valid prompt.
2. Resolve model files under `Documents/Mirage Models`.
3. Create package `ModelFiles(diffusionModel:vae:textEncoder:)`.
4. Load one native `Engine` for the attempt.
5. Install `Mirage.setProgressCallback`.
6. Call `engine.generate(...)` exactly once.
7. Clear the callback.
8. Convert output to immutable PNG data.
9. Await unload after success, load failure, native failure, invalid output, cancellation, or late-result discard.

Do not load on listing or download. Do not reuse an engine across attempts. Do not claim native cancellation; package `0.2.0` does not provide reliable native cancellation.

## 8. Preserve privacy and safety

- Validate 1...1000 visible prompt characters locally.
- Keep prompt text separate from trusted profile and negative prompt data.
- Do not put prompts, generated pixels, credentials, private repository data, or Photo state in URLs, folder names, logs, fixtures, or evidence.
- Send only repository/revision/protocol metadata needed for explicit Hugging Face downloads.
- Validate PNG structure and run on-device Sensitive Content Analysis before display/save.
- Save only after explicit add-only Photos authorization.

## 9. Test before final verification

Deterministic tests should cover:

- featured source order and custom reference parsing;
- private/gated/non-Hugging-Face rejection;
- immutable revisions, license/size confirmation, metadata caps, host redirects, progress, cancellation, retry, integrity, and low storage;
- `Documents/Mirage Models` rooting, staging isolation, atomic promotion, Files tampering, containment, symlinks, case collisions, executable/archive payloads, and data protection;
- no prompt/result/credential leakage into URLs, folders, logs, fixtures, or evidence;
- no load on listing/download, explicit selection state, load only for SEND, actor serialization, and awaited unload after every attempt;
- fail-closed custom snapshot policy;
- Photos add-only save behavior.

## 10. Complete only through Xcode MCP

Use the Hermes-configured Xcode MCP server for final:

- package resolution and binary artifact inspection;
- source/resource/entitlement/Info.plist/scheme membership;
- diagnostics, build, and test execution;
- UI launch and accessibility inspection;
- physical-device multi-GB download, Files visibility, selection, load, generation, unload, memory, thermal, energy, and Photos evidence.

Current evidence is limited to the XcodeMCP focused build/test run recorded in [implementation-evidence.md](implementation-evidence.md). XcodeMCP UI tests returned "No result" and remain a blocker. CLI UI fallback is not constitutional final evidence.
