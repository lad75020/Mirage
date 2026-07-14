# Development model provisioning

Mirage does not bundle or download model weights. Provisioning is development-only and every descriptor remains disabled until its license, hashes, device budget, safety policy, and physical-device evaluation are approved.

## Reviewed candidate: ERNIE-Image-Turbo

Upstream manifest inspected on 2026-07-14:

- Model card: <https://huggingface.co/jc-builds/ERNIE-Image-Turbo-iOS>
- Immutable repository revision used for provenance: `f23d470af1a57a64aa034d0770e74f99aac6135f`
- Repository card states the bundle's ERNIE, Ministral, and VAE components use Apache-2.0 licenses. Complete release approval remains a human/legal gate.
- The upstream security metadata reported no antivirus detections, but one scanner flagged `PAIT-GGUF-100` for the text encoder while another classified the GGUF as safe. This discrepancy is an explicit release blocker pending authorized review.

| Role | Source URL | Filename | Bytes | SHA-256 |
|---|---|---|---:|---|
| Diffusion | `https://huggingface.co/jc-builds/ERNIE-Image-Turbo-iOS/resolve/main/ernie-image-turbo-Q3_K_M.gguf` | `ernie-image-turbo-Q3_K_M.gguf` | 3,909,632,704 | `3c1813fc1e0e904cc342e7b6791d0165e6dbb6aac30ad2924747b198bc435857` |
| VAE | `https://huggingface.co/jc-builds/ERNIE-Image-Turbo-iOS/resolve/main/ae.safetensors` | `ae.safetensors` | 168,120,878 | `ca70d2202afe6415bdbcb8793ba8cd99fd159cfe6192381504d6c4d3036e0f04` |
| Text encoder | `https://huggingface.co/jc-builds/ERNIE-Image-Turbo-iOS/resolve/main/Ministral-3-3B-Instruct-2512-Q4_K_M.gguf` | `Ministral-3-3B-Instruct-2512-Q4_K_M.gguf` | 2,146,497,824 | `fd46fc371ff0509bfa8657ac956b7de8534d7d9baaa4947975c0648c3aa397f4` |

Hashes and sizes come from the repository's Git LFS metadata. Verify downloaded bytes independently before placing them in the sandbox.

## Sandbox destination

Place the three files in the app container at:

```text
Library/Application Support/Mirage/Models/ernieImageTurbo/
```

Do not add a downloader, copy weights into the source tree, weaken sandbox containment, or commit weights. `.gitignore` excludes common model formats and local `Models/` directories.

## Enablement sequence

1. Confirm every file's byte count and SHA-256 against this document and `ModelCatalog.swift`.
2. Complete the license and supply-chain review.
3. Run the prompt/output safety corpus and model quality/bias evaluation.
4. Use the Hermes-configured Xcode MCP server to build and install on each eligible physical device.
5. Record at least 20 consecutive generations, memory, energy, thermal, safety, and fallback evidence.
6. Only then change `evaluationApproved` for the exact descriptor and artifact hashes.

Current state: `evaluationApproved` is `false`, so the candidate correctly remains unavailable even when files are present.
