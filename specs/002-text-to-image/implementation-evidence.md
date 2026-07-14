# Implementation evidence

Date: 2026-07-14  
Feature: `002-text-to-image`

## Implemented

- iOS 26.0 and Swift 6 XcodeGen configuration.
- Exact `haplollc/Mirage` package requirement at `0.2.0` and `MirageApp` module separation.
- Increased-memory and extended-virtual-addressing entitlements.
- No-collection privacy manifest and add-only Photos purpose text.
- Eight-family closed catalog with typed availability and one reviewed-but-disabled ERNIE candidate manifest.
- Application Support path containment, symlink defense, file protection, backup exclusion, size/hash verification, memory and protected-data gates.
- Actor-isolated Quick Start adapter with one retained engine, serial requests, request-scoped progress, callback cleanup, and PNG output.
- MainActor observable state orchestration, previous-result retention, prompt/output safety, accessible one-page UI, model selection, and Save flow.
- Unit, fake-integration, environment-gated real-model, UI journey, security, evaluation, and performance test sources.

## Focused non-Xcode checks

| Check | Result | Scope |
|---|---|---|
| XcodeGen generation | Passed | Intermediate project metadata only |
| Swift parser | 37/37 passed | Feature, unit-test, and UI-test syntax only |
| Swift 6 release semantic typecheck | Passed against a temporary Mirage 0.2.0 API stub | App sources; not package linkage |
| Swift 6 debug/test semantic typecheck | Passed against temporary Mirage 0.2.0 and XCTest API stubs | App, unit-test, and UI-test sources; not test execution |

The temporary API stub mirrored only public signatures inspected from Mirage 0.2.0. It is not build or runtime evidence and was removed after the check.

## Swift 6 ownership review

- UI-observable state is `@MainActor`.
- File resolution, inference, Photos deduplication, preview generation, and test doubles are actors where mutable state crosses tasks.
- Domain values and dependency protocols are `Sendable`.
- The native engine is retained only inside one actor and unloaded before model switches.
- The global Mirage progress callback is installed immediately before generation and cleared with `defer`.
- Progress carries request identity; stale updates are ignored on the MainActor.
- The package does not promise immediate native cancellation, so the UI intentionally offers no misleading Cancel button.
- Raw dependency errors, prompts, model paths, and generated data are neither logged nor surfaced.

## Xcode MCP evidence

**BLOCKED.** No Hermes-configured Xcode MCP tools are exposed in this session. Therefore the following are not claimed:

- Real package resolution or binary-artifact inspection.
- Source/resource/entitlement/Info.plist/scheme inspection in Xcode.
- Compiler diagnostics, unit tests, UI tests, build, install, or launch.
- iPhone/iPad visual and accessibility verification.

## Physical-device and model evidence

**BLOCKED.** No approved model/device pair is available. `evaluationApproved` remains false. See `model-provisioning.md` and `model-evaluation-results.md`.
