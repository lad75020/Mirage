# Feature Specification: Single-Page Text-to-Image Generation

**Feature Branch**: `002-text-to-image`

**Created**: 2026-07-14

**Status**: Refined

**Input**: User description: "From a single page, select a text-to-image AI model, type an image prompt, start inference with a SEND button, display the resulting image above the prompt, and save it to the iPhone or iPad Photo Library. Users can download `jc-builds/Z-Image-Turbo-iOS`, `jc-builds/ERNIE-Image-Turbo-iOS`, `jc-builds/Chroma1-HD-iOS`, or another compatible Hugging Face model reference into a dedicated Files-accessible folder. Models load lazily when selected and unload after every generation."

**Refined**: 2026-07-14 — Replaced the fixed pre-provisioned catalog with Hugging Face model downloads, custom public model references, Files-accessible model storage, selection-triggered lazy loading, and mandatory post-generation unloading.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Generate an Image from One Page (Priority: P1)

A user opens Mirage, selects one compatible model that has been fully downloaded to the device, enters a description of the image or photo they want, and presses **SEND**. Mirage loads the selected model lazily, presents progress without leaving the page, replaces the result area above the prompt with the generated image when inference succeeds, and unloads the model when the attempt ends.

**Why this priority**: This is the product's primary value and delivers a complete prompt-to-image experience.

**Independent Test**: On a supported device with at least one fully downloaded compatible model, select the model, verify that lazy loading begins only after selection, enter a valid prompt, press **SEND**, and verify that the same page shows progress followed by the generated image above the unchanged prompt and that model memory is released after the attempt.

**Acceptance Scenarios**:

1. **Given** the page has at least one available model and a valid prompt, **When** the user selects a model and presses **SEND**, **Then** generation starts once, progress is announced, and model and prompt controls cannot start a competing request.
2. **Given** generation completes successfully, **When** the result is ready, **Then** the generated image appears in the result area above the prompt and the selected model and prompt remain visible.
3. **Given** the prompt is empty or contains only whitespace, **When** the page is displayed, **Then** **SEND** is unavailable and the page explains that an image description is required.
4. **Given** no fully downloaded compatible model can run on the device, **When** the page appears, **Then** generation is unavailable and the page explains whether a model must be downloaded, repaired, or replaced without hiding the model list or crashing.
5. **Given** generation fails or the selected model refuses the request, **When** the operation ends, **Then** the page shows an actionable, nonjudgmental message, keeps the prompt for editing or retry, and preserves any previously successful image.

---

### User Story 2 - Download and Choose a Hugging Face Model (Priority: P2)

~~A user reviews Mirage's fixed, app-curated model catalog and chooses the model that will produce the next image.~~ This fixed-only behavior is superseded by downloadable and user-entered Hugging Face model references.

A user can download one of Mirage's featured Hugging Face repositories—`jc-builds/Z-Image-Turbo-iOS`, `jc-builds/ERNIE-Image-Turbo-iOS`, or `jc-builds/Chroma1-HD-iOS`—or enter another public Hugging Face model reference. Mirage downloads each repository into its own dedicated folder visible in the Files app, communicates download and compatibility state, and allows a fully downloaded compatible model to be selected for lazy loading.

**Why this priority**: On-device generation requires users to acquire and manage large model assets safely before the primary prompt-to-image experience can work.

**Independent Test**: Download one featured public repository and one compatible custom public repository reference, verify that each appears in a separate Files-accessible model folder, select each downloaded model in turn, and verify lazy load, exact model identity, compatibility handling, and cleanup after generation.

**Acceptance Scenarios**:

1. ~~**Given** multiple fixed available models, **When** the user selects a different model, **Then** the new choice is visibly and accessibly selected for the next generation.~~ Superseded by downloaded-model selection and lazy-loading behavior below.
2. ~~**Given** a fixed catalog entry is unavailable, **When** the user reviews the list, **Then** that entry remains identifiable, cannot be selected, and includes a concise reason or compatibility status.~~ Superseded by download and compatibility states below.
3. **Given** generation is running, **When** the user attempts to change models, **Then** the current request continues with its original model and no ambiguous model change is accepted.
4. **Given** the featured model list is displayed, **When** the user chooses one of the three featured repositories to download, **Then** Mirage shows expected storage impact, obtains explicit confirmation, downloads with progress, and does not mark the model usable until the complete snapshot passes integrity and compatibility validation.
5. **Given** the user enters a syntactically valid public Hugging Face repository reference or model URL, **When** they confirm the download, **Then** Mirage normalizes the reference, resolves an immutable repository revision, and applies the same download, storage, integrity, and compatibility rules used for featured models.
6. **Given** a reference is malformed, private, gated, unreachable, incompatible, incomplete, or unsafe to extract, **When** validation or download runs, **Then** Mirage presents a concise recoverable status and never loads partial or untrusted executable content.
7. **Given** a model download completes, **When** the user opens the Files app, **Then** the model exists in its own stable subfolder inside Mirage's dedicated model folder without exposing prompts or generated images.
8. **Given** a fully downloaded compatible model is not loaded, **When** the user selects it, **Then** Mirage begins one lazy load, exposes loading progress, and enables generation only after the model is ready.
9. **Given** an image generation attempt succeeds or fails after native inference begins, **When** the attempt finishes, **Then** Mirage unloads the model and releases its inference memory before accepting another generation or model selection.

---

### User Story 3 - Save the Generated Image (Priority: P3)

After a successful generation, the user saves the displayed image to the iPhone or iPad Photo Library. Mirage requests only the permission needed to add the image, only when the user chooses to save, and reports whether the save succeeded.

**Why this priority**: Saving lets users keep and use the generated result outside Mirage without introducing an in-app gallery.

**Independent Test**: Generate an image, press **Save**, exercise both granted and denied Photo Library permission states, and verify that the displayed image remains available with a correct success or recovery message.

**Acceptance Scenarios**:

1. **Given** a generated image is displayed and Photo Library add access is granted, **When** the user presses **Save**, **Then** that exact displayed image is added once and the page confirms success.
2. **Given** Photo Library permission has not been requested, **When** the user presses **Save**, **Then** Mirage requests only add access and continues the save if access is granted.
3. **Given** Photo Library access is denied or restricted, **When** the user presses **Save**, **Then** no save is claimed, the image remains visible, and the page explains how the user can resolve the permission state.
4. **Given** no generated image exists, **When** the page is displayed, **Then** no active save action is presented.

### Edge Cases

- The prompt reaches the maximum supported length or contains only line breaks, emoji, right-to-left text, or unsupported language content.
- The selected model becomes unavailable between selection and **SEND**, or its assets are missing, still preparing, corrupted, or incompatible with the device.
- The user taps **SEND** repeatedly, changes orientation, backgrounds the app, or the app receives memory pressure during inference.
- Inference returns an invalid, empty, partial, or unsupported image result.
- A safety guardrail rejects a prompt, including a false positive; the message must not reveal hidden instructions or internal model details.
- A new generation succeeds after a previous result, or fails while a previous result is still displayed.
- The generated image has an extreme aspect ratio or resolution and must remain fully inspectable without pushing prompt controls off the single page.
- Photo Library permission changes outside Mirage, storage is unavailable, or saving fails after permission is granted.
- VoiceOver, Dynamic Type, reduced motion, increased contrast, keyboard input, and compact iPhone or wide iPad layouts are active.
- A featured or custom Hugging Face repository is renamed, deleted, gated, rate-limited, changes while downloading, or resolves to a revision with unsupported files.
- A download is interrupted by backgrounding, connectivity loss, low battery, low storage, Files edits, app termination, or device restart; partial data must never be treated as a complete model.
- A repository contains absolute paths, traversal components, symlinks, duplicate/case-colliding paths, oversized files, executable payloads, or a model architecture unsupported by the installed Mirage package.
- The user selects a downloaded model while another model is loading, Files changes or removes a selected model, or memory pressure occurs during load or inference.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Mirage MUST provide the complete model-selection, prompt-entry, generation, result, and save experience on one adaptive page.
- **FR-002**: ~~Mirage MUST present a fixed eight-family catalog, and users MUST NOT add arbitrary models in this feature.~~ Superseded because the refined feature explicitly supports three featured downloads and user-entered Hugging Face model references.
- **FR-003**: Every featured or downloaded model option MUST have a stable repository identity, user-facing name, resolved revision, clear selected state, download state, compatibility state, and load state.
- **FR-004**: Exactly one fully downloaded, integrity-checked, compatible model MUST be selected and loaded before generation can begin. A missing, partial, invalid, incompatible, or currently loading model MUST NOT start inference and MUST explain its status.
- **FR-005**: Users MUST be able to enter and edit a prompt of 1 to 1,000 visible characters describing the desired image or photo.
- **FR-006**: **SEND** MUST be unavailable when the prompt is blank, no model is selected, the selected model is not fully downloaded and loaded, model loading is in progress, or inference is already running.
- **FR-007**: Pressing **SEND** MUST start exactly one generation request using the selected model and current prompt.
- **FR-008**: The page MUST provide visible and accessible model download, model loading, and generation progress appropriate to each operation and MUST prevent competing load or inference requests.
- **FR-009**: On success, Mirage MUST display the complete generated image in a result area above the prompt while retaining the prompt and selected model on the page.
- **FR-010**: A subsequent successful generation MUST replace the prior displayed result. A failed or refused generation MUST preserve the prior successful result, if any.
- **FR-011**: Generation errors, model unavailability, safety refusals, interruptions, and invalid outputs MUST produce concise recovery guidance without exposing hidden prompts, model internals, or sensitive diagnostics.
- **FR-012**: Mirage MUST expose a save action only when a valid generated image is displayed.
- **FR-013**: Saving MUST be initiated explicitly by the user, MUST request only Photo Library add access when required, and MUST never happen automatically.
- **FR-014**: On successful save, Mirage MUST add the exact displayed image once and present a confirmation. On failure or denied access, Mirage MUST not claim success and MUST keep the image visible.
- **FR-015**: Mirage MUST NOT automatically create an in-app generation history or persist prompts and generated images after the current app session unless the user saves the image to the Photo Library. Downloaded model assets and their non-sensitive source, revision, integrity, and compatibility metadata are the only new feature data intentionally persisted.
- **FR-016**: The saved image MUST NOT contain the prompt, model choice, or other private generation context in embedded metadata unless a later specification explicitly adds informed user control.
- **FR-017**: All controls, states, progress, errors, generated-image descriptions, and confirmations MUST be operable and understandable with VoiceOver, Dynamic Type, reduced motion, increased contrast, external keyboards, and supported iPhone/iPad layouts.
- **FR-018**: Mirage MUST offer these featured Hugging Face repository references exactly: `jc-builds/Z-Image-Turbo-iOS`, `jc-builds/ERNIE-Image-Turbo-iOS`, and `jc-builds/Chroma1-HD-iOS`.
- **FR-019**: Mirage MUST allow the user to enter a standard public Hugging Face `owner/repository` reference or full `huggingface.co` model URL, normalize it to a canonical repository identity, and reject malformed or non-Hugging-Face download sources.
- **FR-020**: Before network transfer, Mirage MUST show the repository identity and available size/license information, require an explicit download action, resolve and persist an immutable revision, and communicate that custom models may be incompatible or subject to third-party terms.
- **FR-021**: Model downloads MUST use HTTPS with server identity validation, expose determinate progress when available, support safe cancellation and recovery from interruption, verify the downloaded snapshot before activation, and never treat partial files as a usable model.
- **FR-022**: Mirage MUST store each downloaded model in a separate stable subfolder under a dedicated Mirage model folder accessible through the Files app. Model folders MUST NOT contain prompts, generated images, Photo Library data, credentials, or analytics identifiers.
- **FR-023**: Download and extraction MUST enforce destination containment, safe filenames, declared and available storage limits, immutable-revision consistency, expected file integrity where provided, and rejection of traversal, escaping links, executable code, and unsupported assets.
- **FR-024**: Merely listing or downloading a model MUST NOT load it into inference memory. Selecting a fully downloaded compatible model MUST trigger one lazy load, with clear progress and a recoverable failure state.
- **FR-025**: After every native image-generation attempt ends—success, failure, refusal after inference, or interruption—Mirage MUST unload the active model, release its engine and model memory, retain only the logical selection and allowed generated image, and verify cleanup before another load or generation begins.
- **FR-026**: A custom repository MAY be downloaded even when compatibility cannot be established in advance, but it MUST remain unselectable for generation until local validation confirms that its files and architecture are supported by the installed Mirage package and current device.

### Constitutional Impact Assessment *(mandatory)*

#### Platform and UI

- **PLAT-001**: The feature MUST support iOS 26.0+ on iPhone and iPad as a single adaptive page; desktop and spatial platforms remain out of scope.
- **PLAT-002**: The generated image MUST remain above the prompt at every supported size, use available space without distortion or clipping, and keep model, prompt, **SEND**, and save controls reachable.
- **PLAT-003**: Selection, disabled, progress, refusal, error, result, save, and permission states MUST have semantic labels and MUST not rely on color, animation, or position alone.

#### AI and Model Behavior

- **AI-001**: Image generation MUST run on device for this feature; prompts and generated pixels MUST NOT be sent to a remote service.
- **AI-002**: Featured repository revisions, licenses, supported devices, expected storage/resource limits, and measurable image-quality thresholds MUST be defined during planning and versioned with the feature. Custom repository revisions MUST be recorded at download time and clearly identified as user-supplied, third-party assets.
- **AI-003**: Mirage MUST check repository snapshot integrity, package compatibility, device eligibility, model files, and available storage/memory before selection, load, and generation, with explicit download, unavailable, repair, and retry states.
- **AI-004**: Only one model load and one inference MAY be active at a time. Generation MUST have bounded prompt size, output count of one image per request, documented time/memory/energy/thermal budgets, and deterministic engine teardown after every attempt.
- **AI-005**: Each featured model revision enabled for release MUST pass repeatable quality, safety, demographic-bias, regression, invalid-output, interruption, memory-pressure, unload, and availability-fallback evaluations. Custom models MUST pass structural/package/device validation and the same runtime output-safety controls, and MUST never execute repository code.

#### Prompt and Tool Safety

- **SAFE-001**: User prompt text MUST be treated solely as untrusted image-generation content and MUST never modify trusted application instructions or grant access to application capabilities.
- **SAFE-002**: The image-generation path MUST expose no autonomous tools. Saving to Photos MUST occur only from the explicit user save action after a valid image is displayed.
- **SAFE-003**: Model and platform safety guardrails MUST remain enabled. Harmful or disallowed prompts MUST result in a safe refusal; false positives MUST be recoverable by editing and retrying without disclosing hidden instructions.
- **SAFE-004**: Safety evaluation MUST cover violence, hate, sexual content, illegal activity, impersonation, misinformation, private-data reproduction, prompt injection, jailbreak attempts, stereotypes, representative bias, and adversarially malformed prompts.
- **SAFE-005**: User-facing output MUST identify the displayed result as AI-generated and MUST not claim that the image depicts a real event or person merely because the prompt requests one.
- **SAFE-006**: Hugging Face repository references, filenames, metadata, and model contents MUST be treated as untrusted data and MUST never become shell commands, executable code, dynamic libraries, trusted application instructions, or unrestricted file paths.

#### Security and Privacy

- **SEC-001**: Prompt text, selected model, generated image, custom repository history, and Photo Library permission outcome are private user data and MUST be minimized and excluded from analytics and diagnostic logs. Prompts and generated pixels MUST remain on device; only the repository/revision and protocol metadata necessary for an explicit model download MAY be sent to Hugging Face.
- **SEC-002**: Mirage MUST request Photo Library add access only after the user presses **Save** and MUST operate without read access to the user's library.
- **SEC-003**: The feature MUST perform no tracking, advertising, account linking, remote inference, or telemetry. Network access MUST be limited to explicit model downloads from canonical Hugging Face endpoints, and privacy declarations and App Store disclosures MUST match that behavior.
- **SEC-004**: Temporary inference data MUST be released after replacement, session end, interruption, or memory pressure; the model engine and model memory MUST additionally be released after every generation attempt. No prompt, result, credential, or unsafe temporary download artifact may be written to the Files-accessible model folder.
- **SEC-005**: Security acceptance tests MUST cover permission denial/revocation, sensitive logging, temporary-file handling, image metadata, interruption, memory inspection on an authorized test device, and applicable OWASP MASVS privacy and storage controls.
- **SEC-006**: Security acceptance tests MUST cover malicious repository references and snapshots, redirect/domain validation, immutable-revision consistency, archive bombs, path traversal, symlink escape, executable payloads, case collisions, partial-download activation, Files tampering, low storage, integrity failures, and cleanup of download and inference memory.

### Key Entities

- **Model Option**: A featured or user-entered Hugging Face repository with canonical identity, resolved immutable revision, user-facing name, download state, local Files folder, integrity/compatibility status, selection state, and transient load state.
- **Model Download**: One explicit transfer of a repository snapshot into a staging location, with expected size when known, progress, resolved revision, validation outcome, and atomic promotion into a dedicated Files-accessible model folder.
- **Generation Request**: The selected model and validated prompt for one inference attempt, plus transient progress and outcome state. It is private and session-scoped.
- **Generated Image**: One validated image result associated with its generation request. It remains transient unless the user explicitly saves it.
- **Save Outcome**: The success, denial, restriction, or failure state of one explicit Photo Library save attempt; it does not grant permission to read the library.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In usability testing, at least 95% of participants can download a featured model, find it in the Files app, select and load it, enter a prompt, start generation, identify the result above the prompt, and find the save action without instruction.
- **SC-002**: Every accepted **SEND** action presents visible and accessible progress within 500 milliseconds and starts no more than one generation request.
- **SC-003**: In 100% of successful test generations, exactly one complete image appears above the prompt and the selected model and prompt remain available for review or editing.
- **SC-004**: Across at least 20 consecutive generation attempts per enabled featured model on each supported physical-device class, Mirage completes or presents a recoverable error without crash, indefinite progress, loss of the previous successful image, or residual loaded model after each attempt.
- **SC-005**: In 100% of permission test cases, Mirage saves only after explicit action, accurately reports success or failure, remains usable after denial or revocation, and never requests Photo Library read access.
- **SC-006**: VoiceOver users can identify the selected model, prompt, **SEND** availability, progress, generated image, save action, and save outcome in the intended reading order with no unlabeled interactive element.
- **SC-007**: Privacy tests confirm that no prompt or generated image leaves the device, no generation data is automatically persisted, Files-accessible model folders contain no user-generation data, and saved images contain no prompt or model-selection metadata.
- **SC-008**: Every enabled featured model revision meets approved quality, safety, bias, storage, memory, energy, thermal, unload, and fallback thresholds. Every custom model is blocked unless compatibility and integrity checks pass, remains subject to the same prompt/output safety controls, and leaves no model loaded after generation.
- **SC-009**: In interruption, corruption, low-storage, and malicious-snapshot tests, 100% of incomplete or unsafe downloads remain non-selectable, no extracted path escapes the dedicated model folder, and retry or cleanup is recoverable without reinstalling the app.
- **SC-010**: Instrumented physical-device tests confirm that model loading begins only after explicit selection and that the model engine and model-associated memory are released after 100% of completed or failed native generation attempts before the next operation is accepted.

## Assumptions

- Mirage targets iOS 26.0+ and uses Swift, SwiftUI, and Swift 6 strict concurrency.
- Final project browsing, target inspection, diagnostics, building, testing, and launch verification use the Hermes-configured Xcode MCP server exclusively.
- The app uses the latest reviewed stable haplollc/Mirage Swift package release for inference and follows that package's Quick Start integration contract. Featured downloads are `jc-builds/Z-Image-Turbo-iOS`, `jc-builds/ERNIE-Image-Turbo-iOS`, and `jc-builds/Chroma1-HD-iOS`; their exact immutable revisions, files, licenses, hashes where available, and enabled-device matrix are selected during propagation/planning based on compatibility, quality, safety, and resource evidence.
- Custom model entry initially supports public, unauthenticated Hugging Face repositories. Private/gated repositories and credential storage are out of scope unless a later specification explicitly defines secure authentication.
- Downloaded model snapshots persist on device in Mirage's dedicated Files-accessible model folder until the user removes them through supported file management; model engines and inference memory never persist between generation attempts.
- ~~The first available catalog model may be selected by default.~~ Superseded: Mirage MUST wait for an explicit user selection before lazy-loading any downloaded model; the logical selection remains visible after post-generation unloading.
- This version generates one image per request and allows only one active inference at a time.
- The result is session-scoped and is not restored after the app terminates unless the user saved it to Photos.
- Photo Library saving is available through the system's add-only permission flow and does not require browsing or reading the library.

## Out of Scope

- ~~Adding or downloading models from the UI.~~ Superseded by featured and custom public Hugging Face downloads. Importing from non-Hugging-Face sources, training, fine-tuning, and in-app model deletion remain out of scope.
- Remote or cloud image generation, Hugging Face account authentication, private/gated repository credentials, subscriptions, payments, analytics, advertising, or telemetry. Explicit model-file downloads from public canonical Hugging Face endpoints are in scope and MUST NOT include prompt or generation data.
- Multi-image batches, seeds, negative prompts, advanced sampling controls, image-to-image editing, inpainting, outpainting, upscaling, or post-processing.
- An in-app gallery, generation history, prompt library, social sharing, community feed, or automatic cloud backup.
- Reading, browsing, editing, or deleting existing Photo Library content.
