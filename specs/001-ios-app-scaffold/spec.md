# Feature Specification: iOS App Scaffold

**Feature Branch**: `001-ios-app-scaffold`

**Created**: 2026-07-14

**Status**: Implemented

**Input**: User description: "Create a new iOS-only application project called Mirage with Specify tools and prepare a single-page application scaffold with an Xcode project file."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Launch the Mirage app (Priority: P1)

As a user, I can install and launch Mirage on an iOS device and immediately see a clear, polished landing page that confirms the app is ready for future features.

**Why this priority**: A launchable application is the minimum viable foundation for all future product work.

**Independent Test**: Build and launch the app on a supported iOS simulator, then verify that the Mirage landing page appears without errors or additional setup.

**Acceptance Scenarios**:

1. **Given** a supported iOS device or simulator, **When** Mirage launches, **Then** a single landing page appears with the app name and readiness message.
2. **Given** the device uses light or dark appearance, **When** the landing page appears, **Then** all content remains legible and visually coherent.
3. **Given** the user has increased text size, **When** the landing page appears, **Then** its content remains readable without truncating essential information.

---

### User Story 2 - Continue development from the scaffold (Priority: P2)

As a developer, I can open a native Xcode project, select the Mirage scheme, and build the iOS app without first reconstructing project settings or source membership.

**Why this priority**: The scaffold must be usable as the base for subsequent Spec Kit features.

**Independent Test**: Open the generated Xcode project and perform a clean simulator build using the shared Mirage scheme.

**Acceptance Scenarios**:

1. **Given** the repository is checked out on a supported Mac, **When** the Xcode project is opened, **Then** an iOS application target and a shared Mirage scheme are available.
2. **Given** the Mirage scheme is selected, **When** a simulator build runs, **Then** the build completes successfully without signing credentials.
3. **Given** a future feature is added, **When** source files are placed in the application source group and the project is regenerated, **Then** they are included in the application target.

### Edge Cases

- The project must not expose macOS, Mac Catalyst, or visionOS as supported app destinations.
- The landing page must remain usable on compact iPhone screens and regular iPad screens.
- A simulator build must not require a paid developer account or a selected development team.
- The initial scaffold must not request permissions, collect data, or contact a network service.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The project MUST be named Mirage.
- **FR-002**: The repository MUST contain a native Xcode project file that can be opened directly.
- **FR-003**: The project MUST provide one iOS application target and a shared build scheme named Mirage.
- **FR-004**: The application MUST launch into exactly one primary landing page.
- **FR-005**: The landing page MUST identify the application as Mirage and indicate that the scaffold is ready for future features.
- **FR-006**: The landing page MUST support light appearance, dark appearance, Dynamic Type, and screen-reader navigation.
- **FR-007**: The application target MUST exclude Mac Catalyst, Designed for iPad on Mac, macOS, and visionOS destinations.
- **FR-008**: The scaffold MUST include at least one automated test that validates stable application metadata.
- **FR-009**: The project MUST be reproducible from a version-controlled project definition.
- **FR-010**: The repository MUST retain the Specify/Hermes project infrastructure and extension integrations for future specification-driven work.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can clone the repository, open the project, and start an iOS simulator build in under two minutes.
- **SC-002**: The application completes a simulator build with zero compile errors.
- **SC-003**: The automated scaffold test completes with zero failures.
- **SC-004**: All essential landing-page text remains readable at the largest standard accessibility text size on supported iPhone and iPad layouts.
- **SC-005**: A project inspection reports only iOS device and simulator platforms for the application target.

## Assumptions

- Mirage is a new product foundation; domain features, persistence, networking, analytics, and authentication are outside this initial scaffold.
- The initial bundle identifier is `com.lad75020.Mirage` and can be changed before distribution if needed.
- The minimum supported operating system is iOS 18.0.
- Both iPhone and iPad are supported because both run iOS/iPadOS application binaries; desktop and spatial platforms remain out of scope.
- Native platform frameworks are sufficient for the initial scaffold, so no third-party runtime dependency is required.
