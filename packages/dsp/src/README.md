# packages/dsp/src/

Implementation of the Radioform DSP library.

## Purpose

Actual DSP processing code. This is where `lsp-dsp-lib` is used and wrapped.

## Components to Implement

### Biquad Cascades
- Parametric EQ implementation (Q, frequency, gain)
- Fixed-band graphic EQ option
- Coefficient calculation from user parameters
- Numerically stable filter structures

### Parameter Smoothing
- Interpolation to prevent zipper noise
- Adjustable slew rates
- Per-parameter or global smoothing strategies

### Preamp/Limiter
- Gain stage before and/or after EQ
- Soft-knee or hard limiter
- Look-ahead option (if latency budget allows)

### SIMD Optimization
- NEON (Apple Silicon) paths
- SSE/AVX (Intel) fallbacks
- Runtime CPU detection

### Integration with lsp-dsp-lib
- Wrap biquad primitives from vendor library
- Use FFT or convolution routines if needed
- Isolate vendor types from public API

## File Organization

```
engine.cpp           # Main processing loop
biquad.cpp          # Filter implementation
smoothing.cpp       # Parameter interpolation
limiter.cpp         # Dynamics processing
simd_neon.cpp       # ARM-specific code
simd_sse.cpp        # x86-specific code
```

## Design Rules

- **Zero allocations** in audio processing paths
- **Const correctness**: immutable state where possible
- **Denormal handling**: flush-to-zero or explicit checks
- **NaN safety**: never propagate NaN through audio buffers
