# Security and privacy

## Data handling

- Prompt text, model selection, progress, and generated pixels remain in memory unless the user explicitly saves the result.
- Mirage defines no analytics, telemetry, account, gallery, or cloud persistence path. Network access is limited to explicit public Hugging Face model metadata and file downloads.
- Model files are downloaded only after explicit user action and promoted under `Documents/Mirage Models` so they are visible in Files.
- Prompts, generated images, credentials, tokens, and private repository data are not written to model folders, URLs, logs, fixtures, or evidence.
- Generated images are structurally validated, analyzed on-device, and saved as metadata-free PNG data.
- Photos access is add-only and requested only after an explicit Save action.

## Model trust boundary

`ModelRepositoryReference` accepts only public unauthenticated Hugging Face model repositories. Private, gated, credentialed, non-Hugging-Face, query/fragment, port, and malformed references are rejected.

`HuggingFaceModelDownloader` requires an immutable commit SHA, license, file sizes, and LFS SHA-256 hashes. Redirects are restricted to official Hugging Face/CDN hosts, metadata is capped at 2 MiB, snapshots are capped at 24 files and 24 GiB, and each file is capped at 16 GiB.

`ModelStore` stages downloads outside the promoted folder, removes staging on cancellation/failure, validates containment, file count, byte counts, hashes, symlinks, case collisions, executables, archives, hidden files, and unexpected files, then atomically promotes into `Documents/Mirage Models`.

`ModelFileResolver` rechecks protected data, device/OS, memory, license, evaluation approval, supported files, byte counts, and SHA-256 before returning native URLs. Featured and custom models fail closed until all gates pass.

Model weights are never committed. `.gitignore` excludes GGUF, safetensors, Core ML, and local model directories.

## Prompt and output safety

`PromptSafetyPolicy` is versioned and evaluated against `MirageTests/AIEvaluation/PromptSafetyFixtures.json`. It rejects empty/oversized prompts, explicit exploit instructions, child sexual abuse requests, graphic gore, and explicit sexual content while preserving benign creative prompts.

`ImageSafetyService` verifies PNG structure and dimensions, bounds output size, and uses Apple's on-device Sensitive Content Analysis. If analysis is disabled, unavailable, or fails, the result is not displayed or saved.

## Photos boundary

`PhotoLibrarySaver` validates PNG structure and strips the workflow down to `PHAssetCreationRequest.addResource`. It uses `.addOnly` authorization and suppresses duplicate writes for the same in-memory image digest.

## Logging and secrets

The implementation does not log prompts, model contents, generated images, authorization decisions, credentials, or raw dependency errors. No API key, Hugging Face token, or secret is required or supported.

## Remaining release evidence

- XcodeMCP BuildProject and focused tests: **passed** as recorded in `specs/002-text-to-image/implementation-evidence.md`.
- XcodeMCP UI tests: **blocked** because RunSomeTests returned "No result".
- Physical-device Objection/MASTG validation: **not run**.
- Real multi-GB download, Files visibility, physical load/generation/unload, Instruments, and 20-cycle evaluation: **not run**.
- Legal/release approval: **not run**.
