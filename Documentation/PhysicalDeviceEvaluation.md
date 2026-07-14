# Physical-device evaluation

Mirage inference is intentionally gated until approved model files and a real iPhone or iPad are available. Simulator and compiler checks are not release evidence.

## Required setup

1. Use an iOS 26.0+ physical device with a release-representative memory tier.
2. Provision one reviewed model under `Application Support/Mirage/Models/<model-id>/`.
3. Record exact SHA-256 hashes and byte counts in `ModelCatalog.swift`.
4. Complete license review and set only that descriptor's approval flags.
5. Open, build, test, install, and launch exclusively through the Hermes-configured Xcode MCP server.
6. Disable network access during the inference run and verify generation still succeeds.

## Generation matrix

| Device | OS | Model | Cold load | Warm generation | Peak memory | Thermal result | Output reviewed | Status |
|---|---|---|---:|---:|---:|---|---|---|
| Not run | — | — | — | — | — | — | — | **BLOCKED: no approved assets/device run** |

Record Instruments/Xcode measurements rather than estimates. The candidate must remain responsive, avoid jetsam, and surface low-memory/thermal failures without losing the previous result.

## Model-switch soak

Run at least 20 alternating generations across two approved descriptors:

1. Generate with model A.
2. Switch to model B and generate.
3. Switch back to model A and generate.
4. Repeat while observing retained engine count, peak resident memory, temperature, and output correctness.
5. Confirm only one engine and one inference are active at a time.

| Cycles | Models | Peak memory | Crash/jet-sam | Stale output | Status |
|---:|---|---:|---|---|---|
| 0 | — | — | — | — | **NOT RUN** |

## Accessibility and interaction

On both iPhone and iPad, verify portrait/landscape, Dynamic Type through accessibility sizes, VoiceOver order/announcements, Reduce Motion, hardware keyboard shortcuts, 44-point targets, and Photos denial recovery.

## Release gate

Do not change a descriptor to `evaluationApproved: true` until this document contains measured evidence for that exact model artifact hash, device class, and app revision.
