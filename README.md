# Mirage

Mirage is an iOS-only SwiftUI application scaffold prepared for specification-driven development with GitHub Spec Kit and Hermes.

## Open and build

1. Open `Mirage.xcodeproj` in Xcode 26 or newer.
2. Select the shared **Mirage** scheme.
3. Choose an iOS 18 or newer simulator.
4. Build and run with **⌘R**.

To regenerate the Xcode project after changing `project.yml`:

```sh
xcodegen generate
```

To build and test from the command line:

```sh
xcodebuild -project Mirage.xcodeproj -scheme Mirage \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build test
```

## Structure

- `Mirage/` — SwiftUI application sources and assets
- `MirageTests/` — unit tests
- `specs/` — Spec Kit feature artifacts
- `.specify/` — Specify scripts, templates, integrations, and extensions
- `project.yml` — version-controlled XcodeGen project definition

The initial app contains no persistence, network access, analytics, authentication, or permission requests.
