# Data Model: Single-Page Text-to-Image Generation

**Feature**: `002-text-to-image`
**Date**: 2026-07-14

Mirage has no database. Prompt and generated-image data are session-scoped. Downloaded model snapshots and non-sensitive source/integrity metadata persist in the app Documents container so the user can inspect them in Files.

## 1. ModelRepositoryReference

Canonical public Hugging Face repository identity.

| Field | Type | Validation / meaning |
|---|---|---|
| `owner` | String | 1...96 characters; letters, numbers, `.`, `_`, `-`; no empty, leading/trailing `.`, or `..`. |
| `repository` | String | Same component validation as `owner`. |
| `id` | String | `owner/repository`; used for display and metadata, not as a filesystem path. |
| `apiURLWithBlobs` | URL | `https://huggingface.co/api/models/<owner>/<repository>?blobs=true`. |

Accepted user input is either `owner/repository` or `https://huggingface.co/owner/repository`. Credentials, query strings, fragments, ports, non-HTTPS URLs, non-Hugging-Face hosts, encoded separators, private repositories, and gated repositories are rejected.

## 2. ResolvedModelRevision

Immutable remote revision resolved before download confirmation.

| Field | Type | Validation / meaning |
|---|---|---|
| `reference` | ModelRepositoryReference | Canonical public reference. |
| `commitSHA` | String | Exactly 40 hex characters. Branch names such as `main` are not accepted as resolved revisions. |
| `license` | String? | Required by downloader before confirmation; normalized lowercase. |
| `totalSizeBytes` | Int64? | Sum of accepted `.gguf` and `.safetensors` files when metadata supplies sizes. |

## 3. ModelDownloadFile

One downloadable model asset selected from repository metadata.

| Field | Type | Validation / meaning |
|---|---|---|
| `path` | Safe relative path | No absolute path, traversal, empty component, backslash, encoded separator, or unsafe extension. |
| `sizeBytes` | Int64 | Positive and no more than 16 GiB. |
| `sha256` | String | Required 64-character LFS SHA-256. |
| `downloadURL` | URL | Immutable revision URL under an official Hugging Face host. |

Only `.gguf` and `.safetensors` files are selected. Metadata is capped at 2 MiB. A plan may include at most 24 files and at most 24 GiB total.

## 4. ModelDownloadPlan and State

| Field | Type | Validation / meaning |
|---|---|---|
| `revision` | ResolvedModelRevision | Public, ungated, immutable repository revision. |
| `files` | [ModelDownloadFile] | Complete expected file list with sizes and hashes. |
| `expectedSizeBytes` | Int64 | Sum of file sizes; used for confirmation, storage preflight, and progress. |

Download state:

```text
notDownloaded
resolving(reference)
awaitingConfirmation(revision, sizeBytes, license)
downloading(reference, progress)
validating(reference)
downloaded(snapshot)
cancelled(reference)
failed(reference, reason)
```

Users must explicitly confirm size/license information before transfer. Cancellation and failure clean staging data and never activate partial files.

## 5. LocalModelSnapshot

Promoted snapshot in Files-visible storage.

| Field | Type | Validation / meaning |
|---|---|---|
| `reference` | ModelRepositoryReference | Source repository. |
| `commitSHA` | String | Immutable revision actually downloaded. |
| `folderName` | String | Stable safe slug plus digest, generated from repository identity. |
| `folderURL` | URL | Under `Documents/Mirage Models`. |
| `files` | [ModelDownloadFile] | Exact promoted file list. |
| `license` | String? | Source license recorded at download time. |
| `compatibility` | ModelCompatibility | Separate from download completion. |

The store writes `.mirage-snapshot.json` in the folder. Refresh validates metadata, file count, safe paths, byte counts, SHA-256, case collisions, executable flags, symlinks, hidden files, and unexpected files. Files tampering returns an incompatible state instead of loading stale data.

## 6. ModelDescriptor

Reviewed generation descriptor for a featured repository.

| Field | Type | Validation / meaning |
|---|---|---|
| `id` | ModelID | One of `zImageTurbo`, `ernieImageTurbo`, or `chroma1HD` for current featured descriptors. Historical fixed-family IDs remain in code only for compatibility with superseded tests/tasks. |
| `repository` | ModelRepositoryReference | Must match one featured source. |
| `reviewedRevisionSHA` | String | Exact reviewed commit SHA. |
| `familyName` | String | User-facing model name. |
| `summary` | String | Short user-facing description. |
| `packageVersion` | String | Must be `0.2.0`. |
| `requirements` | [ModelFileRequirement] | Required files, byte counts, and SHA-256 hashes. |
| `profile` | GenerationProfile | Width, height, steps, CFG scale, and optional trusted negative prompt. |
| `minimumAvailableMemoryBytes` | UInt64 | Conservative preflight memory threshold. |
| `licenseApproved` | Bool | True only after license metadata is accepted for planning. |
| `evaluationApproved` | Bool | Runtime compatibility gate for an explicitly enabled reviewed artifact set. Runtime enablement does not establish release approval. |
| `safetyPolicyVersion` | String | Must match current prompt/output safety policy. |

Featured descriptors currently use:

| ID | Repository | Commit | Profile | Evaluation |
|---|---|---|---|---|
| `zImageTurbo` | `jc-builds/Z-Image-Turbo-iOS` | `97ae389b962ee927d83c1911be743c8d82c11674` | 1024 x 1024, 9 steps, CFG 1.0 | true |
| `ernieImageTurbo` | `jc-builds/ERNIE-Image-Turbo-iOS` | `f23d470af1a57a64aa034d0770e74f99aac6135f` | 1024 x 1024, 8 steps, CFG 1.0 | false |
| `chroma1HD` | `jc-builds/Chroma1-HD-iOS` | `722a672dca0d2ec5ff39dea561ae0df62bf49995` | 1024 x 1024, 28 steps, CFG 4.0 | false |

The exact reviewed Z-Image snapshot is runtime-enabled. ERNIE, Chroma, and custom snapshots remain fail-closed; Z-Image still requires physical-device and release evidence.

## 7. ModelCompatibility and Availability

```text
compatible(profile)
incompatible(reason)
unknownCustomRepository
```

Custom snapshots default to `unknownCustomRepository` and are not selectable. Featured snapshots become compatible only when source, commit, files, byte counts, SHA-256, license, safety policy, profile, OS, device, and memory gates all pass.

`ModelAvailability` reports current selection readiness:

```text
checking
available
configurationIncomplete
missingFiles(names)
integrityFailed(name)
licenseNotApproved
evaluationRequired
unsupportedDevice
insufficientMemory(required, available)
protectedDataUnavailable
invalidPath
incompatibleAssets
```

User-facing text is concise and redacted. It does not expose local paths, hashes, native errors, prompts, credentials, or hidden safety rules.

## 8. GenerationRequestSnapshot

Validated immutable snapshot created when SEND is accepted.

| Field | Type | Validation / meaning |
|---|---|---|
| `id` | UUID | New for each accepted attempt. |
| `prompt` | String | Trimmed, 1...1000 visible characters, prompt-safety approved. |
| `modelID` | ModelID | Must match selected descriptor. |
| `profile` | GenerationProfile | Copied from descriptor. |
| `createdAt` | Date | Request timestamp. |

The prompt is never used in URLs, folder names, logs, fixtures, evidence, Photo metadata, or model metadata.

## 9. ImageGenerationState

Single source of truth for the page:

```text
idle
checkingModels
ready
resolvingDownload(reference)
downloadingModel(reference, progress)
validatingDownload(reference)
downloadCancelled(reference)
loadingModel(requestID, previousResult)
modelLoaded(reference)
modelUnloaded(reference)
filesTampered(reference)
generating(requestID, progress, previousResult)
reviewingSafety(requestID, previousResult)
success(image)
refused(message, previousResult)
failed(failure, previousResult)
```

Listing and downloading never load native weights. The current implementation begins native load as part of the SEND attempt for the explicitly selected compatible model, serializes the attempt in the inference actor, and awaits unload before returning. Logical selection remains separate from native engine lifetime.

## 10. GeneratedImage and SaveState

`GeneratedImage` contains request ID, model ID, immutable PNG data, and pixel dimensions. It remains in memory unless the user explicitly saves it.

`SaveState`:

```text
hidden
ready
requestingPermission
saving
saved
denied
failed
```

Saving uses Photo Library add-only authorization and writes one metadata-free PNG per accepted Save action.

## Retention and Sensitivity

| Data | Sensitivity | Persistence | Transport |
|---|---|---|---|
| Prompt | Private user content | Memory only | Never sent for download or inference. |
| Generated image | Private user content | Memory; Photos only after explicit Save | Never sent by Mirage. |
| Featured/custom repository reference | User-selected model source | Download state/session; snapshot metadata after promotion | Sent only to public Hugging Face API/download hosts. |
| Downloaded model files | Third-party assets | `Documents/Mirage Models`; user-visible in Files | Downloaded over HTTPS from official hosts. |
| Snapshot metadata | Non-sensitive source/integrity data | `.mirage-snapshot.json` in model folder | Not uploaded. |
| Credentials/tokens | Out of scope | Never stored | Never accepted. |
