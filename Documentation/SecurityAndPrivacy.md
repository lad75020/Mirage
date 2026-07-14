# Security and privacy

## Data handling

- Prompt text, model selection, progress, and generated pixels remain in memory unless the user explicitly saves the result.
- Mirage defines no analytics, telemetry, networking, account, gallery, or cloud persistence path.
- Model files are read only from the app's protected Application Support container and are excluded from backup.
- Generated images are structurally validated, analyzed on-device, and saved as metadata-free PNG data.
- Photos access is add-only and requested only after an explicit Save action.

## Model trust boundary

`ModelFileResolver` rejects paths outside its model root, symlink escapes, missing files, unsupported extensions, missing or malformed SHA-256 hashes, hash mismatches, unapproved license state, incomplete evaluation state, insufficient available memory, and locked protected data. The catalog therefore fails closed until an exact reviewed manifest is supplied.

Model weights are never committed. `.gitignore` excludes GGUF, safetensors, Core ML, and local model directories.

## Prompt and output safety

`PromptSafetyPolicy` is versioned and evaluated against `MirageTests/AIEvaluation/PromptSafetyFixtures.json`. It rejects empty/oversized prompts, explicit exploit instructions, child sexual abuse requests, graphic gore, and explicit sexual content while preserving benign creative prompts.

`ImageSafetyService` verifies PNG structure and dimensions, bounds output size, and uses Apple's on-device Sensitive Content Analysis. If analysis is disabled, unavailable, or fails, the result is not displayed or saved.

## Photos boundary

`PhotoLibrarySaver` validates PNG structure and strips the workflow down to `PHAssetCreationRequest.addResource`. It uses `.addOnly` authorization and suppresses duplicate writes for the same in-memory image digest.

## Logging and secrets

The implementation does not log prompts, file paths, model contents, generated images, authorization decisions, or raw dependency errors. No API key or secret is required.

## Remaining release evidence

- Physical-device objection/MASTG validation: **not run**.
- Approved model hashes and complete transitive licenses: **not supplied**.
- Xcode MCP build/test/launch verification: **blocked until the server is exposed to this session**.
- Sensitive-content and quality evaluation on approved real outputs: **not run**.
