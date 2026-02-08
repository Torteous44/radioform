# Packages

Minimal structure overview of the core packages in this directory.

- driver: CoreAudio HAL plugin (loaded by `coreaudiod`) that creates proxy output devices and writes audio into shared memory ring buffers.
- dsp: C++ DSP library with a C API, ObjC++ bridge, and tests.
- host: macOS audio host runtime that manages devices, reads shared memory, runs DSP, and outputs to physical devices.
