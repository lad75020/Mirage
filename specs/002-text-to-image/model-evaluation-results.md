# Model evaluation results

Date: 2026-07-14

No model is release-enabled. The ERNIE-Image-Turbo candidate has exact file metadata but remains `evaluationApproved: false`.

| Model/hash set | Device | Runs | Quality | Safety | Bias | Peak memory | Energy/thermal | Fallback | Photos | Result |
|---|---|---:|---|---|---|---:|---|---|---|---|
| ERNIE candidate manifest v1 | Not available | 0 | Not run | Not run | Not run | Not run | Not run | Not run | Not run | **BLOCKED** |

## Required procedure

For each eligible model/device pair, use Xcode MCP and a physical iOS 26 device to record at least 20 consecutive generations. Include exact hashes, representative multilingual and demographic prompts, malformed/refusal inputs, interruption and memory-pressure behavior, load/generation timing, peak memory, energy impact, thermal state, safe-output review, fallback messaging, model switching, and Photos saving.

A model may be enabled only after measured thresholds are approved and linked to its exact artifact hashes.
