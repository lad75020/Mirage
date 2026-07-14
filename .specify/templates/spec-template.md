# Feature Specification: [FEATURE NAME]

**Feature Branch**: `[###-feature-name]`

**Created**: [DATE]

**Status**: Draft

**Input**: User description: "$ARGUMENTS"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - [Brief Title] (Priority: P1)

[Describe the highest-value user journey in plain language.]

**Why this priority**: [Explain its independent user value.]

**Independent Test**: [Describe a complete, observable test of this story.]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]
2. **Given** [degraded or unavailable state], **When** [action], **Then** [safe fallback]

---

### User Story 2 - [Brief Title] (Priority: P2)

[Describe another independently valuable journey.]

**Why this priority**: [Explain its value.]

**Independent Test**: [Describe how to verify it independently.]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]

---

[Add further prioritized stories only when needed.]

### Edge Cases

- What happens when required device, model, locale, asset, network, storage, or
  permission capabilities are unavailable?
- How does the feature handle cancellation, interruption, backgrounding, memory
  pressure, malformed input, and partial output?
- How does the feature remain usable with VoiceOver, Dynamic Type, reduced
  motion, increased contrast, and compact layouts?
- How are prompt injection, unsafe tool requests, unauthorized access, data
  exposure, and guardrail false positives handled when applicable?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The application MUST [specific, testable capability].
- **FR-002**: Users MUST be able to [observable user action].
- **FR-003**: The application MUST [safe degraded or fallback behavior].
- **FR-004**: The application MUST [accessibility requirement].

### Constitutional Impact Assessment *(mandatory)*

Every subsection MUST state concrete requirements or explicitly state that it
has no impact and explain why.

#### Platform and UI

- **PLAT-001**: [iOS 26+, SwiftUI behavior, supported device classes, and
  accessibility impact.]

#### AI and Model Behavior

- **AI-001**: [Framework/use case, availability, fallback, quality threshold,
  context/output limits, memory/energy target, and physical-device needs.]

#### Prompt and Tool Safety

- **SAFE-001**: [Instruction boundary, untrusted inputs, output validation,
  tool allowlist, confirmations, misuse, injection, bias, refusal, and false-
  positive behavior.]

#### Security and Privacy

- **SEC-001**: [Data inventory, minimization, storage, transport, authorization,
  logging, retention, deletion, MASVS controls, and authorized runtime tests.]

### Key Entities *(include when the feature manages data)*

- **[Entity]**: [Meaning, lifecycle, sensitivity, ownership, and relationships.]

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: [User-focused correctness or completion metric.]
- **SC-002**: [Accessibility outcome.]
- **SC-003**: [Latency, memory, energy, or reliability outcome.]
- **SC-004**: [AI quality/safety/fallback outcome when applicable.]
- **SC-005**: [Security/privacy outcome when applicable.]

## Assumptions

- Mirage targets iOS 26.0+ and uses Swift, SwiftUI, and Swift 6 strict concurrency.
- Final project browsing, target inspection, diagnostics, building, testing, and
  launch verification use the Hermes-configured Xcode MCP server exclusively.
- [Feature-specific assumption.]

## Out of Scope

- [Explicitly excluded behavior, platform, data, model, or integration.]
