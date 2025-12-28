# packages/dsp/include/

Public C/C++ headers for the Radioform DSP library.

## Purpose

Stable, template-free API that can be safely consumed by:
- C code
- Objective-C++
- Swift (via C bridging)

## Files to Implement

- `radioform_dsp.h`: Main API surface
  - Engine lifecycle (create, destroy, reset)
  - Parameter application (preset upload, realtime updates)
  - Process function (audio buffers in → out)

- `radioform_types.h`: POD types
  - Filter coefficients
  - Band configurations
  - Preset structures

## Design Constraints

- **No C++ templates** in public headers
- **No exceptions** (compile with `-fno-exceptions` friendly)
- **Explicit sizes** (no `std::vector`, use fixed arrays or explicit count params)
- **ABI stability** (design for minor version compatibility)

This is the contract. The implementation can use modern C++ internally, but the API surface stays simple and portable.
