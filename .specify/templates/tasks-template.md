---
description: "Mirage task list template for SwiftUI and on-device AI features"
---

# Tasks: [FEATURE NAME]

**Input**: Design documents from `/specs/[###-feature-name]/`

**Prerequisites**: `spec.md`, `plan.md`, `research.md`, and applicable data,
contract, prompt, model, security, and evaluation artifacts

**Tests**: Tests are mandatory. Write the narrowest failing test or evaluation
before implementation whenever practical.

**Organization**: Group tasks by user story so each story remains independently
implementable, testable, secure, and releasable.

## Format: `[ID] [P?] [Story] Description with exact path`

- **P**: Can run in parallel because it touches different files and has no unmet dependency.
- **Story**: Maps the task to a user story such as US1 or US2.
- Use Swift/Xcode paths from the approved plan; do not retain sample paths.
- Continue task IDs sequentially without duplicates.

## Mirage Path Conventions

- App source: `Mirage/`
- Unit and integration tests: `MirageTests/`
- UI journeys: `MirageUITests/`
- AI prompts, schemas, tools, and evaluation fixtures: approved feature paths
  under `Mirage/AI/` and `MirageTests/AIEvaluation/`
- Feature documents: `specs/[###-feature-name]/`

## Phase 1: Research and Setup

**Purpose**: Confirm requirements, native APIs, trust boundaries, and test surfaces.

- [ ] T001 Confirm Swift, SwiftUI, Swift 6 strict concurrency, and iOS 26.0+ constraints in the plan
- [ ] T002 [P] Research native Apple frameworks and justify each dependency in `research.md`
- [ ] T003 [P] Document actor isolation, cancellation, error, and state ownership in `plan.md`
- [ ] T004 [P] Document data lifecycle, threat model, MASVS controls, and runtime assessment in `plan.md`
- [ ] T005 [P] For AI, document framework selection, availability, fallback, token, memory, energy, prompt, tool, and evaluation constraints in `plan.md`

**Checkpoint**: Constitution Check passes before implementation begins.

## Phase 2: Test and Evaluation Foundations

**Purpose**: Establish failing evidence for required behavior and guardrails.

- [ ] T006 [P] Add failing unit tests for pure behavior in `MirageTests/Unit/`
- [ ] T007 [P] Add failing integration tests for Apple framework and storage boundaries in `MirageTests/Integration/`
- [ ] T008 [P] Add failing accessibility/UI journey tests in `MirageUITests/Journeys/`
- [ ] T009 [P] For AI, add deterministic quality, fallback, safety, bias, injection, refusal, malformed-output, and tool-authorization evaluations in `MirageTests/AIEvaluation/`
- [ ] T010 [P] Add security tests for sensitive storage, logging, transport, deep links, authorization, and data deletion in `MirageTests/Security/`

**Checkpoint**: Required tests/evaluations fail for the expected missing behavior.

## Phase 3: Foundational Implementation

**Purpose**: Implement only shared prerequisites required by the user stories.

- [ ] T011 Create minimal feature structure at paths approved by `plan.md`
- [ ] T012 Implement typed errors, cancellation, and actor/MainActor isolation
- [ ] T013 Implement privacy-preserving storage, transport, and authorization primitives
- [ ] T014 For AI, implement availability checks, safe fallback states, serialized model access, bounded resources, and validated structured output
- [ ] T015 For tools, implement least-privilege allowlists, typed arguments, authorization, confirmation, bounded results, and audit-safe errors

**Checkpoint**: Shared prerequisites pass their focused tests without speculative abstractions.

## Phase 4: User Story 1 - [Title] (Priority: P1)

**Goal**: [Independent user value]

**Independent Test**: [Observable test]

- [ ] T016 [P] [US1] Add story-specific failing tests at exact planned paths
- [ ] T017 [US1] Implement the minimal Swift/SwiftUI behavior at exact planned paths
- [ ] T018 [US1] Add accessible loading, empty, unavailable, refusal, error, and recovery states
- [ ] T019 [US1] Make US1 tests and evaluations pass

**Checkpoint**: US1 is independently functional, accessible, safe, and testable.

## Phase 5: Additional User Stories

Repeat the User Story 1 structure for each remaining story. Continue IDs from
T020, preserve priority order, and include story-specific security, privacy, AI,
prompt, tool, accessibility, and fallback tasks.

## Final Phase: Hardening and Xcode MCP Verification

**Purpose**: Complete cross-cutting review and authoritative Xcode validation.

- [ ] T900 Review Swift strict concurrency, cancellation, Sendable boundaries, and architecture simplicity
- [ ] T901 [P] Review prompt trust boundaries, tool authorization, output validation, safety, bias, and misuse coverage
- [ ] T902 [P] Review Keychain/Data Protection, ATS, logs, pasteboard, deep links, files, biometrics, retention, deletion, and MASVS coverage
- [ ] T903 [P] Perform authorized Objection/Frida runtime checks on a designated test build when applicable
- [ ] T904 [P] Measure accessibility, launch, interaction, memory, energy, thermal, and degraded-state behavior
- [ ] T905 Validate Foundation Models, Core ML, Neural Engine, Metal, or MLX behavior on eligible physical devices when applicable
- [ ] T906 Use the Hermes-configured Xcode MCP server to browse every affected source area and verify target membership and diagnostics
- [ ] T907 Use the Hermes-configured Xcode MCP server to build and test every affected scheme and required destination
- [ ] T908 Use the Hermes-configured Xcode MCP server to launch the app and verify the critical user journey
- [ ] T909 Record fresh Xcode MCP evidence and unresolved limitations in the feature documentation

**Release Gate**: Do not substitute command-line Xcode tools. If Xcode MCP is
unavailable or fails, report a blocker and leave the feature unverified.

## Execution Rules

1. Research and Constitution Check precede implementation.
2. Tests/evaluations precede or accompany implementation and must prove the intended change.
3. Shared foundations precede dependent stories.
4. Stories are completed in priority order unless independent parallel work is safe.
5. Security, privacy, prompt safety, and accessibility are acceptance criteria, not polish.
6. Final Xcode MCP browsing/build/test/launch evidence is mandatory before completion.
7. Commit only coherent, reviewed, verified changes; never commit generated secrets or private test data.
