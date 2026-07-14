# Data Model: Single-Page Text-to-Image Generation

**Feature**: `002-text-to-image`
**Date**: 2026-07-14

The feature has no database. All user generation data is session-scoped. Model assets are app-managed files described by immutable catalog metadata.

## 1. ModelDescriptor

Represents one fixed model-family option and the exact validated local bundle needed to enable it.

| Field | Type | Required | Validation / meaning |
|---|---|---:|---|
| `id` | Stable string enum | Yes | One of the eight fixed catalog IDs; never derived from a path. |
| `displayName` | String | Yes | Localized family name shown to the user. |
| `architecture` | String | Yes | Informational architecture from upstream README. |
| `exampleFilename` | String | Yes | Informational README example; not trusted for file resolution. |
| `packageVersion` | Semantic version | Yes | Must equal reviewed exact version `0.2.0` for this plan. |
| `diffusionFilename` | Safe relative filename | Conditional | Required before the entry can be available. No separators or traversal. |
| `vaeFilename` | Safe relative filename | No | Required only for that validated family/profile. |
| `textEncoderFilename` | Safe relative filename | No | Required only for that validated family/profile. |
| `expectedFileHashes` | Map of filename to SHA-256 | Conditional | Required for every enabled file. |
| `bundleBytes` | 64-bit integer | Conditional | Positive measured total of required files. |
| `activationHeadroomBytes` | 64-bit integer | Conditional | Positive approved working-memory reserve. |
| `supportedDeviceClasses` | Set | Conditional | Explicit physical-device allowlist from evaluation evidence. |
| `generationProfile` | GenerationProfile | Conditional | Required before selection is enabled. |
| `licenseStatus` | LicenseStatus | Yes | Must be `approved` before selection is enabled. |
| `safetyPolicyVersion` | String | Conditional | Required before selection is enabled. |
| `negativePrompt` | String | No | Trusted, versioned SFW negative prompt; never user-controlled in this feature. |
| `evaluationVersion` | String | Conditional | Links to passing quality/safety/resource evidence. |

### Fixed IDs and source order

1. `stable-diffusion`
2. `sdxl`
3. `sd3`
4. `flux1`
5. `chroma1-hd`
6. `qwen-image`
7. `ernie-image-turbo`
8. `z-image-turbo`

### Validation rules

A descriptor is **selectable** only when:

- every required filename is present and path-safe;
- each file exists under its own model directory and matches its approved hash;
- the package version, generation profile, license, safety policy, device class, and evaluation version are approved;
- current available memory is at least the greater of the package preflight rule and the descriptor's measured total plus activation headroom;
- no generation or engine transition is active.

## 2. GenerationProfile

Immutable model-specific inference settings approved through physical-device evaluation.

| Field | Type | Validation |
|---|---|---|
| `width` | Integer | Positive multiple of 8. |
| `height` | Integer | Positive multiple of 8. |
| `steps` | Integer | Positive and within model-approved range. |
| `cfgScale` | Float | Finite and within model-approved range. |
| `seedPolicy` | Enum | `random` for this feature; deterministic seeds are evaluation-only. |
| `maximumPromptCharacters` | Integer | Exactly 1,000 for the UI contract. |

Known candidate profiles requiring final evidence:

- ERNIE-Image-Turbo: 1024 × 1024, 8 steps, CFG 1.0.
- Z-Image-Turbo: 1024 × 1024, 9 steps, CFG 1.0.
- Chroma1-HD: 1024 × 1024, 28 steps, CFG 4.0, unavailable on iPhone by default.

Other families remain unavailable until a complete profile is approved.

## 3. ModelAvailability

Computed value describing whether a catalog entry can be selected now.

```text
checking
available
unavailable(reason)
```

Typed unavailable reasons:

- `missingManifest`
- `missingFiles`
- `integrityFailure`
- `licenseNotApproved`
- `deviceUnsupported`
- `insufficientMemory`
- `profileNotValidated`
- `safetyPolicyMissing`
- `engineBusy`
- `protectedDataUnavailable`

The user receives concise localized text. Internal paths, hashes, native diagnostics, and hidden policy details are not exposed.

## 4. GenerationInput

Validated snapshot created when SEND is accepted.

| Field | Type | Validation |
|---|---|---|
| `requestID` | UUID | New for each accepted SEND. |
| `modelID` | Model ID | Must reference the currently selected and available descriptor. |
| `prompt` | String | Trimmed; 1–1,000 visible characters; passes prompt safety policy. |
| `profile` | GenerationProfile | Copied from approved descriptor. |
| `negativePrompt` | String? | Trusted descriptor value only. |

The prompt is never used in paths, logs, analytics, configuration, or Photo metadata.

## 5. GenerationProgress

Immutable `Sendable` value emitted from the inference boundary.

| Field | Type | Validation |
|---|---|---|
| `requestID` | UUID | Must match the active request. |
| `phase` | Enum | `resolving`, `loadingModel`, `generating`, `validating`, `completed`. |
| `step` | Integer? | 1-indexed when package callback begins. |
| `totalSteps` | Integer? | Positive and equals the active profile's steps. |
| `elapsedSincePreviousStep` | Duration? | Nonnegative; first value includes warm-up. |
| `estimatedRemaining` | Duration? | Published only after enough stable samples; never guaranteed. |

Stale request IDs are ignored. Accessibility announcements are throttled independently of visual updates.

## 6. GeneratedImage

Validated session result exposed to UI and save flow.

| Field | Type | Validation |
|---|---|---|
| `requestID` | UUID | Matches its generation input. |
| `modelID` | Model ID | Informational UI state; not embedded in the saved file. |
| `pngData` | Data | Nonempty, decodes as one RGB/RGBA image, contains no prompt/model metadata. |
| `pixelWidth` | Integer | Positive and matches approved output. |
| `pixelHeight` | Integer | Positive and matches approved output. |
| `safetyResult` | SafetyResult | Must be `allowed` before display or save. |

A new allowed result replaces the previous result. Failure/refusal preserves the previous result. The result is not persisted by Mirage.

## 7. SafetyResult

```text
allowed(policyVersion)
refused(reasonCategory)
reviewFailed(recoverableMessage)
```

Reason categories are deliberately coarse and user-safe. Hidden rules, prompt-policy internals, model diagnostics, and sensitive detections are not persisted or displayed.

## 8. SaveOutcome

State of one explicit Photo Library save attempt.

```text
idle
requestingAuthorization
saving
saved
permissionDenied
permissionRestricted
failed(recoverableMessage)
```

Save accepts only a current `GeneratedImage` whose safety result is allowed. It requests add-only authorization and creates exactly one asset per accepted tap.

## 9. ImageGenerationState

Single source of truth for the page.

```text
idle
checkingModels
ready(selectedModelID, previousImage?)
loadingModel(requestID, selectedModelID, previousImage?)
generating(requestID, progress, previousImage?)
validating(requestID, previousImage?)
showingResult(image, saveOutcome)
refused(message, previousImage?)
failed(message, previousImage?)
noAvailableModels(reasonSummary)
```

### State transitions

```text
idle → checkingModels → ready | noAvailableModels
ready → loadingModel                    on valid SEND
loadingModel → generating               engine ready
loadingModel → failed                   load/preflight failure
generating → validating                 package returns CGImage
generating → failed                     native generation failure
validating → showingResult              structural + safety checks pass
validating → refused                    safety policy blocks output
validating → failed                     invalid image/review failure
showingResult → loadingModel            next valid SEND; old image retained
showingResult → requestingAuthorization explicit Save
requestingAuthorization → saving        add-only permission granted
requestingAuthorization → permissionDenied | permissionRestricted
saving → saved | failed
```

Model selection and prompt edits are allowed only when they cannot create ambiguity with an active request. The package exposes no reliable native cancel operation, so UI state cannot transition back to ready until the native call resolves or the process is interrupted.

## Relationships

```text
ModelDescriptor 1 ── 1 GenerationProfile
ModelDescriptor 1 ── 0...* local model files
GenerationInput * ── 1 ModelDescriptor
GenerationProgress * ── 1 GenerationInput
GeneratedImage 1 ── 1 GenerationInput
GeneratedImage 1 ── 1 SafetyResult
GeneratedImage 1 ── 0...* explicit SaveOutcome attempts
ImageGenerationState 1 ── 0...1 active GenerationInput
ImageGenerationState 1 ── 0...1 displayed GeneratedImage
```

## Retention and sensitivity

| Data | Sensitivity | Persistence | Logging |
|---|---|---|---|
| Prompt | Private user content | Memory only | Never |
| Generated image | Private user content | Memory; Photos only on explicit Save | Never |
| Model selection | Low sensitivity | Session only | No analytics |
| Model files/hashes | App asset | Application Support; excluded from backup | Safe status only |
| Native errors | Potentially sensitive/path-bearing | Not persisted | Redacted category only |
| Photo permission | Privacy state | System-owned; app reads current status | Never |
