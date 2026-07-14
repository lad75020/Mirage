# Accessibility audit

## Implemented in code

- Native SwiftUI controls and semantic system colors.
- Dynamic Type and system typography; no fixed text sizes.
- VoiceOver labels for model selection, prompt, result, progress, Send, and Save.
- Spoken state changes for loading, generation, review, success, refusal, failure, and Photos outcomes.
- Reduce Motion removes state animation.
- 44-point-or-larger interactive controls.
- Command-Return generates and Command-S saves for hardware keyboards.
- Errors use text and symbols rather than color alone.
- Result-first single-column layout adapts to compact and regular widths.

## Pending device audit

The following require Xcode MCP and physical-device execution and are not claimed complete:

- VoiceOver rotor order and interruption behavior.
- Dynamic Type accessibility-size truncation on iPhone and iPad.
- Landscape, Split View, and Stage Manager layout.
- Switch Control and Full Keyboard Access traversal.
- Photos permission alert and Settings-return behavior.
- Contrast checks under Increase Contrast and Differentiate Without Color.

Record findings and screenshots here before release.
