# Options

- Removed `cuda-sdk-path`, use the `CUDA_PATH` environment variable instead
- Removed `override-module`, `build-location`
- Removed `execute-binary` and `skip-source-generation`, binaries are always
  built (for the build platform if cross compiling) and executed

- `enable-embed-stdlib` renamed to `embed-stdlib`
- `disable-stdlib-source` renamed (inverted) to `embed-stdlib-source`
- `full-debug-validation` renamed to `enable-full-debug-validation`
- `dx-on-vk` renamed to `enable-dx-on-vk`

- Removed `enable-profile` and `enable-experimental-projects`, these targets are now just off by default

# Misc

- 'edit and continue' Is off by default with Meson
