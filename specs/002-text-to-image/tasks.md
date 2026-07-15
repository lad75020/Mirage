# Tasks: Single-Page Text-to-Image Generation

**Input**: Design documents from `specs/002-text-to-image/`

**Propagated**: 2026-07-14 — Updated from spec.md refinement for featured/custom Hugging Face downloads, Files-accessible storage, selection-triggered lazy loading, and mandatory post-generation unloading.

**Prerequisites**: `spec.md`, `plan.md`, `research.md`, `data-model.md`, `contracts/inference-contract.md`, `contracts/ui-contract.md`, and `quickstart.md`

**Tests**: Tests and evaluations are mandatory under the Mirage constitution. Add the narrowest failing test or evaluation before its implementation whenever practical.

**Organization**: Work is grouped by user story. Each story has explicit independent acceptance evidence and remains testable through injected fakes even when multi-gigabyte model assets are unavailable.

## Format

Each task uses `- [ ] T### [P?] [US?] Description with exact path`.

- `[P]` means the task can run in parallel after its phase prerequisites because it touches different files and has no unmet dependency.
- `[US1]`, `[US2]`, and `[US3]` map to the three prioritized stories in `spec.md`.
- Setup, foundational, and cross-cutting tasks intentionally have no story label.
- XcodeGen output is intermediate only. Final browsing, diagnostics, builds, tests, launches, and physical-device evidence must use the Hermes-configured Xcode MCP server.

---

## Phase 1: Setup

**Purpose**: Align the project with iOS 26, integrate the exact reviewed inference package, and declare required privacy/runtime capabilities before feature code is added.

- [x] T001 Update `./project.yml` to target iOS 26.0, pin `https://github.com/haplollc/Mirage.git` exactly at `0.2.0`, link product `Mirage`, set `PRODUCT_MODULE_NAME` to `MirageApp`, include resources, define `NSPhotoLibraryAddUsageDescription`, and add the `MirageUITests/` target without changing the customer-facing Mirage product or scheme name
- [x] T002 [P] Create `Mirage/Mirage.entitlements` with increased-memory-limit and extended-virtual-addressing entitlements required by haplollc/Mirage 0.2.0
- [x] T003 [P] Create `Mirage/Resources/PrivacyInfo.xcprivacy` with no tracking or collected data and only actually used required-reason API declarations
- [x] T004 [P] Set `GGML_METAL_TENSOR_DISABLE=1` and `GGML_METAL_FUSION_DISABLE=1` before any Metal or inference initialization in `Mirage/MirageApp.swift`
- [x] T005 [P] Change the application test import to `@testable import MirageApp` in `MirageTests/AppMetadataTests.swift`
- [x] T006 Regenerate intermediate project metadata from `./project.yml` into `Mirage.xcodeproj/project.pbxproj` and leave authoritative package, membership, entitlement, and scheme inspection for Xcode MCP

**Checkpoint**: Project metadata names one iOS 26 app module (`MirageApp`), one exact Mirage 0.2.0 package product, unit tests, UI tests, required entitlements, Photos add-only usage text, and the privacy manifest.

---

## Phase 2: Foundational

**Purpose**: Establish test-first value types, model eligibility, memory bounds, prompt/output safety, and the baseline that the propagated Hugging Face download refinement will supersede where marked.

- [x] T007 [P] Add failing value, transition, stale-request, previous-result-retention, and typed-error tests in `MirageTests/ImageGenerationStateTests.swift`
- [x] T008 [P] ~~[REMOVED] Add failing tests for eight-family ordering, identifiers, profiles, license/device/evaluation gates, and unavailable reasons in `MirageTests/ModelCatalogTests.swift`~~ — Superseded by the three featured repositories and dynamic user-entered sources in T058–T064.
- [x] T009 [P] ~~[REMOVED] Add failing tests for Application Support rooting, traversal and symlink escape, extension, size, hash, backup exclusion, file protection, protected-data, and memory failures in `MirageTests/ModelFileResolverTests.swift`~~ — Superseded by Files-backed atomic storage and download security tests in T060–T066.
- [x] T010 [P] Add failing prompt normalization, 1–1,000-character, refusal, false-positive, PNG validation, analyzer failure, and sensitive-output tests in `MirageTests/ImageSafetyServiceTests.swift`
- [x] T011 [P] Add versioned harmful-content, injection, jailbreak, stereotype, demographic-bias, unsupported-language, malformed-output, and false-positive fixtures in `MirageTests/AIEvaluation/PromptSafetyFixtures.json`
- [x] T012 Implement immutable Swift 6 `Sendable` model IDs, descriptors, generation profiles, availability, request, progress, image, safety, save, and typed failure values in `Mirage/Features/ImageGeneration/ModelDescriptor.swift`
- [x] T013 [P] Implement the request-scoped state machine and legal transitions from `data-model.md` in `Mirage/Features/ImageGeneration/ImageGenerationState.swift`
- [x] T014 ~~[REMOVED] Implement the ordered eight-family catalog, conservative default profiles, package version, and closed-by-default approval fields in `Mirage/Features/ImageGeneration/ModelCatalog.swift`~~ — Superseded by T063–T064.
- [x] T015 Implement the injectable `os_proc_available_memory()` provider and conservative descriptor budget calculation in `Mirage/Features/ImageGeneration/AvailableMemoryProvider.swift`
- [x] T016 ~~[REMOVED] Implement Application Support model-root creation, backup exclusion, path containment, file protection, SHA-256 verification, device/license/profile/safety/evaluation gates, and typed availability in `Mirage/Features/ImageGeneration/ModelFileResolver.swift`~~ — Superseded by the Files-visible model store and compatibility resolver in T061, T066, and T079.
- [x] T017 [P] Implement versioned local prompt policy, metadata-free PNG structural validation, and on-device Sensitive Content Analysis behind injectable protocols in `Mirage/Features/ImageGeneration/ImageSafetyService.swift`
- [x] T018 ~~[REMOVED] Document development-only provisioning for at least one reviewed local candidate bundle, including exact source URLs, filenames, hashes, licenses, sandbox destination, and a prohibition on committing weights in `specs/002-text-to-image/model-provisioning.md`~~ — Superseded by user-initiated featured/custom downloads and T068.
- [x] T019 Use Xcode MCP to run the focused foundational unit tests, including T058–T067 after the refinement foundation lands, and record failures or passing evidence without prompts, credentials, private paths, or sensitive repository history in `specs/002-text-to-image/implementation-evidence.md`

**Checkpoint**: Superseded fixed-catalog behavior remains historical; the current checkpoint is satisfied only when the three exact featured sources, custom-reference parser, secure downloader, Files store, compatibility gates, and deterministic foundational tests pass through Xcode MCP.

---

## Phase 3: User Story 1 - Generate an Image from One Page (Priority: P1)

**Goal**: Explicitly select a fully downloaded compatible model, load it lazily, enter a valid prompt, press **SEND**, observe progress, see one validated image above the retained prompt, and verify engine/model-memory release after the attempt.

**Independent Test**: Inject a downloaded compatible descriptor and instrumented fake engine, verify no load on listing/download, explicitly select it, verify one lazy load, enter a valid prompt, press **SEND**, verify one request/result, and assert teardown before another operation; repeat for load failure, native failure, refusal after inference, interruption, stale callback, and previous-result retention.

### Tests

- [x] T020 [P] [US1] Add failing MainActor view-model tests for prompt validation, one-request serialization, request snapshots, progress, stale callback rejection, refusal, error recovery, and previous-result retention in `MirageTests/ImageGenerationViewModelTests.swift`
- [x] T021 [P] [US1] ~~[REMOVED] Add failing actor/service tests for engine reuse, model-switch unload, memory preflight, `ModelFiles`, global callback cleanup, sampler-thread progress bridging, PNG conversion, and truthful non-cancellation behavior in `MirageTests/MirageInferenceServiceTests.swift`~~ — Engine reuse is superseded by mandatory post-attempt teardown in T069–T071.
- [x] T022 [P] [US1] Add failing UI journey tests for empty, unavailable, ready, loading, generating, safety-review, result, refusal, and failure states with the result region above the prompt in `MirageUITests/ImageGenerationJourneyTests.swift`
- [x] T023 [P] [US1] Add an environment-gated real-package integration test using `MIRAGE_TEST_MODELS_DIR` without committing weights or logging prompts in `MirageTests/MirageInferenceServiceIntegrationTests.swift`

### Implementation

- [x] T024 [US1] ~~[REMOVED] Implement the actor-isolated Mirage 0.2.0 Quick Start adapter with one retained `Engine`, resolved `ModelFiles`, memory gate, `Mirage.setProgressCallback`, `defer` cleanup, serial generation, and PNG payload output in `Mirage/Features/ImageGeneration/MirageInferenceService.swift`~~ — Retained-engine lifecycle is superseded by T071.
- [x] T025 [US1] Implement the `@MainActor @Observable` prompt, request snapshot, task ownership, progress, safety-review, prior-image, and recoverable-state orchestration in `Mirage/Features/ImageGeneration/ImageGenerationViewModel.swift`
- [x] T026 [US1] Implement the single-column result card, labeled prompt, character count, exact **SEND** action, progress, AI-generated disclosure, and adaptive iPhone/iPad layout in `Mirage/Features/ImageGeneration/ImageGenerationView.swift`
- [x] T027 [US1] Replace the scaffold landing content with the injected image-generation feature root in `Mirage/ContentView.swift`
- [x] T028 [US1] Complete accessible announcements, keyboard Command-Return behavior, control locking, nonjudgmental refusal/error copy, Dynamic Type fallbacks, and previous-image preservation in `Mirage/Features/ImageGeneration/ImageGenerationView.swift` and `Mirage/Features/ImageGeneration/ImageGenerationViewModel.swift`
- [ ] T029 [US1] Use Xcode MCP to run the US1 unit, integration-with-fakes, and UI journey tests after T069–T073, recording selection-triggered lazy load, prompt-to-result behavior, and post-attempt teardown evidence in `specs/002-text-to-image/implementation-evidence.md`

**Checkpoint**: US1 works independently with injected services and passes Xcode MCP tests; the real-package test runs only when approved local model assets are explicitly provisioned.

---

## Phase 4: User Story 2 - Download and Choose a Hugging Face Model (Priority: P2)

**Goal**: Download one of three exact featured repositories or a custom public Hugging Face reference into Mirage's Files-visible model folder, understand download/compatibility/load state, and explicitly select one compatible model without ambiguity.

**Independent Test**: Download one featured repository and one compatible custom reference through deterministic fakes, verify immutable revision and atomic Files promotion, exercise interruption/retry and incompatible/unsafe snapshots, select each compatible model in turn, and verify selection locking plus exact model identity.

### Tests

- [x] T030 [P] [US2] ~~[REMOVED] Add failing selection, first-available default, exact-next-request, unavailable-reason, no-available-model, and in-flight-lock tests in `MirageTests/ImageGenerationViewModelModelSelectionTests.swift`~~ — Automatic first-available selection is superseded by explicit selection and T070/T075.
- [x] T031 [P] [US2] ~~[REMOVED] Extend model-picker UI tests for exact README order, selected/disabled traits, status text, VoiceOver values, and generation-time locking in `MirageUITests/ImageGenerationJourneyTests.swift`~~ — Superseded by featured/custom download UI tests in T076.

### Implementation

- [x] T032 [US2] ~~[REMOVED] Implement first-available selection, exact model snapshotting, unavailable-state presentation, recheck-before-SEND, and in-flight selection locking in `Mirage/Features/ImageGeneration/ImageGenerationViewModel.swift`~~ — Automatic selection is superseded by T072 and T077.
- [x] T033 [US2] Implement localized, redacted model availability and compatibility presentation without exposing paths, hashes, native errors, or hidden policy details in `Mirage/Features/ImageGeneration/ModelAvailability+Presentation.swift`
- [x] T034 [US2] ~~[REMOVED] Implement the accessible eight-entry model menu, checkmark state, disabled entries, and adjacent availability summary in `Mirage/Features/ImageGeneration/ImageGenerationView.swift`~~ — Superseded by T078.
- [ ] T035 [US2] ~~[REMOVED] Use Xcode MCP to run the US2 catalog, selection, and accessibility tests and record the independent fixed-catalog evidence in `specs/002-text-to-image/implementation-evidence.md`~~ — Superseded by T080.

**Checkpoint**: US2 is complete only when featured and custom public references download safely, appear in Files, remain non-selectable while partial/invalid/incompatible, and trigger lazy loading only after explicit compatible selection.

---

## Phase 5: User Story 3 - Save the Generated Image (Priority: P3)

**Goal**: Explicitly save the current validated image to Photos using add-only authorization, report the true outcome, and keep the result visible after denial or failure.

**Independent Test**: Inject a validated PNG and fake Photos boundary, verify Save is absent before a result, then exercise not-determined/granted/denied/restricted/write-failure states and confirm one accepted tap produces at most one metadata-free asset without requesting read access.

### Tests

- [x] T036 [P] [US3] Add failing add-only authorization, exact-once asset creation, denied, restricted, write-failure, concurrency, and metadata-absence tests in `MirageTests/PhotoLibrarySaverTests.swift`
- [x] T037 [P] [US3] Add failing view-model tests for Save visibility, authorization transitions, success confirmation, duplicate-tap suppression, and result retention on failure in `MirageTests/ImageGenerationViewModelSaveTests.swift`
- [x] T038 [P] [US3] Extend UI journey tests for hidden, permission-prompt, saving, saved, denied, restricted, retry, VoiceOver, and Command-S states in `MirageUITests/ImageGenerationJourneyTests.swift`

### Implementation

- [x] T039 [US3] Implement injectable Photos add-only authorization and exact-once metadata-free PNG asset creation with typed errors in `Mirage/Features/ImageGeneration/PhotoLibrarySaver.swift`
- [x] T040 [US3] Implement save task ownership, permission/save state transitions, duplicate suppression, and non-destructive recovery in `Mirage/Features/ImageGeneration/ImageGenerationViewModel.swift`
- [x] T041 [US3] Implement result-associated Save visibility, progress, confirmation, Settings guidance, VoiceOver semantics, and Command-S behavior in `Mirage/Features/ImageGeneration/ImageGenerationView.swift`
- [ ] T042 [US3] Use Xcode MCP to run the US3 Photos boundary and UI journey tests and record the independent save-flow evidence in `specs/002-text-to-image/implementation-evidence.md`

**Checkpoint**: US3 requests only add access after explicit Save, saves one current validated PNG, never reads Photos, and preserves the image through every permission or write outcome.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Complete accessibility, privacy, security, AI evaluation, documentation, and authoritative Xcode MCP/device verification across all stories.

- [ ] T043 [P] Expand the complete VoiceOver order, Accessibility XXXL, Reduce Motion, Increase Contrast, Reduce Transparency, light/dark, rotation, keyboard, and iPad multitasking matrix in `MirageUITests/ImageGenerationJourneyTests.swift`
- [x] T044 [P] ~~[REMOVED] Add MASVS-oriented tests for prompt/result logging, UserDefaults, pasteboard, temporary files, path manipulation, malformed model files, permission revocation, protected data, and absence of remote transport in `MirageTests/ImageGenerationSecurityTests.swift`~~ — The no-network assumption is superseded by explicit Hugging Face download security tests in T062 and T081.
- [x] T045 [P] Implement deterministic model quality, safety, demographic-bias, invalid-output, interruption, memory-pressure, fallback, and regression evaluation harnesses in `MirageTests/AIEvaluation/ModelEvaluationTests.swift`
- [x] T046 [P] ~~[REMOVED] Populate approved package/model hashes, licenses, profiles, device allowlists, safety policy versions, thresholds, and disabled-family reasons in `MirageTests/AIEvaluation/ModelEvaluationManifest.json`~~ — The eight-family manifest is superseded by featured revision and custom-model policy work in T082.
- [x] T047 [P] ~~[REMOVED] Reconcile `Mirage/Resources/PrivacyInfo.xcprivacy`, `Mirage/Mirage.entitlements`, `./project.yml`, and actual runtime behavior, then record the minimization, retention, permission, metadata, logging, and transport review in `specs/002-text-to-image/privacy-assessment.md`~~ — Must be redone for network and Files behavior in T081.
- [x] T048 [P] ~~[REMOVED] Update `./README.md` with detailed package resolution, model provisioning, device/memory requirements, privacy, Photos permission, Xcode MCP verification, and current unavailable-model limitations without documenting unapproved downloads as supported~~ — Superseded by T083.
- [x] T049 Review Swift 6 actor/MainActor ownership, task lifetimes, callback cleanup, `Sendable` boundaries, typed errors, one-engine resource bounds, and architectural simplicity across `Mirage/Features/ImageGeneration/` and record findings in `specs/002-text-to-image/implementation-evidence.md`
- [ ] T050 Use Xcode MCP to inspect Mirage 0.2.0 resolution, iOS 26 deployment, downloader/store source membership, Files exposure keys, dedicated model path, network/privacy configuration, entitlements, usage text, privacy manifest, tests, and schemes; record evidence in `specs/002-text-to-image/implementation-evidence.md`
- [ ] T051 Use Xcode MCP to resolve all diagnostics and build and test every affected scheme on an iOS 26 simulator, including repository parsing, downloader, Files store, compatibility, lazy-load, teardown, UI, privacy, and security tests, recording totals and justified skips in `specs/002-text-to-image/implementation-evidence.md`
- [ ] T052 Use Xcode MCP to launch Mirage on representative iPhone and iPad destinations and verify featured/custom download, interruption/recovery, Files visibility, explicit selection/loading, generation/unloading, accessibility, and Photos outcomes in `specs/002-text-to-image/implementation-evidence.md`
- [ ] T053 [P] Perform authorized Objection/Frida runtime checks on a designated test build for repository metadata, prompts, PNG data, staging/model paths, logs, defaults, pasteboard, network hosts/payloads, Files protection, engine teardown, and entitlement exposure, then record redacted results in `specs/002-text-to-image/security-assessment.md`
- [ ] T054 [P] Use Xcode MCP on each eligible featured-revision/device pair for at least 20 consecutive download/select/generate/unload cycles and record revision/hashes, quality, safety, bias, transfer recovery, Files state, load/generation timing, post-teardown memory, energy, thermal state, fallback behavior, and Photos saving in `specs/002-text-to-image/model-evaluation-results.md`
- [ ] T055 Resolve findings from accessibility, security, evaluation, and Xcode MCP evidence, rerun every affected check through Xcode MCP, and record the final clean result in `specs/002-text-to-image/implementation-evidence.md`
- [x] T056 ~~[REMOVED] Map every functional, platform, AI, prompt-safety, security, privacy, accessibility, and success requirement to passing evidence or an explicit release blocker in `specs/002-text-to-image/requirements-traceability.md`~~ — The pre-refinement map is superseded by T084.

**Release Gate**: Do not claim completion unless Xcode MCP evidence is fresh; every enabled featured revision has passing download, integrity, Files, physical-device, safety, bias, resource, stability, unload, and license evidence; and custom snapshots fail closed unless compatible. If Xcode MCP, official download access, approved model assets, legal approval, or eligible hardware is unavailable, record the concrete blocker instead of inventing or substituting evidence.

---

## Phase 7: Refinement Propagation - Hugging Face Model Lifecycle

**Purpose**: Replace the superseded fixed/pre-provisioned model architecture without deleting historical work, then satisfy the refined FR-018–FR-026 download, Files storage, lazy-load, and teardown requirements.

### Setup and foundational refinement

- [x] T057 Update `./project.yml`, generated Info.plist configuration, and `Mirage/Resources/PrivacyInfo.xcprivacy` for explicit public model downloads plus `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace`, without adding arbitrary-domain exceptions or credentials
- [x] T058 [P] Add failing canonical-reference and featured-source ordering tests for `jc-builds/Z-Image-Turbo-iOS`, `jc-builds/ERNIE-Image-Turbo-iOS`, and `jc-builds/Chroma1-HD-iOS`, plus full-URL normalization, malformed/private/gated/non-Hugging-Face rejection, resolved-revision, and custom-compatibility tests in `MirageTests/ModelRepositoryReferenceTests.swift` and `MirageTests/ModelCatalogTests.swift`
- [x] T059 [P] Add failing download, validation, selection, loading, teardown, cancellation, and Files-tampering state-transition tests in `MirageTests/ImageGenerationStateTests.swift`
- [x] T060 [P] Add failing HTTPS/redirect policy, immutable-revision, expected-size/license confirmation, progress, cancellation, retry, resume, low-storage, partial-download, integrity, and atomic-promotion tests in `MirageTests/HuggingFaceModelDownloaderTests.swift`
- [x] T061 [P] Add failing Documents/Mirage Models rooting, stable-folder mapping, staging isolation, containment, symlink, case collision, executable payload, archive-bomb, Files edit/removal, data-protection, and compatibility tests in `MirageTests/ModelStoreTests.swift` and `MirageTests/ModelFileResolverTests.swift`
- [x] T062 [P] Add failing MASVS-oriented tests for malicious references/snapshots, official-host redirect allowlisting, prompt/result/credential exclusion from requests and model folders, partial activation, sensitive logging, and cleanup in `MirageTests/ImageGenerationSecurityTests.swift` and `MirageTests/SecurityTests/ModelAssetSecurityTests.swift`
- [x] T063 Implement immutable `Sendable` canonical repository, resolved revision, download state/progress, local snapshot, compatibility, and load-state values in `Mirage/Features/ImageGeneration/ModelRepositoryReference.swift`, `Mirage/Features/ImageGeneration/ModelDownload.swift`, and `Mirage/Features/ImageGeneration/ModelDescriptor.swift`
- [x] T064 [P] Replace the fixed eight-family catalog with the three exact featured references and dynamic downloaded/custom entries, preserving closed-by-default compatibility in `Mirage/Features/ImageGeneration/ModelCatalog.swift`
- [x] T065 [P] Implement an actor-isolated public Hugging Face snapshot downloader with URLSession, official-host redirect policy, immutable revision resolution, explicit size/license confirmation data, progress, cancellation/recovery, staging, and typed errors in `Mirage/Features/ImageGeneration/HuggingFaceModelDownloader.swift`
- [x] T066 [P] Implement the Files-visible `Documents/Mirage Models` store, safe folder mapping, available-space gate, atomic promotion, snapshot metadata, containment, integrity, executable rejection, compatibility resolution, and Files-tampering refresh in `Mirage/Features/ImageGeneration/ModelStore.swift` and `Mirage/Features/ImageGeneration/ModelFileResolver.swift`
- [x] T067 Wire injectable catalog/downloader/store protocols and live/preview/test dependencies without embedding credentials in `Mirage/Features/ImageGeneration/ImageGenerationDependencies.swift`, `Mirage/Features/ImageGeneration/LiveDependencies.swift`, `Mirage/Features/ImageGeneration/PreviewDependencies.swift`, and `MirageTests/TestFixtures.swift`
- [x] T068 [P] Propagate the refined model lifecycle into `specs/002-text-to-image/research.md`, `specs/002-text-to-image/data-model.md`, `specs/002-text-to-image/contracts/inference-contract.md`, `specs/002-text-to-image/contracts/ui-contract.md`, `specs/002-text-to-image/quickstart.md`, and `specs/002-text-to-image/model-provisioning.md`

### User Story 1 refinement - Lazy load and deterministic teardown

- [x] T069 [P] [US1] Add failing service tests proving no load on listing/download, one load after explicit selection, no competing load/inference, and callback/engine/model-memory teardown after success, native failure, refused output, discarded late result, and interruption in `MirageTests/MirageInferenceServiceTests.swift`
- [x] T070 [P] [US1] Add failing MainActor tests for explicit selection, loading progress/failure, SEND gating until loaded, logical selection retention after unload, teardown barrier, previous-image retention, and next-attempt reload in `MirageTests/ImageGenerationViewModelTests.swift` and `MirageTests/ImageGenerationViewModelModelSelectionTests.swift`
- [x] T071 [US1] Refactor `Mirage/Features/ImageGeneration/MirageInferenceService.swift` to load the selected resolved files on demand, serialize native work, and use guaranteed post-attempt cleanup that clears the callback and releases the Engine before returning or throwing
- [x] T072 [US1] Refactor selection/load/generation orchestration and legal states in `Mirage/Features/ImageGeneration/ImageGenerationViewModel.swift` and `Mirage/Features/ImageGeneration/ImageGenerationState.swift` so explicit selection triggers load and every completed attempt returns to a selected-but-unloaded state
- [x] T073 [US1] Update `Mirage/Features/ImageGeneration/ImageGenerationView.swift` with accessible selection-triggered loading progress, SEND gating, unload-safe recovery, and no automatic first-model selection
- [x] T074 [US1] Use Xcode MCP to run T069–T073 tests and record independent lazy-load and deterministic post-attempt teardown evidence in `specs/002-text-to-image/implementation-evidence.md`

### User Story 2 refinement - Featured and custom downloads

- [x] T075 [P] [US2] Add failing view-model tests for featured download confirmation, custom reference submission, progress/cancellation/retry, downloaded-but-incompatible state, exact revision identity, explicit selection, operation locking, and Files removal refresh in `MirageTests/ImageGenerationViewModelModelSelectionTests.swift`
- [x] T076 [P] [US2] Add failing UI journeys for the three exact featured sources, custom reference field, size/license confirmation, progress, cancellation/retry, Files location, invalid/private/gated/incompatible status, explicit selection, VoiceOver, Dynamic Type, and operation locking in `MirageUITests/ImageGenerationJourneyTests.swift`
- [x] T077 [US2] Implement MainActor download/list/refresh/selection orchestration with separate download, compatibility, and load states in `Mirage/Features/ImageGeneration/ImageGenerationViewModel.swift`
- [x] T078 [US2] Implement the accessible featured source cards, downloaded-model list, custom Hugging Face reference field, explicit Download/Cancel/Retry actions, progress, Files location, compatibility messages, and selected state in `Mirage/Features/ImageGeneration/ImageGenerationView.swift`
- [x] T079 [US2] Implement foreground and pre-selection store refresh so Files edits/removals/integrity changes invalidate stale compatibility without exposing paths or hashes in `Mirage/Features/ImageGeneration/ImageGenerationViewModel.swift`, `Mirage/Features/ImageGeneration/ModelStore.swift`, and `Mirage/Features/ImageGeneration/ModelAvailability+Presentation.swift`
- [ ] T080 [US2] Use Xcode MCP to run T075–T079 catalog/download/Files/selection/accessibility tests and record the independent featured/custom model-download evidence in `specs/002-text-to-image/implementation-evidence.md`

### Cross-cutting refinement

- [x] T081 [P] Reconcile network and Files behavior across `Mirage/Resources/PrivacyInfo.xcprivacy`, `Mirage/Mirage.entitlements`, `./project.yml`, `specs/002-text-to-image/privacy-assessment.md`, and `specs/002-text-to-image/security-assessment.md`, covering retention, staging cleanup, request minimization, official hosts, data protection, and App Store disclosures
- [x] T082 [P] Replace fixed-family evaluation metadata with exact featured repository revisions/hashes/licenses/profiles and custom-model runtime policy, then add download recovery and post-teardown memory assertions in `MirageTests/AIEvaluation/ModelEvaluationManifest.json`, `MirageTests/AIEvaluation/ModelEvaluationTests.swift`, and `MirageTests/ImageGenerationPerformanceTests.swift`
- [x] T083 [P] Update `./README.md` with detailed featured/custom download instructions, Files location, storage/device requirements, compatibility limits, public-only scope, privacy/security behavior, lazy loading, mandatory unloading, and Xcode MCP verification
- [x] T084 Map FR-001–FR-026, PLAT-001–PLAT-003, AI-001–AI-005, SAFE-001–SAFE-006, SEC-001–SEC-006, and SC-001–SC-010 to implemented tasks, passing evidence, or explicit blockers in `specs/002-text-to-image/requirements-traceability.md`

### Requirement-to-task traceability

| Specification requirements | Primary task coverage |
|---|---|
| FR-001, FR-005–FR-017 | T010–T013, T017, T020, T022, T025–T029, T036–T043, T051–T055, T069–T074 |
| FR-002 (superseded fixed catalog) | T008, T014, T030–T035 marked removed; replacements T058, T064, T075–T080 |
| FR-003–FR-004 | T058–T067, T070, T075–T080 |
| FR-018–FR-020 | T058, T060, T063–T065, T075–T078 |
| FR-021–FR-023 | T057, T060–T067, T075–T081 |
| FR-024–FR-025 | T059, T069–T074, T082, T050–T055 |
| FR-026 | T058, T061, T064, T066, T075, T077–T080 |
| PLAT-001–PLAT-003 | T001–T006, T022, T026, T028, T043, T050–T052, T057, T073, T076, T078 |
| AI-001–AI-005 | T015, T017, T023, T045, T054, T058–T071, T074–T075, T079, T082 |
| SAFE-001–SAFE-006 | T010–T011, T017, T044–T045, T058, T060–T066, T069, T075, T081–T082 |
| SEC-001–SEC-006 | T003, T009, T016, T044, T047, T053, T057, T060–T067, T079, T081 |
| SC-001–SC-010 | T019, T029, T035, T042–T055, T058–T084 |

---

## Dependencies

### Phase dependencies

```text
Existing baseline: Phases 1–5
  └── Phase 7 Setup/Foundation (T057–T068)
        ├── Phase 7 US1 refinement (T069–T074)
        └── Phase 7 US2 refinement (T075–T080)
              └── real-model US1 integration

Phase 7 US1 + US2 and existing US3 complete
  └── Phase 7 cross-cutting (T081–T084)
        └── remaining Phase 6 verification (T050–T055)
```

### User-story dependencies

- **US1** refinement depends on T057–T067 and is independently testable with an instrumented fake engine; its real-model path additionally depends on a completed compatible download from US2.
- **US2** refinement depends on T057–T067. Its tests may run in parallel with US1 tests; downloader/store implementation provides the real assets required by US1 integration.
- **US3** depends on US1's validated-image result contract but not on a real diffusion model; its independent test injects PNG data and a fake Photos boundary.
- **Final hardening** depends on refined US1/US2 plus existing US3. Runtime security T053 and featured-model physical evaluation T054 may run in parallel after T050–T052 establish a verified test build.

### Critical path

`T057 → T058 → T063 → T065 → T067 → T075 → T077 → T078 → T080 → T050 → T051 → T052 → T054 → T084 → T055`

---

## Parallel Execution Examples

### Refinement foundation

After T057, run these independent test tasks together:

```text
T058 repository/catalog tests
T059 lifecycle-state tests
T060 downloader tests
T061 Files store/resolver tests
T062 download and snapshot security tests
```

After T063 defines shared values, T064, T065, and T066 can proceed in parallel; T067 integrates all three. T068 documentation propagation can proceed in parallel once those contracts are stable.

### User Story 1

After T067, run T069 and T070 in parallel. Then implement `T071 → T072 → T073 → T074`; real-model evidence waits for a compatible US2 download.

### User Story 2

After T067, run T075 and T076 in parallel. Then implement `T077 → T078`, complete T079, and verify with T080.

### User Story 3

Run `T036`, `T037`, and `T038` in parallel. Then implement `T039 → T040 → T041 → T042`.

### Cross-cutting

After refined US1/US2, run T081, T082, and T083 in parallel. Complete Xcode MCP inspection/build/launch T050–T052, then run T053 and T054 in parallel before T084 and final resolution T055.

---

## Implementation Strategy

### MVP first

1. Complete T057–T067 to establish secure public downloads and Files-backed storage.
2. Complete T075–T080 with one featured source and a deterministic custom-reference fixture.
3. Complete T069–T074 so explicit selection loads lazily and every native attempt unloads deterministically.
4. Re-run the existing Photos flow and stop at a downloadable, generate, unload, and save demonstration before cross-cutting hardening.

### Incremental delivery

1. **Acquisition**: US2 securely downloads one featured or custom public repository into Files with compatibility state.
2. **Inference lifecycle**: US1 explicitly selects, lazily loads, generates one image, and unloads.
3. **Export**: US3 retains least-privilege Photo Library saving.
4. **Release hardening**: Complete download security, privacy, accessibility, featured-model evaluation, memory teardown, and Xcode MCP/device gates.

### Discipline

- Keep model weights, private prompts, credentials, sensitive custom repository history, and generated pixels out of Git, logs, screenshots, fixtures, and evidence.
- Keep package configuration exact at 0.2.0 until a separately reviewed upgrade changes the plan.
- Do not enable a downloaded snapshot based only on repository name or package-family support; require immutable revision, complete assets, compatibility, memory, and safety evidence.
- Write tests/evaluations before implementation where practical and keep fakes at explicit protocol boundaries.
- Permit cancellation only for download tasks; do not claim native inference cancellation. Do not add authenticated repositories, cloud inference, history, galleries, advanced sampling controls, executable plugins, or unrestricted download domains.
- Commit only coherent, reviewed increments after fresh Xcode MCP verification.

---

## Summary Counts

- **Total tasks**: 84
- **Setup**: 6
- **Foundational baseline**: 13
- **US1 baseline**: 10
- **US2 baseline**: 6
- **US3**: 7
- **Polish and cross-cutting baseline**: 14
- **Refinement propagation**: 28
- **Parallel-marked tasks**: 44
- **Superseded tasks retained and marked removed**: 17
