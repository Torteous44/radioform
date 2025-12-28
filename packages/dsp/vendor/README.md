# packages/dsp/vendor/

Third-party dependencies for the DSP library.

## Purpose

Isolate external DSP libraries to prevent them from "infecting" the rest of the codebase.

## Contents

### lsp-dsp-lib/
High-quality open-source DSP primitives library.

**Added as a Git submodule:**
```bash
git submodule add https://github.com/sadko4u/lsp-dsp-lib.git packages/dsp/vendor/lsp-dsp-lib
git submodule update --init --recursive
```

## Why Vendor Here?

- **Containment**: Only `packages/dsp/src/` sees `lsp-dsp-lib` types
- **Swappability**: You can replace the vendor library later without breaking `RadioformAudioHost` or the bridge
- **Version control**: Pin to specific commit/tag for reproducibility

## Usage Rule

**No code outside `packages/dsp/` should `#include` anything from vendor/.**

The DSP package wraps vendor primitives behind `radioform_dsp.h`. This keeps the dependency contained and the API stable.
