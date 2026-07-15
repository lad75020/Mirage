# Model Download and Provisioning

Date: 2026-07-14
Feature: `002-text-to-image`

Mirage now downloads public Hugging Face model snapshots from the app UI. It does not bundle model weights, commit weights to Git, support tokens, support private/gated repositories, or enable custom snapshots by default.

## Storage location

Promoted downloads are visible to the user in Files:

```text
Files > On My iPhone > Mirage > Mirage Models
Documents/Mirage Models/<safe-repository-folder>/
```

Temporary staging is outside the promoted folder. Cancellation, validation failure, low storage, integrity failure, and unsafe snapshot failures remove staging data. Atomic promotion is required before a snapshot can appear as downloaded.

## Download rules

Mirage downloads only public unauthenticated model files from official Hugging Face hosts over HTTPS. It resolves metadata from the Hugging Face API with `blobs=true`, requires an immutable commit SHA, requires license and size information for confirmation, and requires LFS SHA-256 for every downloaded `.gguf` or `.safetensors` file.

Limits:

| Limit | Value |
|---|---:|
| Metadata response | 2 MiB |
| Files per snapshot | 24 |
| Size per file | 16 GiB |
| Size per snapshot | 24 GiB |

Promoted folders must not contain prompts, generated images, Photo Library data, credentials, analytics IDs, logs, or fixtures.

## Featured repositories

Metadata below was verified through the Hugging Face API on 2026-07-14. All three featured repositories are public, ungated, and Apache-2.0. The exact reviewed Z-Image snapshot is runtime-enabled; ERNIE and Chroma remain disabled. Runtime enablement does not replace physical-device and release evidence.

### `jc-builds/Z-Image-Turbo-iOS`

- Commit: `97ae389b962ee927d83c1911be743c8d82c11674`
- Profile: 1024 x 1024, 9 steps, CFG 1.0

| Role | Filename | Bytes | SHA-256 |
|---|---|---:|---|
| Text encoder | `Qwen3-4B-Instruct-2507-Q4_K_M.gguf` | 2497281120 | `3605803b982cb64aead44f6c1b2ae36e3acdb41d8e46c8a94c6533bc4c67e597` |
| VAE | `ae.safetensors` | 335304388 | `afc8e28272cd15db3919bacdb6918ce9c1ed22e96cb12c4d5ed0fba823529e38` |
| Diffusion | `z-image-turbo-Q3_K_M.gguf` | 4186161216 | `7070b605165c372833c21c6bd45e73b242cf0db261b4d5436039363f3dbd4e0e` |

### `jc-builds/ERNIE-Image-Turbo-iOS`

- Commit: `f23d470af1a57a64aa034d0770e74f99aac6135f`
- Profile: 1024 x 1024, 8 steps, CFG 1.0

| Role | Filename | Bytes | SHA-256 |
|---|---|---:|---|
| Diffusion | `ernie-image-turbo-Q3_K_M.gguf` | 3909632704 | `3c1813fc1e0e904cc342e7b6791d0165e6dbb6aac30ad2924747b198bc435857` |
| VAE | `ae.safetensors` | 168120878 | `ca70d2202afe6415bdbcb8793ba8cd99fd159cfe6192381504d6c4d3036e0f04` |
| Text encoder | `Ministral-3-3B-Instruct-2512-Q4_K_M.gguf` | 2146497824 | `fd46fc371ff0509bfa8657ac956b7de8534d7d9baaa4947975c0648c3aa397f4` |

### `jc-builds/Chroma1-HD-iOS`

- Commit: `722a672dca0d2ec5ff39dea561ae0df62bf49995`
- Profile: 1024 x 1024, 28 steps, CFG 4.0

| Role | Filename | Bytes | SHA-256 |
|---|---|---:|---|
| Diffusion | `Chroma1-HD-Q4_K_S.gguf` | 5432053920 | `4443db48850a45bb7f163a0582ea0e9f9d449db1aa56632c8572515e8e83acc8` |
| VAE | `ae.safetensors` | 335304388 | `afc8e28272cd15db3919bacdb6918ce9c1ed22e96cb12c4d5ed0fba823529e38` |
| Text encoder | `t5xxl_fp16.safetensors` | 9787841024 | `6e480b09fae049a72d2a8c5fbccb8d3e92febeb233bbe9dfe7256958a9167635` |

## Custom repository policy

A custom public Hugging Face repository can be downloaded after reference validation and explicit confirmation. It remains unselectable by default. Selection requires local validation of:

- safe public metadata;
- immutable commit SHA;
- complete size and SHA-256 data;
- safe paths and atomic promotion;
- supported file roles and architecture/profile for package `0.2.0`;
- device OS, memory, and Metal eligibility;
- prompt and output safety policy;
- no executable code or path escape.

Private, gated, token-authenticated, and non-Hugging-Face repositories are out of scope.

## Enablement sequence

1. Download a featured repository through the app UI.
2. Confirm the UI shows repository identity, immutable commit, license, and total size before transfer.
3. Confirm byte progress during transfer.
4. Confirm staging disappears after cancellation/failure.
5. Confirm promoted files and `.mirage-snapshot.json` appear under `Documents/Mirage Models`.
6. Confirm every promoted file matches byte count and SHA-256.
7. Confirm Files edits/removals cause refresh to mark the snapshot incompatible.
8. Run XcodeMCP unit/build evidence.
9. Run physical-device download, selection, load, generation, unload, memory, energy, thermal, quality, bias, safety, and Photos evidence.
10. Complete legal/release approval.
11. Record whether runtime enablement is approved for the exact featured descriptor; release approval remains a separate decision.

Current state: Z-Image is `evaluationApproved = true` for the exact reviewed commit and hash set. ERNIE, Chroma, and custom repositories remain fail-closed. Z-Image release evidence remains incomplete.
