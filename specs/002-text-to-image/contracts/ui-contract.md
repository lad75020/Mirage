# Single-Page UI Contract

**Feature**: `002-text-to-image`
**Platforms**: iPhone and iPad on iOS 26.0+

## Experience intent

Mirage is a focused creative tool: result first, controls second, one obvious primary action, immediate feedback, and no navigation or model-management chrome. The visual language is minimal and native rather than web-styled.

## Page hierarchy

A vertical `ScrollView` contains one centered content column:

1. Page identity: compact "Mirage" title and a brief on-device privacy statement.
2. Result card: always present and always above the prompt.
3. Model field: labeled picker/menu plus current availability text.
4. Prompt field: labeled multiline input plus validation/character count.
5. SEND: full-width primary action.

The result card owns its Save action when an allowed image exists. No additional screen, tab, sheet, in-app gallery, or model download flow is introduced. System permission UI is allowed because it is not app navigation.

## Layout contract

- Respect safe areas; only background decoration may extend beneath them.
- Use standard system spacing and at least 16 points of horizontal page padding.
- Constrain the content column to a readable iPad width while keeping the generated image large enough to inspect.
- The result card is square by default, uses aspect fit, never clips the image, and can shrink vertically only to keep controls reachable.
- The full page scrolls in compact height, landscape, keyboard-visible, Split View, and accessibility Dynamic Type states.
- Interactive targets are at least 44 × 44 points with sufficient separation.
- Prompt and status text wrap; essential text is never truncated.
- Use `ViewThatFits` or vertical fallbacks when horizontal control composition does not fit.

## Visual system

- Typography: SF system semantic styles only (`title`, `headline`, `body`, `callout`, `caption`). No fixed font sizes or custom web fonts.
- Color: semantic foreground/background/fill styles and the app's existing tint. Support light, dark, Increased Contrast, and Reduce Transparency.
- Icons: SF Symbols with consistent rendering. No emoji icons.
- Surfaces: restrained native cards/materials; no heavy chrome, decorative gradients behind text, or low-contrast glass.
- Motion: standard state transitions only; disable nonessential animation under Reduce Motion.
- Status: never communicate selection, availability, progress, refusal, or failure by color alone.

The generic UI-UX design-system output recommended minimal single-column structure and immediate progress; those structural recommendations are accepted. Its Archivo/Space Grotesk fonts and hardcoded black/gold palette are rejected in favor of Apple HIG, Dynamic Type, semantic colors, and existing Mirage brand tint.

## Result card states

### Empty

- Neutral system image or restrained placeholder.
- Text: explain that the generated image will appear here.
- No Save action.

### Model loading

- Indeterminate progress with selected model name.
- Announce once to VoiceOver.
- Keep previous image visible if one exists, with a clear loading overlay/status outside the image.

### Generating

- Determinate progress when step/total is available.
- Show `Step n of total`; show ETA only after a stable estimate exists and label it as estimated.
- Do not announce every sampler callback. Announce start, meaningful milestones, and completion.
- Preserve previous image until replacement passes validation.

### Safety review

- Indeterminate, brief "Checking result" status.
- Do not expose new pixels until allowed.

### Result

- Display the validated image with accessibility label "AI-generated image" and value identifying the selected model only if useful.
- Present Save with a standard photo/add symbol and text label.
- Present a subtle "AI-generated" disclosure.

### Refusal or failure

- Use concise, nonjudgmental text near the result/prompt context.
- Include a recovery action only when actionable (edit prompt, Retry, choose another model, open Settings for Photos).
- Preserve previous allowed image.
- Announce the error; do not rely on red styling alone.

## Model field contract

- Label: "Model".
- One menu/picker lists all eight families in this exact order:
  1. Stable Diffusion 1.x / 2.x
  2. SDXL / SDXL-Turbo
  3. SD3 / SD3.5
  4. FLUX.1 schnell / dev
  5. Chroma1-HD
  6. Qwen-Image
  7. ERNIE-Image-Turbo
  8. Z-Image-Turbo
- Exactly one available entry has selected/checkmark state.
- Unavailable entries remain listed and disabled; a concise status explains the selected/unavailable reason below the control.
- Selection does not load multi-GB weights. Loading begins only after SEND.
- Model changes are disabled while native generation is active.
- VoiceOver exposes label, selected value, availability, and disabled state.

## Prompt field contract

- Visible label: "Describe your image"; placeholder is supplementary, not the only label.
- Multiline, leading aligned, 1–1,000 visible characters.
- Character count is secondary and announced only when useful, including near/at the limit.
- Whitespace-only input is invalid.
- Validation appears adjacent to the field and is announced.
- Prompt remains after success, refusal, or failure.
- Standard text editing, dictation, right-to-left input, emoji, and external keyboard input remain available.

## SEND contract

- Visible title is exactly **SEND**.
- Full-width bordered-prominent style and at least 44 points high.
- Disabled while prompt is invalid, selected model is unavailable, or load/generation/safety review is active.
- Disabled styling includes more than opacity: semantic disabled behavior and accessibility state.
- Press produces immediate state feedback within 500 ms.
- Command-Return activates SEND on external keyboards only when enabled.
- No Cancel button is shown because package 0.2.0 cannot cancel native inference reliably.

## Save and Photos contract

- Save appears only with a current allowed result.
- The first tap may trigger the system add-only permission prompt.
- Success produces an accessible confirmation without navigating away.
- Denied/restricted states keep the image visible and offer concise Settings guidance.
- Command-S saves only when Save is enabled.
- Repeated taps cannot create concurrent saves; each accepted tap creates one Photo asset.

## Accessibility contract

- Logical VoiceOver order: title/privacy, result/status, Save if present, Model, model status, Prompt, validation/count, SEND.
- Use semantic Button, Picker/Menu, TextField, Image, and ProgressView controls rather than tap gestures on decorative views.
- Selected model adds selected state; progress exposes current value; dynamic errors use announcements.
- All interactive elements have localized labels and useful hints without repeating visible text unnecessarily.
- Test at Accessibility XXXL with no clipped text and all buttons reachable.
- Test VoiceOver, Switch Control basics, Full Keyboard Access, Reduce Motion, Increase Contrast, Reduce Transparency, light/dark modes, portrait/landscape, and iPad multitasking.

## UI state acceptance matrix

| State | Result area | Model | Prompt | SEND | Save |
|---|---|---|---|---|---|
| No model available | Empty + reason | Visible, disabled entries | Editable | Disabled | Hidden |
| Ready | Empty or prior result | Enabled | Editable | Depends on prompt | Prior result only |
| Loading model | Prior result/status | Locked | Retained, not submitted again | Disabled | Disabled |
| Generating | Prior result + step progress | Locked | Retained | Disabled | Disabled |
| Reviewing output | Prior result + review status | Locked | Retained | Disabled | Disabled |
| Result | New image | Enabled | Editable | Enabled when valid | Enabled |
| Refused | Prior result + message | Enabled | Editable/focused | Enabled when valid | Prior result only |
| Generation error | Prior result + recovery | Enabled | Editable | Enabled when valid | Prior result only |
| Saving | Image + save progress | Enabled | Editable | Enabled unless conflicting | Disabled |
| Saved | Image + confirmation | Enabled | Editable | Enabled when valid | Enabled |
| Photos denied | Image + Settings guidance | Enabled | Editable | Enabled when valid | Enabled |
