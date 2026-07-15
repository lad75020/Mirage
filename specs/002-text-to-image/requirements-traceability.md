# Requirements traceability

Date: 2026-07-14
Feature: `002-text-to-image`

Status meanings:

- **Implemented / XcodeMCP unit target passed**: source and deterministic tests are covered by the XcodeMCP run of all 68 `MirageTests` (67 passed, 1 environment-gated integration test skipped, 0 failed) in [implementation-evidence.md](implementation-evidence.md).
- **Implemented / XcodeMCP UI blocked**: source/tests exist, but UI-test execution returned "No result".
- **Release blocked**: physical-device, runtime, legal, accessibility, or full XcodeMCP evidence is missing.
- **Superseded**: historical fixed-catalog requirement was replaced by refined requirements and tasks.

## Functional requirements

| Requirement | Primary implementation/tasks | Evidence | Status |
|---|---|---|---|
| FR-001 one adaptive page | T025-T028, T073, T078 | Source plus UI tests; XcodeMCP UI returned "No result" | Implemented / XcodeMCP UI blocked |
| FR-002 fixed catalog removal | T008/T014/T030-T035 removed; T058, T064, T075-T080 replacements | Spec/tasks preserve supersession | Superseded |
| FR-003 model identity/state | T058-T064, T075, T077-T079 | Focused catalog/reference/state tests | Implemented / focused XcodeMCP passed |
| FR-004 compatible selected/loaded before generation | T066, T070-T072, T075, T077-T079 | Focused resolver/view-model/inference tests | Implemented; exact reviewed Z-Image snapshot runtime-enabled; physical release verification pending |
| FR-005 prompt length/editing | T010, T017, T020, T025 | Focused view-model/safety tests | Implemented / focused XcodeMCP passed |
| FR-006 SEND gating | T020, T025, T070, T072 | Focused view-model tests | Implemented / focused XcodeMCP passed |
| FR-007 one generation request | T020, T069-T071 | Focused inference/view-model tests | Implemented / focused XcodeMCP passed |
| FR-008 progress/control locking | T020, T059, T073, T075-T078 | Focused state/view-model tests; UI blocked | Implemented / XcodeMCP UI blocked |
| FR-009 result above prompt | T022, T026, T073 | UI source/tests | Implemented / XcodeMCP UI blocked |
| FR-010 previous result retention | T007, T020, T025, T070 | Focused state/view-model tests | Implemented / focused XcodeMCP passed |
| FR-011 redacted recovery guidance | T013, T017, T033, T062, T081 | Focused security/state tests and assessments | Implemented / focused XcodeMCP passed |
| FR-012 save visible only for valid image | T036-T041 | Existing Photos tests; not in focused 47-test list | Implemented / full XcodeMCP blocked |
| FR-013 explicit add-only save | T036, T039-T041 | Photos tests/source | Implemented / full XcodeMCP blocked |
| FR-014 truthful save outcomes | T036-T041 | Photos tests/source | Implemented / full XcodeMCP blocked |
| FR-015 no prompt/result persistence | T017, T044/T062, T081 | Focused security tests and privacy assessment | Implemented / focused XcodeMCP passed; runtime inspection blocked |
| FR-016 metadata-free saved image | T017, T036, T039, T081 | Safety/Photos tests | Implemented / full XcodeMCP blocked |
| FR-017 accessibility | T022, T028, T043, T076, T078 | UI tests/audit source | Release blocked: XcodeMCP UI and physical accessibility not complete |
| FR-018 exact featured repos | T058, T064, T083 | Focused catalog/reference tests; README | Implemented / focused XcodeMCP passed |
| FR-019 custom public reference normalization | T058, T063, T075, T077 | Focused reference/view-model tests | Implemented / focused XcodeMCP passed |
| FR-020 size/license/commit confirmation | T060, T065, T075, T077-T078 | Focused downloader/view-model tests; docs | Implemented / focused XcodeMCP passed |
| FR-021 HTTPS/progress/cancel/recovery/integrity | T060, T065, T082 | Downloader tests including interruption/retry | Implemented / focused XcodeMCP passed; real download blocked |
| FR-022 Files-visible model folders | T057, T061, T066, T079, T081 | Store tests/docs | Implemented / focused XcodeMCP passed; physical Files check blocked |
| FR-023 containment/storage/integrity unsafe rejection | T060-T066, T079, T081 | Focused downloader/store/security tests | Implemented / focused XcodeMCP passed |
| FR-024 no load until explicit selected attempt | T069-T073 | Focused inference/view-model tests | Implemented / focused XcodeMCP passed |
| FR-025 unload after every native attempt | T069-T074, T082 | Focused inference/performance boundary tests | Implemented / focused XcodeMCP passed; Instruments evidence blocked |
| FR-026 custom snapshots fail closed | T058, T061, T064, T066, T075, T077-T080, T082 | Manifest and catalog/store tests | Implemented / focused XcodeMCP passed |

## Constitutional gates

| Gate | Coverage | Status |
|---|---|---|
| PLAT-001 iOS 26 iPhone/iPad | T001-T006, T057 | BuildProject passed; full XcodeMCP inspection blocked | Implemented / release blocked |
| PLAT-002 result above prompt/adaptive layout | T026, T073, T078 | UI source/tests | XcodeMCP UI blocked |
| PLAT-003 semantic labels/states | T028, T043, T076, T078 | UI source/tests | XcodeMCP UI and accessibility audit blocked |
| AI-001 on-device inference/no prompt upload | T017, T062, T071, T081 | Security tests/privacy assessment | Runtime network inspection blocked |
| AI-002 featured revisions/licenses/profiles | T064, T082 | Manifest/docs | Implemented; release approval blocked |
| AI-003 integrity/package/device/storage/memory gates | T060-T066, T079 | Focused tests | Implemented; physical device blocked |
| AI-004 one active load/inference/unload | T069-T074, T082 | Focused inference/performance tests | Implemented; Instruments blocked |
| AI-005 quality/safety/bias evaluations | T045, T054, T082 | Harness/manifest only | Release blocked: no 20-cycle runs |
| SAFE-001 prompt untrusted | T010, T017, T081 | Safety/security tests | Implemented / focused XcodeMCP passed |
| SAFE-002 no autonomous tools, explicit Photos | T036-T041 | Photos source/tests | Full XcodeMCP blocked |
| SAFE-003 guardrails/refusal | T010, T017, T045 | Safety/eval tests | Implemented; real model output blocked |
| SAFE-004 safety corpus | T011, T045 | Fixtures/harness | Implemented; full run/evaluation blocked |
| SAFE-005 AI-generated disclosure | T026, T078 | UI source/tests | XcodeMCP UI blocked |
| SAFE-006 repo data untrusted | T058-T066, T081 | Focused downloader/store/security tests | Implemented / focused XcodeMCP passed |
| SEC-001 minimization/no prompt upload | T062, T081 | Security/privacy docs/tests | Runtime inspection blocked |
| SEC-002 add-only Photos | T036-T041 | Source/tests | Full XcodeMCP blocked |
| SEC-003 no tracking/telemetry; limited downloads | T003, T057, T060, T081 | Privacy manifest/docs/tests | Runtime traffic inspection blocked |
| SEC-004 retention/unload/cleanup | T060, T065-T066, T069-T074, T081-T082 | Focused tests/docs | Implemented; device memory blocked |
| SEC-005 MASVS runtime checks | T053, T081 | Assessment records not run | Release blocked |
| SEC-006 malicious references/snapshots | T060-T066, T079, T081 | Focused tests | Implemented / focused XcodeMCP passed |

## Success criteria

| Criterion | Evidence | Status |
|---|---|---|
| SC-001 usability download/select/generate/save | UI/source only | Release blocked: usability and XcodeMCP UI not complete |
| SC-002 progress within 500 ms / one request | State/view-model/inference tests | Implemented; UI timing blocked |
| SC-003 one complete image and retained inputs | State/view-model tests | Implemented; real model blocked |
| SC-004 20 attempts per model/device | `model-evaluation-results.md` | Release blocked: 0 runs |
| SC-005 Photos correctness | Photos source/tests | Full XcodeMCP/device blocked |
| SC-006 VoiceOver journey | UI tests/audit source | Release blocked |
| SC-007 no prompt/result transport/persistence | Security/privacy assessment | Runtime inspection blocked |
| SC-008 model quality/safety/bias/resources | Manifest fail-closed | Release blocked: no model approved |
| SC-009 unsafe/incomplete downloads nonselectable | Downloader/store/security tests | Implemented; real interruption blocked |
| SC-010 explicit load and post-attempt release | Inference/performance tests | Implemented; Instruments/physical memory blocked |

## Final release blockers

1. XcodeMCP UI tests returned "No result".
2. Full XcodeMCP scheme test/build/launch inspection is incomplete.
3. A Z-Image download was reported successful by the user, but independent download/Files visibility evidence is not recorded.
4. No physical-device generation/unload/memory/thermal/energy evaluation has run.
5. No 20-cycle featured model evaluation has run.
6. No authorized runtime security/privacy inspection has run.
7. No legal/release approval has occurred.
8. Z-Image is runtime-enabled, but its physical-device release evidence is incomplete; ERNIE and Chroma remain disabled.
