# Tasks: Single-Page Text-to-Image Generation

**Input**: Design documents from `specs/002-text-to-image/`

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

**Purpose**: Establish test-first value types, the fixed catalog, local model eligibility, memory bounds, prompt/output safety, and developer model provisioning required by every story.

- [x] T007 [P] Add failing value, transition, stale-request, previous-result-retention, and typed-error tests in `MirageTests/ImageGenerationStateTests.swift`
- [x] T008 [P] Add failing tests for eight-family ordering, identifiers, profiles, license/device/evaluation gates, and unavailable reasons in `MirageTests/ModelCatalogTests.swift`
- [x] T009 [P] Add failing tests for Application Support rooting, traversal and symlink escape, extension, size, hash, backup exclusion, file protection, protected-data, and memory failures in `MirageTests/ModelFileResolverTests.swift`
- [x] T010 [P] Add failing prompt normalization, 1–1,000-character, refusal, false-positive, PNG validation, analyzer failure, and sensitive-output tests in `MirageTests/ImageSafetyServiceTests.swift`
- [x] T011 [P] Add versioned harmful-content, injection, jailbreak, stereotype, demographic-bias, unsupported-language, malformed-output, and false-positive fixtures in `MirageTests/AIEvaluation/PromptSafetyFixtures.json`
- [x] T012 Implement immutable Swift 6 `Sendable` model IDs, descriptors, generation profiles, availability, request, progress, image, safety, save, and typed failure values in `Mirage/Features/ImageGeneration/ModelDescriptor.swift`
- [x] T013 [P] Implement the request-scoped state machine and legal transitions from `data-model.md` in `Mirage/Features/ImageGeneration/ImageGenerationState.swift`
- [x] T014 Implement the ordered eight-family catalog, conservative default profiles, package version, and closed-by-default approval fields in `Mirage/Features/ImageGeneration/ModelCatalog.swift`
- [x] T015 Implement the injectable `os_proc_available_memory()` provider and conservative descriptor budget calculation in `Mirage/Features/ImageGeneration/AvailableMemoryProvider.swift`
- [x] T016 Implement Application Support model-root creation, backup exclusion, path containment, file protection, SHA-256 verification, device/license/profile/safety/evaluation gates, and typed availability in `Mirage/Features/ImageGeneration/ModelFileResolver.swift`
- [x] T017 [P] Implement versioned local prompt policy, metadata-free PNG structural validation, and on-device Sensitive Content Analysis behind injectable protocols in `Mirage/Features/ImageGeneration/ImageSafetyService.swift`
- [x] T018 Document development-only provisioning for at least one reviewed local candidate bundle, including exact source URLs, filenames, hashes, licenses, sandbox destination, and a prohibition on committing weights in `specs/002-text-to-image/model-provisioning.md`
- [ ] T019 Use Xcode MCP to run the focused foundational unit tests and record failures or passing evidence without raw prompts, paths, or secrets in `specs/002-text-to-image/implementation-evidence.md`

**Checkpoint**: The catalog always exposes eight entries, unsafe or incomplete entries fail closed with typed reasons, model paths cannot escape app storage, and deterministic foundational tests pass through Xcode MCP.

---

## Phase 3: User Story 1 - Generate an Image from One Page (Priority: P1)

**Goal**: Select an available model, enter a valid prompt, press **SEND**, observe progress, and see one validated generated image above the retained prompt without leaving the page.

**Independent Test**: Inject an available test descriptor and fake engine, enter a valid prompt, press **SEND**, verify one request and progress sequence, then verify the validated image appears above the unchanged prompt; repeat with blank input, refusal, native failure, invalid output, stale callback, and a previous successful image.

### Tests

- [x] T020 [P] [US1] Add failing MainActor view-model tests for prompt validation, one-request serialization, request snapshots, progress, stale callback rejection, refusal, error recovery, and previous-result retention in `MirageTests/ImageGenerationViewModelTests.swift`
- [x] T021 [P] [US1] Add failing actor/service tests for engine reuse, model-switch unload, memory preflight, `ModelFiles`, global callback cleanup, sampler-thread progress bridging, PNG conversion, and truthful non-cancellation behavior in `MirageTests/MirageInferenceServiceTests.swift`
- [x] T022 [P] [US1] Add failing UI journey tests for empty, unavailable, ready, loading, generating, safety-review, result, refusal, and failure states with the result region above the prompt in `MirageUITests/ImageGenerationJourneyTests.swift`
- [x] T023 [P] [US1] Add an environment-gated real-package integration test using `MIRAGE_TEST_MODELS_DIR` without committing weights or logging prompts in `MirageTests/MirageInferenceServiceIntegrationTests.swift`

### Implementation

- [x] T024 [US1] Implement the actor-isolated Mirage 0.2.0 Quick Start adapter with one retained `Engine`, resolved `ModelFiles`, memory gate, `Mirage.setProgressCallback`, `defer` cleanup, serial generation, and PNG payload output in `Mirage/Features/ImageGeneration/MirageInferenceService.swift`
- [x] T025 [US1] Implement the `@MainActor @Observable` prompt, request snapshot, task ownership, progress, safety-review, prior-image, and recoverable-state orchestration in `Mirage/Features/ImageGeneration/ImageGenerationViewModel.swift`
- [x] T026 [US1] Implement the single-column result card, labeled prompt, character count, exact **SEND** action, progress, AI-generated disclosure, and adaptive iPhone/iPad layout in `Mirage/Features/ImageGeneration/ImageGenerationView.swift`
- [x] T027 [US1] Replace the scaffold landing content with the injected image-generation feature root in `Mirage/ContentView.swift`
- [x] T028 [US1] Complete accessible announcements, keyboard Command-Return behavior, control locking, nonjudgmental refusal/error copy, Dynamic Type fallbacks, and previous-image preservation in `Mirage/Features/ImageGeneration/ImageGenerationView.swift` and `Mirage/Features/ImageGeneration/ImageGenerationViewModel.swift`
- [ ] T029 [US1] Use Xcode MCP to run the US1 unit, integration-with-fakes, and UI journey tests and record the independent prompt-to-result evidence in `specs/002-text-to-image/implementation-evidence.md`

**Checkpoint**: US1 works independently with injected services and passes Xcode MCP tests; the real-package test runs only when approved local model assets are explicitly provisioned.

---

## Phase 4: User Story 2 - Choose a Model from the Fixed Catalog (Priority: P2)

**Goal**: Review all eight documented model families, select exactly one available model for the next request, understand why other entries are unavailable, and prevent ambiguous changes during generation.

**Independent Test**: Inject two available and six unavailable descriptors, select each available model in turn, verify exactly one selected state and the next request's model ID, confirm every unavailable family remains visible with a concise reason, and confirm selection is locked while generation runs.

### Tests

- [x] T030 [P] [US2] Add failing selection, first-available default, exact-next-request, unavailable-reason, no-available-model, and in-flight-lock tests in `MirageTests/ImageGenerationViewModelModelSelectionTests.swift`
- [x] T031 [P] [US2] Extend model-picker UI tests for exact README order, selected/disabled traits, status text, VoiceOver values, and generation-time locking in `MirageUITests/ImageGenerationJourneyTests.swift`

### Implementation

- [x] T032 [US2] Implement first-available selection, exact model snapshotting, unavailable-state presentation, recheck-before-SEND, and in-flight selection locking in `Mirage/Features/ImageGeneration/ImageGenerationViewModel.swift`
- [x] T033 [US2] Implement localized, redacted model availability and compatibility presentation without exposing paths, hashes, native errors, or hidden policy details in `Mirage/Features/ImageGeneration/ModelAvailability+Presentation.swift`
- [x] T034 [US2] Implement the accessible eight-entry model menu, checkmark state, disabled entries, and adjacent availability summary in `Mirage/Features/ImageGeneration/ImageGenerationView.swift`
- [ ] T035 [US2] Use Xcode MCP to run the US2 catalog, selection, and accessibility tests and record the independent fixed-catalog evidence in `specs/002-text-to-image/implementation-evidence.md`

**Checkpoint**: US2 is independently testable with fake descriptors, lists all eight families, and never marks an unapproved or incompatible model selectable.

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
- [x] T044 [P] Add MASVS-oriented tests for prompt/result logging, UserDefaults, pasteboard, temporary files, path manipulation, malformed model files, permission revocation, protected data, and absence of remote transport in `MirageTests/ImageGenerationSecurityTests.swift`
- [x] T045 [P] Implement deterministic model quality, safety, demographic-bias, invalid-output, interruption, memory-pressure, fallback, and regression evaluation harnesses in `MirageTests/AIEvaluation/ModelEvaluationTests.swift`
- [x] T046 [P] Populate approved package/model hashes, licenses, profiles, device allowlists, safety policy versions, thresholds, and disabled-family reasons in `MirageTests/AIEvaluation/ModelEvaluationManifest.json`
- [x] T047 [P] Reconcile `Mirage/Resources/PrivacyInfo.xcprivacy`, `Mirage/Mirage.entitlements`, `./project.yml`, and actual runtime behavior, then record the minimization, retention, permission, metadata, logging, and transport review in `specs/002-text-to-image/privacy-assessment.md`
- [x] T048 [P] Update `./README.md` with detailed package resolution, model provisioning, device/memory requirements, privacy, Photos permission, Xcode MCP verification, and current unavailable-model limitations without documenting unapproved downloads as supported
- [x] T049 Review Swift 6 actor/MainActor ownership, task lifetimes, callback cleanup, `Sendable` boundaries, typed errors, one-engine resource bounds, and architectural simplicity across `Mirage/Features/ImageGeneration/` and record findings in `specs/002-text-to-image/implementation-evidence.md`
- [ ] T050 Use Xcode MCP to inspect exact Mirage 0.2.0 resolution, binary artifact, app module name, iOS 26 deployment, source/resource membership, entitlements, Info.plist usage text, privacy manifest, unit/UI test targets, and schemes; record evidence in `specs/002-text-to-image/implementation-evidence.md`
- [ ] T051 Use Xcode MCP to resolve all diagnostics and build and test every affected scheme on an iOS 26 simulator, recording test totals and any justified skips in `specs/002-text-to-image/implementation-evidence.md`
- [ ] T052 Use Xcode MCP to launch Mirage on representative iPhone and iPad destinations and verify every UI state, layout, accessibility mode, keyboard action, refusal/recovery path, and Photos save outcome in `specs/002-text-to-image/implementation-evidence.md`
- [ ] T053 [P] Perform authorized Objection/Frida runtime checks on a designated test build for prompts, PNG data, model paths, logs, UserDefaults, pasteboard, files, network activity, and entitlement exposure, then record redacted results in `specs/002-text-to-image/security-assessment.md`
- [ ] T054 [P] Use Xcode MCP on each eligible physical-device/model pair for at least 20 consecutive generations and record model hashes, quality, safety, bias, load/generation timing, peak memory, energy, thermal state, fallback behavior, and Photos saving in `specs/002-text-to-image/model-evaluation-results.md`
- [ ] T055 Resolve findings from accessibility, security, evaluation, and Xcode MCP evidence, rerun every affected check through Xcode MCP, and record the final clean result in `specs/002-text-to-image/implementation-evidence.md`
- [x] T056 Map every functional, platform, AI, prompt-safety, security, privacy, accessibility, and success requirement to passing evidence or an explicit release blocker in `specs/002-text-to-image/requirements-traceability.md`

**Release Gate**: Do not claim completion unless Xcode MCP evidence is fresh and every enabled model has passing physical-device, safety, bias, resource, stability, and license evidence. If Xcode MCP, approved model assets, legal approval, or eligible hardware is unavailable, record the concrete blocker instead of substituting command-line Xcode output or simulated results.

---

## Dependencies

### Phase dependencies

```text
Phase 1 Setup
  └── Phase 2 Foundational
        ├── Phase 3 US1 Generate Image
        │     └── Phase 5 US3 Save Image
        └── Phase 4 US2 Choose Model

Phases 3, 4, and 5 complete
  └── Phase 6 Polish & Cross-Cutting Concerns
```

### User-story dependencies

- **US1** depends only on Setup and Foundational. It is the MVP and is independently demonstrable with a fake engine plus an optional approved real-model integration test.
- **US2** depends only on Setup and Foundational and may proceed in parallel with US1 because its independent test injects catalog descriptors and captures the next request.
- **US3** depends on US1's validated-image result contract but not on a real diffusion model; its independent test injects PNG data and a fake Photos boundary.
- **Final hardening** depends on all three stories. Runtime security and physical-model evaluation may run in parallel after a test build is available.

### Critical path

`T001 → T006 → T012 → T014 → T016 → T019 → T024 → T025 → T026 → T029 → T039 → T042 → T049 → T050 → T051 → T052 → T055 → T056`

---

## Parallel Execution Examples

### Foundational

After Phase 1, run these independent test/fixture tasks together:

```text
T007 Image generation state tests
T008 Model catalog tests
T009 Model resolver security tests
T010 Prompt and image safety tests
T011 AI safety fixtures
```

After shared value types exist, `T013` and `T017` can proceed in parallel while catalog/resolver work continues in dependency order.

### User Story 1

After Foundation, run `T020`, `T021`, `T022`, and `T023` in parallel. Then implement in dependency order: `T024 → T025 → T026 → T027 → T028 → T029`.

### User Story 2

Run `T030` and `T031` in parallel. Then implement `T032 → T033 → T034 → T035`.

### User Story 3

Run `T036`, `T037`, and `T038` in parallel. Then implement `T039 → T040 → T041 → T042`.

### Cross-cutting

After all stories, run `T043` through `T048` in parallel. After the Xcode MCP build is available, run authorized runtime assessment `T053` and physical-device/model evaluation `T054` in parallel on separate designated devices when resources permit.

---

## Implementation Strategy

### MVP first

1. Complete Setup and Foundational phases.
2. Complete US1 with injected services and deterministic tests.
3. Provision one reviewed local model bundle outside the repository and run the gated integration test.
4. Stop at the US1 checkpoint for a usable prompt-to-image demonstration before adding catalog refinement or Photos saving.

### Incremental delivery

1. **MVP**: US1 produces a validated image on one page with progress and recoverable errors.
2. **Catalog control**: US2 exposes all eight documented families with safe availability gates.
3. **Export**: US3 adds least-privilege Photo Library saving.
4. **Release hardening**: Complete accessibility, privacy, security, model evaluation, and Xcode MCP/device gates.

### Discipline

- Keep model weights and private prompts out of Git, logs, screenshots, fixtures, and evidence.
- Keep package configuration exact at 0.2.0 until a separately reviewed upgrade changes the plan.
- Do not enable a catalog entry based only on package-family support; require complete assets and evidence.
- Write tests/evaluations before implementation where practical and keep fakes at explicit protocol boundaries.
- Do not add model download UI, cloud inference, history, galleries, advanced sampling controls, or cancellation claims.
- Commit only coherent, reviewed increments after fresh Xcode MCP verification.

---

## Summary Counts

- **Total tasks**: 56
- **Setup**: 6
- **Foundational**: 13
- **US1**: 10
- **US2**: 6
- **US3**: 7
- **Polish and cross-cutting**: 14
- **Parallel-marked tasks**: 28
