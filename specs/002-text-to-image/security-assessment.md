# Security assessment

Date: 2026-07-14
Feature: `002-text-to-image`

## Static controls implemented

- Exact package requirement for haplollc/Mirage `0.2.0`.
- Public unauthenticated Hugging Face repository parsing only.
- Credentialed, private, gated, non-Hugging-Face, query/fragment, port, non-HTTPS, and malformed references rejected.
- Metadata cap of 2 MiB.
- Official-host redirect allowlist for Hugging Face and known CDN/Xet hosts.
- Required immutable commit SHA, license, file sizes, and LFS SHA-256.
- Model file count cap of 24, per-file cap of 16 GiB, and snapshot cap of 24 GiB.
- Streaming downloads with byte progress and no cookies.
- Staging outside the promoted model folder.
- Staging cleanup on cancellation and failure.
- Atomic promotion into `Documents/Mirage Models`.
- Snapshot metadata with immutable source/integrity data.
- Containment, safe path, symlink, case collision, executable, archive, hidden-file, unexpected-file, byte-count, and SHA-256 validation.
- Files tamper refresh that marks changed snapshots incompatible.
- Custom snapshots fail closed by default.
- Actor-serialized native attempts with awaited unload after every attempt.
- Prompt/output safety checks remain local.
- Photos save uses add-only authorization and metadata-free PNG validation.
- No prompt, result, credential, token, private repository data, native path, or raw dependency error is intentionally written to URLs, model folders, logs, fixtures, or evidence.

## Automated source coverage

Relevant test sources include:

- `ModelRepositoryReferenceTests`
- `ModelCatalogTests`
- `HuggingFaceModelDownloaderTests`
- `ModelStoreTests`
- `ModelFileResolverTests`
- `ImageGenerationStateTests`
- `ImageGenerationViewModelModelSelectionTests`
- `MirageInferenceServiceTests`
- `ImageGenerationSecurityTests`
- `SecurityTests/ModelAssetSecurityTests`
- `AIEvaluation/ModelEvaluationTests`
- `ImageGenerationPerformanceTests`

XcodeMCP selected all 68 `MirageTests`: 67 passed, the environment-gated real-package integration test skipped, and 0 failed. Full XcodeMCP UI, accessibility, runtime, device, and real-download evidence remains blocked or not run.

## Runtime checks

| Check | Result |
|---|---|
| XcodeMCP BuildProject | Passed with 0 errors. |
| XcodeMCP unit/security/download/model tests | 68 selected: 67 passed, 1 environment-gated integration test skipped, 0 failed; 0 Issue Navigator errors. |
| XcodeMCP UI tests | **BLOCKED**: 12 selected, 0 executed, 12 "No result"; not a pass. CLI fallback passed 12/12 but is not final constitutional evidence. |
| Real multi-GB Hugging Face download | **NOT RUN** |
| Physical-device load/generation/unload | **NOT RUN** |
| 20-cycle featured model evaluation | **NOT RUN** |
| Instruments memory/energy/thermal trace | **NOT RUN** |
| Objection/Frida storage/logs/defaults/pasteboard/network inspection | **NOT RUN** |
| Legal/release approval | **NOT RUN** |

## Residual risk

The static controls and deterministic tests are necessary but insufficient for release. Multi-GB transfer behavior, Files visibility, model load memory, unload memory release, thermal pressure, output quality/safety, and App Store privacy disclosures need physical-device and XcodeMCP evidence before any featured descriptor can set `evaluationApproved = true`.
