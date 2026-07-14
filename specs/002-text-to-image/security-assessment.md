# Security assessment

Date: 2026-07-14

## Static controls implemented

- Closed model catalog and exact package version.
- Application Support root containment and symlink escape rejection.
- Extension, byte-count, SHA-256, license, evaluation, protected-data, and available-memory gates.
- File backup exclusion and data protection.
- No remote transport, telemetry, UserDefaults, pasteboard, temporary generation files, prompt logs, or history.
- Versioned prompt policy and fail-closed on-device output sensitivity analysis.
- PNG structural validation and metadata checks before Photos writes.
- Photos add-only authorization requested only from explicit Save.
- Typed/redacted errors and no secret/API-key requirement.

## Automated source coverage

- `ModelFileResolverTests`
- `ImageSafetyServiceTests`
- `ModelAssetSecurityTests`
- `ImageGenerationSecurityTests`
- `PhotoLibrarySaverTests`
- `AIEvaluation/*`

These sources have not been executed by Xcode MCP in this session.

## Runtime checks

| Check | Result |
|---|---|
| Objection/Frida storage inspection | **NOT RUN** |
| Prompt/PNG memory lifetime | **NOT RUN** |
| Logs/UserDefaults/pasteboard/files | **NOT RUN** |
| Network traffic under inference/save | **NOT RUN** |
| Photos permission revocation | **NOT RUN** |
| Entitlement exposure | **NOT RUN** |

Runtime checks require an explicitly authorized designated test build and physical device. No claims are inferred from static inspection.
