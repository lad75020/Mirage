# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]

**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`

## Summary

[Summarize the user value, primary requirement, and selected technical approach.]

## Technical Context

**Language/Version**: Swift 6.x with strict concurrency checking

**UI Framework**: SwiftUI on iOS 26.0+

**Apple Frameworks**: [List native frameworks, including Foundation Models,
Core ML, Vision, Natural Language, or none]

**Third-Party Dependencies**: [None preferred; list and justify each dependency]

**Storage**: [SwiftData, Core Data, Keychain, protected files, UserDefaults for
non-sensitive settings, or none]

**Testing**: XCTest and/or Swift Testing; XCUITest for critical journeys

**Target Platform**: iOS 26.0+ on iPhone and iPad unless the spec narrows scope

**Project Type**: Native iOS application

**Performance Goals**: [Launch, interaction, inference, memory, energy, and
thermal targets relevant to this feature]

**AI/ML Strategy**: [No AI, Foundation Models, Core ML, MLX Swift, or llama.cpp;
include framework-selection rationale]

**Privacy/Security**: [Data inventory, trust boundaries, storage, transport,
authorization, retention, deletion, and MASVS controls]

**Scale/Scope**: [Screens, data volume, model size, context budget, and supported
device classes]

## Constitution Check

*GATE: Every item MUST pass before Phase 0 research and MUST be re-checked after
Phase 1 design.*

- [ ] Uses Swift, SwiftUI, Swift 6 strict concurrency, and iOS 26.0+.
- [ ] Uses native frameworks first and justifies every dependency and abstraction.
- [ ] Defines actor/MainActor isolation, Sendable boundaries, cancellation, and
      typed error handling.
- [ ] For AI: selects the smallest suitable on-device framework; checks device,
      model, asset, and locale availability; defines fallback UI; bounds tokens,
      memory, latency, and energy; and versions prompts/models/evaluations.
- [ ] For prompts/tools: separates trusted instructions from untrusted content,
      validates structured output, allowlists tools, and tests injection, misuse,
      bias, refusals, false positives, and unsafe actions.
- [ ] Defines data minimization, Keychain/Data Protection use, ATS, authorization,
      logging redaction, retention/deletion, and relevant OWASP MASVS/MASTG tests.
- [ ] Includes mandatory unit/integration/UI/evaluation tests plus accessibility,
      degraded-state, performance, and physical-device validation as applicable.
- [ ] Final project browsing, membership inspection, diagnostics, builds, tests,
      and launch verification use the Hermes-configured Xcode MCP server only.

## Project Structure

### Documentation for This Feature

```text
specs/[###-feature]/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
└── tasks.md
```

### Mirage Source Layout

```text
Mirage/
├── App/
├── Features/
│   └── [Feature]/
│       ├── Models/
│       ├── Services/
│       ├── ViewModels/
│       └── Views/
├── AI/
│   ├── Models/
│   ├── Prompts/
│   ├── Tools/
│   └── Evaluation/
├── Security/
├── Shared/
└── Resources/

MirageTests/
├── Unit/
├── Integration/
├── Security/
└── AIEvaluation/

MirageUITests/
└── Journeys/
```

Remove unused directories; do not create empty architectural layers.

**Structure Decision**: [Describe the minimal concrete paths used by this feature
and why each boundary is required.]

## AI, Prompt, and Security Design

**Availability and Fallback**: [Eligibility checks, user-visible states, and
non-AI/alternate behavior]

**Prompt Trust Boundaries**: [Trusted instructions, untrusted inputs, retrieval,
tool results, and output validation]

**Tool Authorization**: [Allowed capabilities, typed arguments, confirmation,
least privilege, and failure handling]

**Data Lifecycle**: [Collection, processing location, storage, transport,
retention, deletion, and logging]

**Threat Model and Runtime Assessment**: [Misuse cases, MASVS/MASTG controls, and
authorized Objection/Frida checks]

**Evaluation Plan**: [Quality thresholds, deterministic fixtures, regressions,
safety, bias, injection, fallback, accessibility, and physical-device tests]

## Xcode MCP Verification Plan

**Affected Schemes**: [List schemes]

**Destinations**: [Simulator and eligible physical devices]

**Required Evidence**: [Affected-file browse, target membership, diagnostics,
build, test, launch, and device-specific AI/performance results]

**Blocker Policy**: If the Hermes-configured Xcode MCP server is unavailable or
fails, stop and report the blocker. Do not substitute command-line build tools.

## Complexity Tracking

> Fill only when the Constitution Check has a justified violation.

| Violation | Why Required | Simpler Compliant Alternative Rejected Because | Owner | Expiry |
|---|---|---|---|---|
| [Describe] | [Need] | [Reason] | [Owner] | [Date] |
