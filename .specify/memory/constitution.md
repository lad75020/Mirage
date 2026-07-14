<!--
Sync Impact Report
- Version change: unratified template → 1.0.0
- Committed history reviewed: cd0492b contained the original unfilled Spec Kit
  constitution template; no prior project principles existed to preserve.
- Principles established:
  - Native Swift and SwiftUI on iOS 26+
  - Modern Swift concurrency and simple architecture
  - On-device-first AI with measurable quality
  - Prompt safety and responsible AI
  - Security and privacy by design
  - Test-first quality, accessibility, and performance
  - Xcode MCP as the exclusive final project authority
- Sections added:
  - Platform, AI, Safety, and Security Constraints
  - Development Workflow and Quality Gates
- Sections removed: none; template placeholders were replaced.
- Dependent artifacts:
  - ✅ .specify/templates/plan-template.md
  - ✅ .specify/templates/spec-template.md
  - ✅ .specify/templates/tasks-template.md
  - ✅ specs/001-ios-app-scaffold/spec.md
  - ✅ README.md
  - ✅ AGENTS.md
  - ℹ .specify/templates/commands is not present in this Spec Kit layout.
- Follow-up:
  - project.yml currently declares an older deployment target. Its migration and
    regenerated Xcode project require a separate implementation change followed
    by final inspection and build verification through the Hermes-configured
    Xcode MCP server.
- Deferred placeholders: none.
-->

# Mirage Constitution

## Core Principles

### I. Native Swift and SwiftUI on iOS 26+

Mirage MUST target iOS 26.0 or newer and MUST use Swift and SwiftUI as its
primary implementation stack. New user interfaces MUST be implemented in
SwiftUI with Apple platform conventions, semantic system components, Dynamic
Type, VoiceOver, sufficient contrast, reduced-motion support, and adaptive
layouts. UIKit bridges MAY be introduced only when a required platform
capability has no practical SwiftUI equivalent; the plan MUST document the
boundary, ownership, tests, and removal path. Cross-platform abstractions,
legacy deployment compatibility, and third-party UI frameworks are out of scope
unless a specification explicitly justifies them.

Rationale: A single modern Apple-native stack keeps the product coherent,
accessible, maintainable, and aligned with iOS 26 capabilities.

### II. Modern Swift Concurrency and Simple Architecture

All production code MUST compile under Swift 6 strict concurrency checking.
Mutable shared state MUST be isolated with actors or an explicitly documented
executor; UI state and UI mutations MUST be `@MainActor`-isolated. Async work
MUST use structured concurrency, cancellation, and typed errors. Values crossing
isolation boundaries MUST be `Sendable` or safely isolated. Detached tasks,
unchecked sendability, unsafe pointers, and pre-concurrency escape hatches MUST
not be used without a written risk justification and focused tests.

Architecture MUST remain feature-oriented, dependency-light, and no more
abstract than the current requirements demand. Protocols, repositories,
coordinators, and packages MUST solve a demonstrated boundary rather than create
organizational indirection. Native frameworks are preferred over dependencies.

Rationale: Strict concurrency prevents data races, while simple architecture
preserves clarity and avoids speculative complexity.

### III. On-Device-First AI with Measurable Quality

AI features MUST select the smallest suitable Apple-platform framework and MUST
prefer on-device processing. Apple Foundation Models is the default for iOS 26+
text generation, summarization, classification, structured output, and bounded
tool use when the device is eligible. Core ML is preferred for custom vision,
audio, and predictive models. MLX Swift or llama.cpp MAY be used only when the
system model or Core ML cannot satisfy a documented requirement.

Every AI feature MUST:

- check model, asset, locale, and device eligibility before use;
- provide a useful non-AI or alternate-model fallback and explicit user-facing
  unavailable states;
- serialize model access through a concurrency-safe coordinator;
- bound context, output tokens, latency, memory, and energy use;
- prewarm only when it improves a measured interaction and does not waste
  resources;
- use typed structured output where feasible and validate every model result
  before it affects application state or invokes a capability;
- version models, prompts, schemas, evaluation data, and quality thresholds;
- include deterministic fixtures plus quality, safety, bias, regression, and
  fallback evaluations;
- keep private user content on device unless a specification explicitly defines
  informed consent, minimization, transport protection, retention, deletion,
  and a nonlocal fallback.

Core ML deliverables MUST use modern ML Program packages for new models and MUST
be converted from evaluation-mode source models. MLX-based features MUST keep
peak model memory below 60 percent of device RAM, set cache limits, clear caches
on unload or pressure, and be validated on physical hardware.

Rationale: AI must be private, bounded, reproducible, and useful even when the
preferred model is unavailable.

### IV. Prompt Safety and Responsible AI

Prompts, tool descriptions, schemas, and model instructions are security-
critical, versioned product artifacts. Trusted instructions MUST be separated
from untrusted user, retrieved, document, clipboard, network, and tool-result
content. Untrusted content MUST never be interpolated into system instructions.
Tool access MUST use explicit allowlists, least privilege, typed arguments,
authorization checks, bounded outputs, and user confirmation before destructive,
external, financial, privacy-sensitive, or irreversible effects.

Each AI feature MUST document its misuse cases and test prompt injection,
indirect injection, data exfiltration, unsafe tool selection, malformed output,
refusal handling, misinformation, representative bias, accessibility impact,
and guardrail false positives. Prompts MUST be concise, explicit about limits,
and structured for consistent results; hidden reasoning MUST not be requested,
persisted, logged, or exposed. User-visible AI output MUST communicate material
uncertainty and MUST not claim unsupported facts or completed actions.

Rationale: Prompt quality alone is insufficient; safe instruction boundaries,
validated outputs, and controlled capabilities are mandatory.

### V. Security and Privacy by Design

Every feature MUST apply data minimization, least privilege, secure defaults,
and explicit threat modeling. Secrets and credentials MUST use Keychain with an
appropriate accessibility class and MUST never be stored in UserDefaults,
source, prompts, logs, analytics, crash reports, or plaintext files. Sensitive
files MUST use iOS Data Protection and backup exclusion where appropriate.
Network traffic MUST use App Transport Security and system trust evaluation;
arbitrary-load exceptions or broad trust bypasses are prohibited. Authentication,
biometric checks, deep links, URL schemes, pasteboard access, file paths, and
model tools MUST enforce authorization at the point of use.

Security acceptance criteria MUST map relevant behavior to OWASP MASVS and MASTG.
Authorized runtime assessments SHOULD use Objection and Frida to inspect Keychain,
UserDefaults, SQLite/files, memory, logs, pasteboard, transport security, URL
handling, authentication, binary protections, and resilience controls. Dynamic
instrumentation MUST occur only on designated test builds and explicitly
authorized devices; it MUST NOT be used against production users or systems.
Client-side controls MUST not be treated as a substitute for server-side or
capability-level authorization.

Rationale: iOS sandboxing and model guardrails do not eliminate data exposure,
runtime tampering, or authorization risks.

### VI. Test-First Quality, Accessibility, and Performance

Changed behavior MUST have automated tests written before or alongside the
implementation and MUST demonstrate failure before the fix whenever practical.
Unit tests cover pure logic and state transitions; integration tests cover
framework, persistence, model, and tool boundaries; UI tests cover critical user
journeys and accessibility. AI behavior additionally requires evaluation suites
with fixed seeds or deterministic fixtures where supported.

Every feature MUST define measurable acceptance criteria for correctness,
accessibility, launch and interaction latency, memory, energy, offline behavior,
and failure recovery as applicable. Simulator tests are valid for UI and control
flow, but Foundation Models, Neural Engine, Metal, MLX, memory, thermal, and
performance claims MUST be validated on eligible physical devices. Flaky tests,
ignored failures, and unverifiable success claims are release blockers.

Rationale: Quality is proven by repeatable evidence across normal, degraded,
adversarial, and accessible use cases.

### VII. Xcode MCP Is the Exclusive Final Project Authority (NON-NEGOTIABLE)

All final project browsing, source membership inspection, target and scheme
inspection, diagnostics review, building, testing, and launch verification MUST
be performed through the Xcode MCP server configured directly in Hermes Agent.
An Xcode MCP server exposed through mcporter MUST NOT be used. Command-line
`xcodebuild`, `xcodegen`, direct project-file inspection, or another automation
layer MUST NOT substitute for the final gate.

File tools MAY edit documentation and source during implementation, and focused
non-Xcode checks MAY provide intermediate feedback. Before work is declared
complete, Xcode MCP MUST browse the affected project areas and return fresh
successful evidence from every affected scheme and required destination. If the
Hermes-configured Xcode MCP server is unavailable, lacks access, or fails, work
MUST stop at the verification gate and the blocker MUST be reported; no fallback
build or unverified success claim is permitted.

Rationale: A single authoritative Xcode integration prevents stale project
membership, scheme, destination, signing, and diagnostic assumptions.

## Platform, AI, Safety, and Security Constraints

- Supported platform: iOS 26.0+ only. Mac Catalyst, Designed for iPad on Mac,
  visionOS, watchOS, tvOS, and macOS targets require a constitutional amendment.
- Language and UI: Swift with SwiftUI; Swift 6 strict concurrency is mandatory.
- Apple Foundation Models integrations MUST retain system guardrails, check
  availability and locale, handle all generation errors, enforce one request per
  session, and monitor the shared input/output context budget.
- Tool-enabled models MUST register only the capabilities needed for the current
  task. Deterministic required data SHOULD be fetched before generation rather
  than exposed as an autonomous tool.
- New Core ML models MUST use ML Program packages and document conversion,
  compression, accuracy, deployment target, and compute-unit validation.
- Remote AI, analytics, or telemetry MUST be opt-in at the product level and
  requires a documented privacy purpose, data inventory, consent, retention,
  deletion, transport, and fallback policy.
- Dependencies MUST be actively maintained, license-compatible, privacy-reviewed,
  security-reviewed, and justified against a native implementation.
- No feature may weaken platform guardrails, transport trust, sandboxing,
  authorization, or runtime protections merely to simplify development.

## Development Workflow and Quality Gates

1. **Specify**: Every change starts with a testable Spec Kit specification. The
   specification declares platform impact, AI/ML behavior, prompt/tool risks,
   privacy and security impact, accessibility, degraded states, and measurable
   success criteria.
2. **Plan**: Research selects native APIs first and records architecture,
   concurrency isolation, model/framework choice, availability fallback,
   threat model, data lifecycle, evaluation strategy, and physical-device needs.
3. **Task**: Tasks are ordered test-first and include safety, bias, injection,
   security, accessibility, performance, and Xcode MCP verification work where
   applicable.
4. **Implement**: Keep changes minimal, feature-oriented, and reviewable. Do not
   mix unrelated refactors with feature behavior.
5. **Review**: Review Swift concurrency, privacy boundaries, prompt/tool trust,
   model lifecycle, OWASP MASVS coverage, dependency risk, accessibility, and
   complexity before the final gate.
6. **Verify**: Use the Hermes-configured Xcode MCP server to browse all affected
   files and target membership, then build and test every affected scheme. Use
   eligible physical devices for on-device AI, Metal, memory, energy, thermal,
   and performance claims.
7. **Release**: A release requires fresh Xcode MCP evidence, passing required
   tests/evaluations, no unresolved critical or high security findings, and
   documentation of user-visible AI limitations and privacy behavior.

## Governance

This constitution supersedes conflicting repository conventions, templates,
plans, tasks, and implementation shortcuts. Reviews MUST explicitly verify every
applicable principle. A deviation requires a written exception in the feature
plan that states scope, risk, owner, expiry, mitigation, and why a compliant
alternative is not viable; Principle VII cannot be waived by a feature plan.

Amendments require a documented rationale, a Sync Impact Report, propagation to
dependent Spec Kit templates and runtime guidance, and maintainer approval.
Versioning follows semantic versioning:

- MAJOR for removed or incompatibly redefined principles;
- MINOR for new principles or materially expanded obligations;
- PATCH for clarifications that do not change required behavior.

Compliance is reviewed during planning, after design, before merge, and before
release. When this constitution and a feature specification conflict, work MUST
pause until the constitution is amended or the specification is corrected.

**Version**: 1.0.0 | **Ratified**: 2026-07-14 | **Last Amended**: 2026-07-14
