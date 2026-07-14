# Requirements traceability

Date: 2026-07-14  
Feature: `002-text-to-image`

Status meanings:

- **Implemented / verification blocked** — source and tests exist; Xcode MCP execution is unavailable.
- **Release blocked** — requires approved model artifacts, Xcode MCP, physical devices, or authorized runtime tooling.

## Functional requirements

| Requirement | Implementation | Evidence source | Status |
|---|---|---|---|
| FR-001 | `ImageGenerationView`, `ContentView` | UI journey tests | Implemented / verification blocked |
| FR-002 | `ModelCatalog.entries` exact eight-family order | `ModelCatalogTests`, model-menu UI test | Implemented / verification blocked |
| FR-003 | `ModelDescriptor`, `ModelAvailability`, presentation extension | catalog/resolver tests | Implemented / verification blocked |
| FR-004 | first-available selection and disabled menu options | view-model selection tests | Implemented / verification blocked |
| FR-005 | 1–1,000-character editor and prompt policy | safety/view-model tests | Implemented / verification blocked |
| FR-006 | `canSend`, busy and availability gates | view-model/UI tests | Implemented / verification blocked |
| FR-007 | immutable request snapshot and one task/engine | view-model/service tests | Implemented / verification blocked |
| FR-008 | request-scoped progress and control locking | state/view-model/UI tests | Implemented / verification blocked |
| FR-009 | result-first card with retained editor/model | UI journey test | Implemented / verification blocked |
| FR-010 | state retains previous successful image on refusal/failure | state/view-model tests | Implemented / verification blocked |
| FR-011 | typed failures and redacted recovery copy | state/presentation/view-model tests | Implemented / verification blocked |
| FR-012 | save state hidden until valid image | save view-model/UI tests | Implemented / verification blocked |
| FR-013 | explicit `.addOnly` Photos flow | `PhotoLibrarySaver`, tests | Implemented / verification blocked |
| FR-014 | digest-based exact-once save and truthful outcomes | Photos/save tests | Implemented / verification blocked |
| FR-015 | no history or prompt/image persistence path | security source test and privacy assessment | Implemented / verification blocked |
| FR-016 | metadata-free PNG gate | Photos/safety tests | Implemented / verification blocked |
| FR-017 | labels, Dynamic Type, Reduce Motion, keyboard, adaptive layout | UI source/tests and accessibility audit | Release blocked: physical accessibility audit |

## Platform, AI, privacy, and security gates

| Gate | Implementation/evidence | Status |
|---|---|---|
| iOS 26 / Swift 6 strict concurrency | `project.yml`; actor/MainActor review | Implemented / Xcode MCP inspection blocked |
| Mirage package 0.2.0 | exact XcodeGen package declaration and Quick Start adapter | Real package resolution/build blocked |
| Bounded memory and one engine | memory provider/resolver; actor-retained driver | Physical memory/thermal evidence blocked |
| Model integrity and provenance | exact ERNIE sizes/hashes; fail-closed resolver | Supply-chain discrepancy and evaluation blocked |
| Prompt safety | versioned policy and evaluation fixture | Test execution blocked |
| Output safety | PNG validation and Sensitive Content Analysis fail-closed path | Real-output evaluation blocked |
| Privacy minimization | no-collection manifest, no transport/persistence, add-only Photos | Runtime Objection/network verification blocked |
| MASVS model/file boundary | containment, symlink, extension, size/hash, protection tests | Authorized runtime checks blocked |

## Success criteria

| Criterion | Evidence | Status |
|---|---|---|
| SC-001 usability completion | single-page implementation | Release blocked: usability study not run |
| SC-002 progress within 500 ms / one request | immediate loading state and task guard | Xcode/UI timing run blocked |
| SC-003 one complete image and retained inputs | state/UI source and tests | Test execution blocked |
| SC-004 20 attempts per model/device | `model-evaluation-results.md` | Release blocked: 0 runs |
| SC-005 Photos permission correctness | add-only implementation and tests | Xcode/device run blocked |
| SC-006 VoiceOver journey | labels/announcements and UI test source | Physical VoiceOver audit blocked |
| SC-007 no transport/persistence/metadata | static controls and privacy assessment | Runtime network/storage check blocked |
| SC-008 per-model quality/safety/bias/resources | closed catalog and evaluation manifest | Release blocked: no model approved |

## Final release blockers

1. Hermes-configured Xcode MCP server is not exposed, so package resolution, diagnostics, build, tests, launch, and UI inspection are unverified.
2. No eligible physical-device/model pair has completed the required evaluation.
3. ERNIE supply-chain scanner results require authorized review; every descriptor remains `evaluationApproved: false`.
4. Objection/Frida, network, Photos revocation, and physical accessibility audits are not run.
