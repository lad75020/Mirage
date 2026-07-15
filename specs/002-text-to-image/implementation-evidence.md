# Implementation evidence

Date: 2026-07-15
Feature: `002-text-to-image`

## Implemented source behavior

- iOS 26.0 and Swift 6 XcodeGen configuration.
- Exact `haplollc/Mirage` package requirement at `0.2.0` and `MirageApp` module separation.
- Increased-memory and extended-virtual-addressing entitlements.
- No-collection privacy manifest and add-only Photos purpose text.
- Files sharing keys for user-visible `Documents/Mirage Models`.
- Three exact featured public Hugging Face references:
  - `jc-builds/Z-Image-Turbo-iOS`
  - `jc-builds/ERNIE-Image-Turbo-iOS`
  - `jc-builds/Chroma1-HD-iOS`
- Public custom Hugging Face reference parsing with credential/private/gated/non-Hugging-Face rejection.
- Hugging Face API metadata resolution with immutable commit SHA, license, size, and LFS SHA-256 requirements.
- Official-host redirect allowlist, metadata/file count/file size/snapshot caps, byte progress, integrity verification, and cancellation cleanup.
- Files-visible model store under `Documents/Mirage Models`, staging isolation, atomic promotion, snapshot metadata, data protection, containment, executable/archive/symlink/case-collision checks, and Files tamper refresh.
- Custom snapshots fail closed by default.
- MainActor download/list/refresh/selection orchestration with separate download, compatibility, and generation states.
- Actor-isolated inference service that loads only inside an accepted SEND attempt, serializes attempts, clears callbacks, and awaits unload after every attempt.
- Prompt/output safety, previous-result retention, add-only Photos save flow, accessible one-page UI, and deterministic tests for the above boundaries.

## XcodeMCP evidence obtained

Truthful evidence already obtained through Hermes-configured XcodeMCP in the open Xcode project:

| Evidence | Result |
|---|---|
| BuildProject | Current Z-Image compatibility verification succeeded with 0 errors. |
| Focused Z-Image tests | `testDocumentedZImageSnapshotIsCompatibleAndSelectable` and `testEvaluationManifestMatchesFeaturedCatalogCandidates` both passed. |
| Earlier full `MirageTests` target | 68 selected: 67 passed, 1 environment-gated real-package integration test skipped, 0 failed. |
| Issue Navigator | 0 errors and 170 warnings; warnings are primarily pre-existing MainActor diagnostics in UI tests plus one recommended-settings warning. |

The earlier full-target XcodeMCP run exercised all 20 `MirageTests` suites, including:

- `MirageInferenceServiceTests`
- `ImageGenerationViewModelTests`
- `ImageGenerationViewModelModelSelectionTests`
- `ModelRepositoryReferenceTests`
- `ModelCatalogTests`
- `HuggingFaceModelDownloaderTests`
- `ModelStoreTests`
- `ModelFileResolverTests`
- `ImageGenerationStateTests`
- `ImageGenerationSecurityTests`
- `ModelAssetSecurityTests`

The only skipped test was `MirageInferenceServiceIntegrationTests/testRealPackageGenerationWhenApprovedModelsAreProvisioned()` because approved local weights were not provisioned. This evidence supports marking T019 and T074 complete and supports source/test completion for T057-T073 and T075-T079 where current code and tests satisfy the task text.

Current CLI development verification executed 69 unit tests with 68 passed, the same approved-bundle integration test skipped, and 0 failures. An arm64 iOS Simulator Release build also succeeded. A generic universal simulator Release build is unsupported because the upstream native `sdcpp` artifact does not contain an x86_64 simulator slice.

## XcodeMCP limitation

XcodeMCP `RunSomeTests` selected all 12 UI tests but returned `No result` for each: 0 executed and 12 not run. This is not a pass. A CLI fallback executed all 12 UI journeys with 12 passing and 0 failures, but that is intermediate evidence rather than constitutional final evidence. T080 and any UI/accessibility release gate remain blocked until XcodeMCP returns a real UI-test result.

## Not performed

No claim is made for:

- independently captured multi-GB download evidence (a Z-Image download was reported successful by the user);
- physical-device run;
- physical-device Files visibility;
- physical-device load/generation/unload;
- 20-cycle featured model evaluation;
- Instruments memory, energy, or thermal trace;
- authorized Objection/Frida runtime inspection;
- legal/release approval;
- App Store privacy approval.

The exact reviewed Z-Image descriptor is `evaluationApproved = true` and can be selected after verified download. ERNIE, Chroma, and custom repositories remain fail-closed. This runtime enablement is not evidence of a completed physical-device or release evaluation.

## Ownership and concurrency review

- UI-observable state is `@MainActor`.
- Downloader, store, resolver, inference, and test doubles are actor/protocol boundaries where mutable state crosses tasks.
- Domain values and dependency protocols are `Sendable`.
- The native engine is held only inside the driver actor for one attempt.
- The global Mirage progress callback is installed for generation and cleared before unload.
- The service awaits unload before returning, so a second attempt cannot start while the previous engine remains logically loaded.
- The package does not expose reliable native cancellation, so the UI does not claim native inference cancellation.
- Download cancellation is supported and removes staging data.
- Raw dependency errors, prompts, model paths, credentials, and generated data are not surfaced or logged intentionally.

## Remaining blockers

1. XcodeMCP UI test execution must return a concrete pass/fail result.
2. XcodeMCP full scheme test/build/launch inspection remains incomplete.
3. Eligible physical devices and real model downloads are still required.
4. Runtime privacy/security inspection is still required.
5. Featured model legal/release approval is still required.
