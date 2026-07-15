# Research: Single-Page Text-to-Image Generation

**Feature**: `002-text-to-image`
**Date**: 2026-07-14
**Refined**: Public Hugging Face downloads, Files-visible storage, explicit selection, lazy load, and post-attempt unload.

## 1. Swift Package Release and Provenance

**Decision**: Depend on `https://github.com/haplollc/Mirage.git` at exact version `0.2.0`.

**Rationale**:

- Release `0.2.0` is the reviewed stable release for this feature.
- The tag resolves to commit `34b9bbf0b17a1aa42593d7e9d64ff55091944ec9`.
- Its binary artifact checksum is `2754f948ff12e1c546f46e0dfa59f29627d468b1c30ba1783bdaa5d8948e5472`.
- The package provides the native `Engine`, `ModelFiles`, `GenerationRequest`, and progress callback used by the app.
- Model weights have separate licenses and are reviewed per immutable Hugging Face revision.

**Rejected alternatives**:

- `from: "0.2.0"`: allows unreviewed package updates.
- Direct stable-diffusion.cpp integration: expands native surface area outside the selected package.
- A retained multi-model cache: unsafe for mobile memory budgets.

## 2. Module Name Collision

**Decision**: Keep the app product and scheme named `Mirage`, but use Swift module name `MirageApp` for the app target and import package module `Mirage`.

**Rationale**: This preserves the user-facing app name and avoids ambiguous imports in app and test code.

## 3. Featured and Custom Model Sources

**Decision**: Replace the removed fixed eight-family catalog with these exact featured public repositories, in order:

1. `jc-builds/Z-Image-Turbo-iOS`
2. `jc-builds/ERNIE-Image-Turbo-iOS`
3. `jc-builds/Chroma1-HD-iOS`

Users may also enter a public unauthenticated Hugging Face model reference as `owner/repository` or a full `https://huggingface.co/owner/repository` URL. The parser rejects credentials, queries, fragments, ports, non-HTTPS URLs, non-Hugging-Face hosts, encoded path separators, malformed paths, private repositories, and gated repositories.

**Rationale**: The refined product scope requires explicit user downloads while keeping the trust boundary narrow. Repository code is never executed.

## 4. Verified Featured Metadata

Metadata was verified through the Hugging Face API on 2026-07-14. All three repositories were public, ungated, and licensed as Apache-2.0. The exact reviewed Z-Image descriptor is runtime-enabled by explicit product decision; ERNIE and Chroma remain disabled, and physical-device/release evidence is still pending.

| Repository | Commit | Profile | Required files |
|---|---|---|---|
| `jc-builds/Z-Image-Turbo-iOS` | `97ae389b962ee927d83c1911be743c8d82c11674` | 1024 x 1024, 9 steps, CFG 1.0 | `Qwen3-4B-Instruct-2507-Q4_K_M.gguf` 2497281120 bytes SHA `3605803b982cb64aead44f6c1b2ae36e3acdb41d8e46c8a94c6533bc4c67e597`; `ae.safetensors` 335304388 bytes SHA `afc8e28272cd15db3919bacdb6918ce9c1ed22e96cb12c4d5ed0fba823529e38`; `z-image-turbo-Q3_K_M.gguf` 4186161216 bytes SHA `7070b605165c372833c21c6bd45e73b242cf0db261b4d5436039363f3dbd4e0e` |
| `jc-builds/ERNIE-Image-Turbo-iOS` | `f23d470af1a57a64aa034d0770e74f99aac6135f` | 1024 x 1024, 8 steps, CFG 1.0 | `ernie-image-turbo-Q3_K_M.gguf` 3909632704 bytes SHA `3c1813fc1e0e904cc342e7b6791d0165e6dbb6aac30ad2924747b198bc435857`; `ae.safetensors` 168120878 bytes SHA `ca70d2202afe6415bdbcb8793ba8cd99fd159cfe6192381504d6c4d3036e0f04`; `Ministral-3-3B-Instruct-2512-Q4_K_M.gguf` 2146497824 bytes SHA `fd46fc371ff0509bfa8657ac956b7de8534d7d9baaa4947975c0648c3aa397f4` |
| `jc-builds/Chroma1-HD-iOS` | `722a672dca0d2ec5ff39dea561ae0df62bf49995` | 1024 x 1024, 28 steps, CFG 4.0 | `Chroma1-HD-Q4_K_S.gguf` 5432053920 bytes SHA `4443db48850a45bb7f163a0582ea0e9f9d449db1aa56632c8572515e8e83acc8`; `ae.safetensors` 335304388 bytes SHA `afc8e28272cd15db3919bacdb6918ce9c1ed22e96cb12c4d5ed0fba823529e38`; `t5xxl_fp16.safetensors` 9787841024 bytes SHA `6e480b09fae049a72d2a8c5fbccb8d3e92febeb233bbe9dfe7256958a9167635` |

## 5. Download Policy

**Decision**: Download only from official Hugging Face model and CDN hosts over HTTPS:

- `huggingface.co`
- `cdn-lfs.huggingface.co`
- `cdn-lfs-us-1.huggingface.co`
- `cdn-lfs-eu-1.huggingface.co`
- `cdn-lfs.hf.co`
- `cas-bridge.xethub.hf.co`

The downloader reads API metadata with `blobs=true`, caps metadata at 2 MiB, accepts at most 24 model files, caps each file at 16 GiB, caps each snapshot at 24 GiB, requires an immutable 40-character commit SHA, requires a nonempty license, requires size metadata, and requires a 64-character LFS SHA-256 for every `.gguf` or `.safetensors` file.

**Rationale**: The app needs exact revision, size, license, and integrity information before asking the user to confirm a multi-GB download. Partial or hashless files never become selectable.

## 6. Storage and Files Visibility

**Decision**: Store promoted snapshots in:

```text
Documents/Mirage Models/<safe-repository-folder>/
```

Staging lives outside the promoted model folder. Promotion is atomic: validate staged files, copy them into a replacement directory, write `.mirage-snapshot.json`, apply file protection, then move or replace the final folder. Cancellation and failures remove staging data. Files edits are detected by refresh and convert the snapshot to an incompatible state.

**Rationale**: Users explicitly need Files visibility. The dedicated folder keeps model assets distinct from prompts, generated images, credentials, logs, and Photos data.

## 7. Compatibility and Fail-Closed Custom Models

**Decision**: Download completion is separate from compatibility. Featured snapshots are compatible only when repository, commit SHA, license, file names, byte counts, SHA-256 hashes, safety policy, memory, OS, device, and evaluation gates pass. Custom snapshots default to `unknownCustomRepository` and remain unselectable until local validation identifies a supported Mirage package profile.

**Rationale**: A public repository can contain valid files but still be unsupported or unsafe for this app/device.

## 8. Inference Lifecycle

**Decision**: `MirageInferenceService` is an actor. It serializes attempts, resolves files for the selected descriptor, creates a native engine only after SEND begins the selected model attempt, generates once, then awaits unload before returning success or failure.

**Rationale**: Listing or downloading a model must not consume multi-GB inference memory. The package has a global progress callback and no reliable native cancellation API, so attempts are serialized and teardown is the memory boundary.

## 9. Privacy and Safety

**Decision**:

- Prompt text is validated locally and passed only to `GenerationRequest.prompt`.
- Prompt, result pixels, credentials, and private repository data are not placed in URLs, folder names, logs, fixtures, or evidence.
- Model metadata/download requests include only repository, revision, and protocol data needed for the explicit download.
- Generated PNGs stay in memory unless the user explicitly saves to Photos.
- Photos uses add-only authorization and does not read the user's library.

## 10. Verification Authority

Final project inspection, diagnostics, build, test, launch, and device evidence must come from the Hermes-configured Xcode MCP server. CLI checks may support development but are not constitutional final evidence.

## Sources

- haplollc/Mirage README, tag 0.2.0: https://github.com/haplollc/Mirage/blob/0.2.0/README.md
- haplollc/Mirage release 0.2.0: https://github.com/haplollc/Mirage/releases/tag/0.2.0
- haplollc/Mirage Package.swift, tag 0.2.0: https://github.com/haplollc/Mirage/blob/0.2.0/Package.swift
- Z-Image-Turbo iOS bundle: https://huggingface.co/jc-builds/Z-Image-Turbo-iOS
- ERNIE-Image-Turbo iOS bundle: https://huggingface.co/jc-builds/ERNIE-Image-Turbo-iOS
- Chroma1-HD iOS bundle: https://huggingface.co/jc-builds/Chroma1-HD-iOS
