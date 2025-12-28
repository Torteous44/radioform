# packages/dsp/tests/

Unit tests for DSP library correctness.

## Purpose

Validate that DSP processing behaves correctly across platforms and configurations.

## Test Categories

### Filter Accuracy
- Coefficient generation correctness
- Frequency response matches expected curves
- Q factor and gain applied correctly
- Shelf and peak filter types

### Signal Processing
- Impulse response (verify filter order, ringing)
- Step response (check overshoot, settling time)
- White noise / pink noise (validate frequency response)
- DC offset handling

### Parameter Smoothing
- No zipper noise on parameter changes
- Smooth interpolation over time
- Edge cases (instant change vs slow ramp)

### Numerical Stability
- Denormal handling (very quiet signals)
- NaN detection and recovery
- Clipping behavior
- Float vs double precision accuracy

### Performance
- Benchmark processing speed (samples/sec)
- SIMD vs scalar comparison
- Memory footprint validation

## Framework

Uses standard C++ testing (Catch2, Google Test, or similar).

Run via:
```bash
mkdir build && cd build
cmake ..
make
ctest
```

## Continuous Integration

These tests run on every commit via `tools/ci/` workflows.
