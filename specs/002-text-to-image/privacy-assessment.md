# Privacy assessment

Date: 2026-07-14  
Feature: `002-text-to-image`

## Data inventory

| Data | Purpose | Storage | Retention | Transport |
|---|---|---|---|---|
| Prompt | User-requested generation | Process memory | Current session/request only | None |
| Model selection | Select local model | Process memory | Current session | None |
| Local weights | On-device inference | Protected Application Support | Developer/user provisioned | None at runtime |
| Generated PNG | Display and optional save | Process memory; Photos only after Save | Current session or user-controlled Photos | None |
| Progress/error state | User feedback | Process memory | Current request | None |

## Runtime reconciliation

- `PrivacyInfo.xcprivacy` declares no tracking and no collected data.
- There is no analytics, telemetry, account, remote API, networking, UserDefaults, pasteboard, cache, or history implementation.
- `NSPhotoLibraryAddUsageDescription` describes explicit add-only saving.
- `PhotoLibrarySaver` calls Photos with `.addOnly`; it never requests read access.
- `Mirage.entitlements` contains only the two memory-related entitlements required by the local inference package.
- Generated PNG input is rejected if it contains GPS, EXIF, or TIFF metadata.
- Model files use complete-until-first-authentication protection and backup exclusion.
- User-visible errors are typed and redacted; raw model paths and dependency errors are not presented or logged.

## Retention and deletion

No automatic prompt/image persistence exists. Ending the process releases in-memory generation data. A user-saved image is governed by Photos and remains under user control. Provisioned model files are removed by deleting the app or its Application Support model folder.

## Open release blockers

- Network-observation and runtime storage inspection with authorized Objection/Frida are not run.
- Physical-device Photos permission/revocation testing is not run.
- Xcode MCP resource, entitlement, Info.plist, build, test, and launch inspection is not available in this session.
