# packages/dsp/

Core DSP library for Radioform.

## Purpose

Stable, minimal DSP library providing the audio processing core.

This is **your** API boundary. Even though it wraps `lsp-dsp-lib` internally, the external interface is clean, stable, and under your control.

## What Lives Here

### include/
Public C/C++ headers:
- `radioform_dsp.h`: main API
- Parameter structures (POD types, template-free)
- Filter types and preset definitions

### src/
Implementation:
- Biquad cascade EQ (fixed bands or parametric)
- Parameter smoothing (prevent zipper noise)
- Limiter and preamp stages
- SIMD optimizations (future)

### tests/
Correctness validation:
- Filter coefficient accuracy
- Impulse and step response tests
- Parameter smoothing behavior
- Edge case handling (denormals, NaN safety)

### vendor/
Third-party dependencies:
- `lsp-dsp-lib/`: Git submodule for low-level DSP primitives

## Build System

CMake-based build:
- Produces a static library
- Runs tests via CTest
- Header-only or vendored dependencies preferred

## Design Rules

1. **Stable API**: No C++ templates in public headers
2. **No allocations**: All processing paths are allocation-free
3. **Vendor isolation**: `lsp-dsp-lib` is wrapped, not exposed
4. **Swappable**: You can replace internal DSP impl without breaking users

This boundary lets you upgrade or replace `lsp-dsp-lib` later without touching the host or app.
