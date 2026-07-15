# Physical-device evaluation

The exact reviewed Z-Image-Turbo snapshot is runtime-enabled so physical-device inference can be exercised. Simulator and compiler checks are not release evidence, and runtime enablement is not release approval.

## Required setup

1. Use an iOS 26.0+ physical device with a release-representative memory tier.
2. Download one featured public Hugging Face repository through the app UI.
3. Verify the resolved immutable commit, license, file sizes, and SHA-256 hashes against `MirageTests/AIEvaluation/ModelEvaluationManifest.json`.
4. Verify the promoted snapshot is under `Documents/Mirage Models` and visible in Files.
5. Open, build, test, install, and launch exclusively through the Hermes-configured Xcode MCP server.
6. Verify listing/downloading did not load native weights.
7. Explicitly select the compatible downloaded model, press **SEND**, and verify the native load begins only for that accepted attempt.

## Generation matrix

| Device | OS | Model | Cold load | Warm generation | Peak memory | Thermal result | Output reviewed | Status |
|---|---|---|---:|---:|---:|---|---|---|
| Not recorded | — | Z-Image-Turbo | — | — | — | — | — | **RUNTIME ENABLED; RELEASE EVIDENCE PENDING** |

Record Instruments/Xcode measurements rather than estimates. The candidate must remain responsive, avoid jetsam, and surface low-memory/thermal failures without losing the previous result.

## Download and unload soak

Run at least 20 consecutive cycles for each enabled featured descriptor/device class:

1. Resolve metadata and confirm size/license.
2. Download, validate, and verify Files visibility.
3. Select the model and generate one image.
4. Confirm output safety review and Photos save behavior.
5. Confirm the native engine and model memory unload after success or failure before the next operation.
6. Repeat while observing load time, generation time, post-unload memory, energy, thermal state, and output correctness.

| Cycles | Model | Peak memory | Post-unload memory | Crash/jetsam | Status |
|---:|---|---:|---:|---|---|
| 0 | - | - | - | - | **NOT RUN** |

## Accessibility and interaction

On both iPhone and iPad, verify portrait/landscape, Dynamic Type through accessibility sizes, VoiceOver order/announcements, Reduce Motion, hardware keyboard shortcuts, 44-point targets, and Photos denial recovery.

## Release gate

Z-Image-Turbo is `evaluationApproved: true` by explicit product decision for the exact reviewed commit and hash set. Complete this document before release sign-off. Do not enable another descriptor without equivalent artifact review and an explicit product decision.
