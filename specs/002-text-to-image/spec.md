# Feature Specification: Single-Page Text-to-Image Generation

**Feature Branch**: `002-text-to-image`

**Created**: 2026-07-14

**Status**: Draft

**Input**: User description: "From a single page, select a text-to-image AI model from a fixed list, type an image prompt, start inference with a SEND button, display the resulting image above the prompt, and save it to the iPhone or iPad Photo Library."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Generate an Image from One Page (Priority: P1)

A user opens Mirage, selects one available model from the fixed model list, enters a description of the image or photo they want, and presses **SEND**. Mirage presents progress without leaving the page and replaces the result area above the prompt with the generated image when inference succeeds.

**Why this priority**: This is the product's primary value and delivers a complete prompt-to-image experience.

**Independent Test**: On a supported device with at least one available model, select a model, enter a valid prompt, press **SEND**, and verify that the same page shows progress followed by the generated image above the unchanged prompt.

**Acceptance Scenarios**:

1. **Given** the page has at least one available model and a valid prompt, **When** the user selects a model and presses **SEND**, **Then** generation starts once, progress is announced, and model and prompt controls cannot start a competing request.
2. **Given** generation completes successfully, **When** the result is ready, **Then** the generated image appears in the result area above the prompt and the selected model and prompt remain visible.
3. **Given** the prompt is empty or contains only whitespace, **When** the page is displayed, **Then** **SEND** is unavailable and the page explains that an image description is required.
4. **Given** no model can run on the device, **When** the page appears, **Then** generation is unavailable and the page explains why without hiding the model list or crashing.
5. **Given** generation fails or the selected model refuses the request, **When** the operation ends, **Then** the page shows an actionable, nonjudgmental message, keeps the prompt for editing or retry, and preserves any previously successful image.

---

### User Story 2 - Choose a Model from the Fixed Catalog (Priority: P2)

A user reviews Mirage's fixed, app-curated model catalog and chooses the model that will produce the next image. Each option clearly communicates its display name and whether it is currently available on the device.

**Why this priority**: Model choice gives users meaningful control over the output while keeping the experience predictable and bounded.

**Independent Test**: With two catalog entries, select each available model in turn and verify that exactly one model is selected and that the next generation request identifies the chosen model.

**Acceptance Scenarios**:

1. **Given** multiple available models, **When** the user selects a different model, **Then** the new choice is visibly and accessibly selected for the next generation.
2. **Given** a fixed catalog entry is unavailable, **When** the user reviews the list, **Then** that entry remains identifiable, cannot be selected, and includes a concise reason or compatibility status.
3. **Given** generation is running, **When** the user attempts to change models, **Then** the current request continues with its original model and no ambiguous model change is accepted.

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

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Mirage MUST provide the complete model-selection, prompt-entry, generation, result, and save experience on one adaptive page.
- **FR-002**: Mirage MUST present this fixed, app-curated catalog from the haplollc/Mirage Supported model families documentation: Stable Diffusion 1.x / 2.x, SDXL / SDXL-Turbo, SD3 / SD3.5, FLUX.1 schnell / dev, Chroma1-HD, Qwen-Image, ERNIE-Image-Turbo, and Z-Image-Turbo. Users MUST NOT add arbitrary models in this feature.
- **FR-003**: Every model option MUST have a stable display name, a clear selected state, and a current availability state.
- **FR-004**: Exactly one available model MUST be selected before generation can begin. An unavailable model MUST NOT be selectable and MUST explain its status.
- **FR-005**: Users MUST be able to enter and edit a prompt of 1 to 1,000 visible characters describing the desired image or photo.
- **FR-006**: **SEND** MUST be unavailable when the prompt is blank, no model is selected, the selected model is unavailable, or inference is already running.
- **FR-007**: Pressing **SEND** MUST start exactly one generation request using the selected model and current prompt.
- **FR-008**: The page MUST acknowledge the generation request immediately with visible and accessible progress and MUST prevent competing inference requests.
- **FR-009**: On success, Mirage MUST display the complete generated image in a result area above the prompt while retaining the prompt and selected model on the page.
- **FR-010**: A subsequent successful generation MUST replace the prior displayed result. A failed or refused generation MUST preserve the prior successful result, if any.
- **FR-011**: Generation errors, model unavailability, safety refusals, interruptions, and invalid outputs MUST produce concise recovery guidance without exposing hidden prompts, model internals, or sensitive diagnostics.
- **FR-012**: Mirage MUST expose a save action only when a valid generated image is displayed.
- **FR-013**: Saving MUST be initiated explicitly by the user, MUST request only Photo Library add access when required, and MUST never happen automatically.
- **FR-014**: On successful save, Mirage MUST add the exact displayed image once and present a confirmation. On failure or denied access, Mirage MUST not claim success and MUST keep the image visible.
- **FR-015**: Mirage MUST NOT automatically create an in-app generation history or persist prompts and generated images after the current app session unless the user saves the image to the Photo Library.
- **FR-016**: The saved image MUST NOT contain the prompt, model choice, or other private generation context in embedded metadata unless a later specification explicitly adds informed user control.
- **FR-017**: All controls, states, progress, errors, generated-image descriptions, and confirmations MUST be operable and understandable with VoiceOver, Dynamic Type, reduced motion, increased contrast, external keyboards, and supported iPhone/iPad layouts.

### Constitutional Impact Assessment *(mandatory)*

#### Platform and UI

- **PLAT-001**: The feature MUST support iOS 26.0+ on iPhone and iPad as a single adaptive page; desktop and spatial platforms remain out of scope.
- **PLAT-002**: The generated image MUST remain above the prompt at every supported size, use available space without distortion or clipping, and keep model, prompt, **SEND**, and save controls reachable.
- **PLAT-003**: Selection, disabled, progress, refusal, error, result, save, and permission states MUST have semantic labels and MUST not rely on color, animation, or position alone.

#### AI and Model Behavior

- **AI-001**: Image generation MUST run on device for this feature; prompts and generated pixels MUST NOT be sent to a remote service.
- **AI-002**: The fixed model catalog, model versions, licenses, supported devices, expected resource limits, and measurable image-quality thresholds MUST be defined during planning and versioned with the feature.
- **AI-003**: Mirage MUST check device, model, and asset eligibility before selection and immediately before generation, and MUST provide explicit unavailable and retry states.
- **AI-004**: Only one inference MAY run at a time. Generation MUST have bounded prompt size, output count of one image per request, and documented time, memory, energy, and thermal budgets verified on eligible physical devices.
- **AI-005**: Each catalog model MUST pass repeatable quality, safety, demographic-bias, regression, invalid-output, interruption, memory-pressure, and availability-fallback evaluations before release.

#### Prompt and Tool Safety

- **SAFE-001**: User prompt text MUST be treated solely as untrusted image-generation content and MUST never modify trusted application instructions or grant access to application capabilities.
- **SAFE-002**: The image-generation path MUST expose no autonomous tools. Saving to Photos MUST occur only from the explicit user save action after a valid image is displayed.
- **SAFE-003**: Model and platform safety guardrails MUST remain enabled. Harmful or disallowed prompts MUST result in a safe refusal; false positives MUST be recoverable by editing and retrying without disclosing hidden instructions.
- **SAFE-004**: Safety evaluation MUST cover violence, hate, sexual content, illegal activity, impersonation, misinformation, private-data reproduction, prompt injection, jailbreak attempts, stereotypes, representative bias, and adversarially malformed prompts.
- **SAFE-005**: User-facing output MUST identify the displayed result as AI-generated and MUST not claim that the image depicts a real event or person merely because the prompt requests one.

#### Security and Privacy

- **SEC-001**: Prompt text, selected model, generated image, and Photo Library permission outcome are private user data and MUST be minimized, excluded from analytics and diagnostic logs, and kept on device.
- **SEC-002**: Mirage MUST request Photo Library add access only after the user presses **Save** and MUST operate without read access to the user's library.
- **SEC-003**: The feature MUST perform no tracking, advertising, account linking, or remote telemetry and MUST keep privacy declarations and App Store disclosures consistent with actual behavior.
- **SEC-004**: Temporary inference data MUST be released after replacement, session end, cancellation, or memory pressure and MUST not be written to unprotected shared storage.
- **SEC-005**: Security acceptance tests MUST cover permission denial/revocation, sensitive logging, temporary-file handling, image metadata, interruption, memory inspection on an authorized test device, and applicable OWASP MASVS privacy and storage controls.

### Key Entities

- **Model Option**: A fixed catalog entry with stable identity, user-facing name, version, availability, compatibility status, and selection state. It contains no user data.
- **Generation Request**: The selected model and validated prompt for one inference attempt, plus transient progress and outcome state. It is private and session-scoped.
- **Generated Image**: One validated image result associated with its generation request. It remains transient unless the user explicitly saves it.
- **Save Outcome**: The success, denial, restriction, or failure state of one explicit Photo Library save attempt; it does not grant permission to read the library.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In usability testing, at least 95% of participants can select a model, enter a prompt, start generation, identify the result above the prompt, and find the save action without instruction.
- **SC-002**: Every accepted **SEND** action presents visible and accessible progress within 500 milliseconds and starts no more than one generation request.
- **SC-003**: In 100% of successful test generations, exactly one complete image appears above the prompt and the selected model and prompt remain available for review or editing.
- **SC-004**: Across at least 20 consecutive generation attempts per supported model on each supported physical-device class, Mirage completes or presents a recoverable error without crash, indefinite progress, or loss of the previous successful image.
- **SC-005**: In 100% of permission test cases, Mirage saves only after explicit action, accurately reports success or failure, remains usable after denial or revocation, and never requests Photo Library read access.
- **SC-006**: VoiceOver users can identify the selected model, prompt, **SEND** availability, progress, generated image, save action, and save outcome in the intended reading order with no unlabeled interactive element.
- **SC-007**: Privacy tests confirm that no prompt or generated image leaves the device, no generation data is automatically persisted, and saved files contain no prompt or model-selection metadata.
- **SC-008**: Every catalog model meets the quality, safety, bias, memory, energy, thermal, and fallback thresholds approved during planning before it is enabled for release.

## Assumptions

- Mirage targets iOS 26.0+ and uses Swift, SwiftUI, and Swift 6 strict concurrency.
- Final project browsing, target inspection, diagnostics, building, testing, and launch verification use the Hermes-configured Xcode MCP server exclusively.
- The app uses the latest reviewed stable haplollc/Mirage Swift package release for inference and follows that package's Quick Start integration contract. The catalog contains the eight documented model families; exact weight files, quantizations, auxiliary encoders/VAEs, and enabled-device matrix are selected during planning based on licensing, compatibility, quality, safety, and resource evidence.
- The first available catalog model may be selected by default, and the user may change it before pressing **SEND**.
- This version generates one image per request and allows only one active inference at a time.
- The result is session-scoped and is not restored after the app terminates unless the user saved it to Photos.
- Photo Library saving is available through the system's add-only permission flow and does not require browsing or reading the library.

## Out of Scope

- Adding, downloading, importing, training, fine-tuning, or deleting models from the UI.
- Remote or cloud image generation, accounts, subscriptions, payments, analytics, advertising, or telemetry.
- Multi-image batches, seeds, negative prompts, advanced sampling controls, image-to-image editing, inpainting, outpainting, upscaling, or post-processing.
- An in-app gallery, generation history, prompt library, social sharing, community feed, or automatic cloud backup.
- Reading, browsing, editing, or deleting existing Photo Library content.
