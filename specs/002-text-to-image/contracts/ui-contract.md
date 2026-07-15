# Single-Page UI Contract

**Feature**: `002-text-to-image`
**Platforms**: iPhone and iPad on iOS 26.0+

## Experience intent

Mirage is a focused native creative tool: result first, model acquisition and selection second, prompt and SEND third, Save only after a validated result. The app remains one page; system Photos permission UI and Files visibility are the only external surfaces.

## Page hierarchy

A vertical `ScrollView` contains one centered content column:

1. Compact page identity and on-device privacy statement.
2. Result card, always above model and prompt controls.
3. Featured model download cards for:
   - `jc-builds/Z-Image-Turbo-iOS`
   - `jc-builds/ERNIE-Image-Turbo-iOS`
   - `jc-builds/Chroma1-HD-iOS`
4. Downloaded snapshots and compatibility/selection status.
5. Custom public Hugging Face reference field plus explicit Download action.
6. Prompt field with validation and count.
7. Full-width **SEND** action.

The result card owns Save when an allowed image exists. The page does not add tabs, navigation stacks, galleries, account screens, token entry, private repository access, or cloud inference.

## Layout and visual system

- Respect safe areas and keyboard avoidance.
- Use system typography, semantic colors, SF Symbols, and the existing app tint.
- Use at least 16 points of horizontal padding and 44 x 44 point interactive targets.
- Constrain readable width on iPad while keeping the result inspectable.
- The result card uses aspect fit and never clips the image.
- The page scrolls in compact height, landscape, keyboard-visible, Split View, and Accessibility XXXL states.
- Essential text wraps; status and button labels do not truncate.
- Status never relies on color, animation, or position alone.
- Reduce Motion, Increase Contrast, Reduce Transparency, light/dark mode, and external keyboard use remain supported.

## Model download contract

Featured cards show repository identity, download state, compatibility state, and actions appropriate to state:

```text
not downloaded -> Download
resolving -> progress/status
awaiting confirmation -> size/license/commit confirmation
downloading -> byte progress and Cancel
validating -> validation status
downloaded compatible -> Select
downloaded incompatible/custom unknown -> visible but unselectable reason
cancelled/failed -> Retry
```

Before transfer, Mirage shows:

- canonical repository identity;
- immutable commit SHA when resolved;
- total size when available;
- license string when available;
- public third-party model terms reminder;
- custom compatibility warning for user-entered repositories.

The Files location text is:

```text
Files > On My iPhone > Mirage > Mirage Models
```

Prompts, generated images, credentials, and private repository tokens are never shown as model folder names or download details.

## Custom reference contract

- Label the field as a public Hugging Face model reference.
- Accept `owner/repository` and `https://huggingface.co/owner/repository`.
- Reject malformed, non-Hugging-Face, private/gated, credentialed, query/fragment, or unsupported references with concise recovery text.
- Custom snapshots may download but remain unselectable until local compatibility checks prove support.
- No token, password, or gated/private repository UI is present.

## Selection and load contract

- Selection is explicit logical state.
- No model is auto-selected.
- Listing, resolving, downloading, and validation do not load native weights.
- A fully downloaded compatible model can be selected.
- The current implementation loads native weights as part of the accepted SEND attempt for the selected model and disables conflicting operations during load/generation/review.
- After every native attempt, the model unloads; logical selection can remain visible, but SEND requires a fresh accepted attempt.
- Model changes are blocked while any download, load, generation, safety review, or save conflict is active.

## Result card states

- Empty: explain that generated output appears here; Save hidden.
- Download/load status: keep prior image visible if one exists and present status outside or over the result area without hiding controls.
- Generating: show step progress when available; announce start, meaningful milestones, and completion, not every callback.
- Safety review: brief status; do not display new pixels until allowed.
- Result: show validated image with accessibility label "AI-generated image"; show Save and a subtle AI-generated disclosure.
- Refusal/failure: concise nonjudgmental text, previous image retained, actionable recovery when available.

## Prompt contract

- Visible label: "Describe your image".
- Multiline, leading aligned, 1...1000 visible characters.
- Whitespace-only input is invalid.
- Prompt remains after success, refusal, or failure.
- Standard text editing, dictation, right-to-left input, emoji, and external keyboard input remain available.
- Prompt content is never used in model download URLs, folder names, logs, fixtures, evidence, or Photo metadata.

## SEND contract

- Visible title is exactly **SEND**.
- Full-width bordered-prominent style and at least 44 points high.
- Disabled while prompt is invalid, no compatible model is explicitly selected, the selected model is unavailable, or download/load/generation/safety operations are active.
- Press produces visible state feedback within 500 ms.
- Command-Return activates SEND only when enabled.
- No native inference Cancel button is shown because package `0.2.0` cannot reliably cancel native generation.

## Save and Photos contract

- Save appears only with a current allowed result.
- The first tap may trigger system add-only permission.
- Success produces an accessible confirmation without navigating away.
- Denied/restricted states keep the image visible and offer concise Settings guidance.
- Command-S saves only when Save is enabled.
- Repeated taps cannot create concurrent saves; each accepted tap creates one Photo asset.

## Accessibility contract

Logical VoiceOver order:

1. Title/privacy statement.
2. Result/status and Save when present.
3. Featured download cards and download progress.
4. Downloaded snapshots and selected/compatibility status.
5. Custom reference field and Download action.
6. Prompt, validation/count, and **SEND**.

Use semantic Button, TextField, Image, ProgressView, and selected/disabled traits. Progress exposes current value. Dynamic errors use announcements. Test VoiceOver, Switch Control basics, Full Keyboard Access, Accessibility XXXL, Reduce Motion, Increase Contrast, Reduce Transparency, light/dark modes, portrait/landscape, and iPad multitasking.

## UI state acceptance matrix

| State | Result area | Model/download area | Prompt | SEND | Save |
|---|---|---|---|---|---|
| Empty/no downloads | Empty guidance | Featured Download actions and custom field | Editable | Disabled | Hidden |
| Resolving/confirming | Prior image or empty + status | Locked current download; confirmation if resolved | Editable | Disabled | Prior result only |
| Downloading | Prior image or empty + progress | Progress + Cancel; other operations locked | Editable | Disabled | Disabled |
| Download failed/cancelled | Prior image or empty + status | Retry available | Editable | Disabled until compatible selection | Prior result only |
| Downloaded incompatible/custom unknown | Prior image or empty | Visible unselectable reason | Editable | Disabled for that model | Prior result only |
| Compatible selected | Empty or prior result | Selected state visible | Editable | Depends on prompt | Prior result only |
| Loading/generating/reviewing | Prior image/status/progress | Locked | Retained | Disabled | Disabled |
| Result | New image | Enabled | Editable | Enabled when valid | Enabled |
| Refused/error | Prior image + message | Enabled | Editable/focused | Enabled when valid | Prior result only |
| Saving/saved/denied | Image + save status | Enabled unless operation conflict | Editable | Enabled when valid | State-dependent |
