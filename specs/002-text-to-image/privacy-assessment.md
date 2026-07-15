# Privacy assessment

Date: 2026-07-14
Feature: `002-text-to-image`

## Data inventory

| Data | Purpose | Storage | Retention | Transport |
|---|---|---|---|---|
| Prompt | User-requested image generation | Process memory | Current request/session only | Not sent by Mirage. |
| Generated PNG | Display and optional Photos save | Process memory; Photos only after explicit Save | Session or user-controlled Photos | Not sent by Mirage. |
| Logical model selection | Choose the next generation model | Process memory | Current session | Not sent by itself. |
| Featured/custom repository reference | Resolve/download user-selected model | Download state and snapshot metadata | Until app/session or model folder deletion | Sent to Hugging Face API/download hosts only after explicit action. |
| Resolved commit, license, file names, sizes, hashes | Integrity and compatibility | `.mirage-snapshot.json` in `Documents/Mirage Models` | Until model folder deletion | Not uploaded by Mirage. |
| Model bytes | On-device inference | `Documents/Mirage Models` visible in Files | Until user deletes app/model files | Downloaded from official Hugging Face hosts. |
| Download staging | Partial transfer/validation | Temporary staging outside promoted folder | Removed on success, cancellation, or failure | Download target only. |
| Photos authorization state | Save outcome | System-owned | System-managed | Not sent by Mirage. |

## Runtime reconciliation

- `PrivacyInfo.xcprivacy` declares no tracking and no collected data.
- `project.yml` enables Files sharing with `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace`.
- The app requests only Photo Library add access and only after explicit Save.
- The app has no accounts, analytics, advertising SDK, telemetry endpoint, prompt logging, generation history, pasteboard use, or credential storage.
- Network behavior is limited to explicit public unauthenticated Hugging Face metadata and model file downloads.
- Official hosts are restricted to `huggingface.co`, `cdn-lfs.huggingface.co`, `cdn-lfs-us-1.huggingface.co`, `cdn-lfs-eu-1.huggingface.co`, `cdn-lfs.hf.co`, and `cas-bridge.xethub.hf.co`.
- Prompts and generated pixels are not included in metadata URLs, download URLs, model folders, snapshot metadata, logs, fixtures, or evidence.
- Downloaded model folders are user-visible under `Documents/Mirage Models`; they contain only model files and `.mirage-snapshot.json`.
- File protection is applied to model root, staging root, promoted folders, and metadata.
- Generated PNG input is rejected if it contains GPS, EXIF, or TIFF metadata before Photos save.

## App Store disclosure position

Current intended disclosure:

- No tracking.
- No collected user data.
- Network use is user-initiated model download traffic to Hugging Face infrastructure.
- No remote inference.
- No prompt or generated image upload.
- Photo Library access is add-only and user initiated.

This position still requires final App Store privacy review after XcodeMCP and runtime traffic inspection.

## Retention and deletion

Ending the process releases prompt and generated-image memory. Saved images are governed by Photos. Downloaded models remain in the app Documents container and are visible through Files until the user deletes the model folder or the app. Cancelled/failed download staging is removed by the app.

## Open release blockers

- XcodeMCP has not completed full target/resource/privacy inspection.
- XcodeMCP selected 12 UI tests but executed none (`No result` for all 12); a CLI fallback passed 12/12 but is not constitutional final evidence.
- A Z-Image download was reported successful by the user, but no independently captured multi-GB download evidence is recorded.
- No physical-device prompt/result/network/storage inspection has been run.
- No authorized Objection/Frida runtime inspection has been run.
- No final App Store legal/privacy release approval has occurred.
