# Mirage Engine — memory-safe local build

This package is based on [`haplollc/Mirage` 0.2.0](https://github.com/haplollc/Mirage/tree/0.2.0) (commit `34b9bbf0b17a1aa42593d7e9d64ff55091944ec9`).

The bundled native XCFramework changes `sd_ctx_params_t.free_params_immediately` to `true`. During one image-generation request, stable-diffusion.cpp therefore releases:

1. the text-encoder parameters after prompt conditioning;
2. the diffusion parameters after denoising;
3. the VAE parameters after image decoding.

The app creates and tears down a fresh `Engine` for every generation attempt, so these buffers are not needed for a second call. Keeping them previously caused all three multi-gigabyte components to overlap in unified memory and could trigger iOS jetsam termination.

`NativeSource/` contains the exact modified C bridge source and exported-symbol list used to produce the binary. The vendored stable-diffusion.cpp source is unchanged from the upstream commit recorded above.
