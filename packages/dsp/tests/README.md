# packages/dsp/tests/

Test suite for DSP library correctness.

## Test Coverage

33 tests across:
- Preset validation
- Biquad filter accuracy
- Parameter smoothing
- Engine integration
- Frequency response
- THD+N measurement

## Framework

Custom lightweight test framework (test_utils.h) with signal generation and analysis utilities.

## Running Tests

```bash
cd packages/dsp
mkdir -p build && cd build
cmake ..
cmake --build .
./tests/radioform_dsp_tests
```

## Test Files

- `test_preset.cpp` - Preset validation
- `test_biquad.cpp` - Filter coefficient correctness
- `test_smoothing.cpp` - Parameter smoothing and zipper noise
- `test_engine.cpp` - Engine integration
- `test_frequency_response.cpp` - Frequency response accuracy
