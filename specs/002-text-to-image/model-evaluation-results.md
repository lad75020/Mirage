# Model evaluation results

Date: 2026-07-14

The exact reviewed Z-Image descriptor is runtime-enabled by explicit product decision, but it is not release-verified. No recorded physical-device generation, 20-cycle evaluation, Instruments trace, or legal/release approval has occurred. ERNIE and Chroma remain disabled.

| Repository | Commit | Runs | Quality | Safety | Bias | Peak memory | Post-unload memory | Energy/thermal | Files/download | Photos | Result |
|---|---|---:|---|---|---|---:|---:|---|---|---|---|
| `jc-builds/Z-Image-Turbo-iOS` | `97ae389b962ee927d83c1911be743c8d82c11674` | 0 recorded | Not run | Not run | Not run | Not run | Not run | Not run | User-reported download completed; evidence not recorded | Not run | **RUNTIME ENABLED / RELEASE EVIDENCE PENDING** |
| `jc-builds/ERNIE-Image-Turbo-iOS` | `f23d470af1a57a64aa034d0770e74f99aac6135f` | 0 | Not run | Not run | Not run | Not run | Not run | Not run | Not run | Not run | **BLOCKED** |
| `jc-builds/Chroma1-HD-iOS` | `722a672dca0d2ec5ff39dea561ae0df62bf49995` | 0 | Not run | Not run | Not run | Not run | Not run | Not run | Not run | Not run | **BLOCKED** |

## Required procedure

For each enabled featured repository/device pair, use XcodeMCP and a physical iOS 26 device to record at least 20 consecutive download/select/generate/unload cycles.

Each run must include:

- repository commit and exact file SHA-256 set;
- device identifier and OS;
- download size, progress, interruption/recovery, integrity, and Files visibility;
- load time, generation time, and unload completion;
- peak memory and post-unload memory;
- energy and thermal state;
- prompt/output safety result;
- quality, bias, malformed/refusal, and fallback behavior;
- Photos add-only save result.

Runtime enablement does not establish release approval. Release sign-off still requires measured thresholds and legal/release approval linked to the exact repository commit and artifact hashes.
