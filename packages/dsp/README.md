# Radioform DSP Library

Digital signal processing core for the Radioform macOS equalizer, built for predictable performance, clean integration points, and thorough test coverage.

## Features

- 10-band parametric EQ with seven filter types
- Self-contained C++ implementation with no external DSP dependencies
- Realtime-safe processing with lock-free bypass and zero audio-path allocations
- Objective-C++ bridge using Foundation types for Swift interoperability
- Automated verification with 33 tests and measured THD below 0.1%
- Low CPU overhead on Apple Silicon at 48 kHz (under 1%)

## Architecture

```
┌──────────────────────────────────┐
│  Swift Application              │
└───────────────┬──────────────────┘
                │
┌───────────────▼──────────────────┐
│  RadioformDSPEngine (ObjC++)    │  ← bridge/RadioformDSPEngine.{h,mm}
│  - Foundation types             │
│  - Memory management (ARC)      │
└───────────────┬──────────────────┘
                │
┌───────────────▼──────────────────┐
│  radioform_dsp.h (C API)        │  ← include/radioform_dsp.h
│  - Clean ABI boundary           │
│  - POD types                    │
└───────────────┬──────────────────┘
                │
┌───────────────▼──────────────────┐
│  C++ DSP Engine                 │  ← src/engine.cpp
│  - RBJ biquad filters           │
│  - Parameter smoothing          │
│  - Soft limiter                 │
│  - Lock-free bypass             │
└──────────────────────────────────┘
```

## Directory Structure

```
packages/dsp/
├── include/              # Public C API
│   ├── radioform_types.h    # POD types, enums
│   └── radioform_dsp.h      # Engine API
├── src/                  # C++ implementation
│   ├── engine.cpp           # DSP engine
│   ├── biquad.h / .cpp      # RBJ biquad filters (7 types)
│   ├── smoothing.h / .cpp   # Parameter smoothing
│   ├── limiter.h / .cpp     # Soft limiter
│   ├── dc_blocker.h         # DC offset removal filter
│   ├── cpu_util.h           # Denormal suppression (x86/ARM)
│   ├── preset.cpp           # Preset validation
│   └── version.cpp          # Version info
├── bridge/               # Objective-C++ bridge
│   ├── RadioformDSPEngine.h     # ObjC public API
│   ├── RadioformDSPEngine.mm    # ObjC++ implementation
│   ├── SwiftUsageExample.swift  # Usage examples
│   └── README.md                # Bridge documentation
├── tests/                # Automated test suite (33 tests)
│   ├── test_main.cpp            # Test runner
│   ├── test_utils.h             # Test framework
│   ├── test_preset.cpp          # Preset validation
│   ├── test_smoothing.cpp       # Smoothing and zipper noise
│   ├── test_biquad.cpp          # Filter correctness
│   ├── test_engine.cpp          # Engine integration
│   └── test_frequency_response.cpp  # Accuracy validation
├── tools/                # Command-line tools
│   └── wav_processor.cpp        # Audio file processor
└── CMakeLists.txt        # Build configuration
```

## Quick Start

### Build

```bash
cd packages/dsp
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build .
```

### Run Tests

```bash
./tests/radioform_dsp_tests
```

### Try Audio Processing

```bash
./tools/wav_processor input.wav output_bass.wav bass
./tools/wav_processor input.wav output_treble.wav treble
./tools/wav_processor input.wav output_vocal.wav vocal
```

## Swift Usage

See `bridge/SwiftUsageExample.swift` for a full example. Quick usage:

```swift
let engine = try RadioformDSPEngine(sampleRate: 48000)

let band = RadioformBand(frequency: 100, gain: 6.0, qFactor: 0.707, filterType: .lowShelf)
let preset = RadioformPreset.preset(withName: "Bass Boost", bands: [band])
try engine.apply(preset)

engine.processInterleaved(inputBuffer, output: &outputBuffer, frameCount: 512)
engine.updateBandGain(0, gainDb: 3.0)
engine.bypass = true
```

## Technical Specifications

- Sample rates: 8 kHz–384 kHz (optimized for 48 kHz)
- Processing: 32-bit float, stereo (dual mono), zero algorithmic latency
- Formats: Interleaved (LRLR...) and planar (LLL...RRR...)
- Filters: Up to 10 bands, seven types, ±12 dB gain, 20 Hz–20 kHz, Q 0.1–10.0
- Implementation: RBJ Audio EQ Cookbook formulas, Direct Form II Transposed biquads

### Performance (Apple M1 @ 48 kHz)

| Configuration | CPU Usage |
|--------------|-----------|
| Bypass | <0.1% |
| 3-band EQ + limiter | 0.3% |
| 10-band EQ + limiter | 0.8% |

### Quality Metrics

- THD+N below 0.1% with moderate EQ
- Frequency response within ±1 dB
- Bypass is bit-perfect
- Noise floor below -140 dBFS (32-bit float)

## Design Principles

- Self-contained implementation of RBJ biquads to avoid external dependencies
- Clean C ABI with POD types to keep Swift interoperability stable
- Support for both interleaved and planar audio formats
- Atomics and smoothing to keep realtime operations lock-free
- Direct Form II Transposed structure for numerical stability and efficiency

## Test Coverage

- 33 automated tests across presets, smoothing, biquads, engine integration, and frequency response
- Includes impulse response checks, sweep analysis, THD+N measurement, bypass verification, and realtime safety validation

## Thread Safety

Audio-thread safe:

```c
void radioform_dsp_process_interleaved(...);
void radioform_dsp_process_planar(...);
void radioform_dsp_set_bypass(...);
void radioform_dsp_update_band_gain(...);
void radioform_dsp_update_band_frequency(...);
void radioform_dsp_update_band_q(...);
void radioform_dsp_update_preamp(...);
```

Configuration-thread only:

```c
radioform_error_t radioform_dsp_apply_preset(...);
radioform_error_t radioform_dsp_set_sample_rate(...);
void radioform_dsp_reset(...);
radioform_error_t radioform_dsp_get_preset(...);
void radioform_dsp_get_stats(...);
```

## Build Options

```bash
cmake .. -DCMAKE_BUILD_TYPE=Release  # Optimized (-O3)
cmake .. -DCMAKE_BUILD_TYPE=Debug    # Debug symbols + AddressSanitizer
cmake .. -DBUILD_TESTS=OFF           # Skip tests
cmake .. -DBUILD_BRIDGE=OFF          # Skip ObjC++ bridge
cmake .. -DBUILD_TOOLS=OFF           # Skip command-line tools
```

## Documentation

- `bridge/README.md` — ObjC++ bridge overview
- `bridge/SwiftUsageExample.swift` — Usage examples

## References

### DSP Theory
- W3C Audio EQ Cookbook: https://www.w3.org/TR/audio-eq-cookbook/
- Web Audio API Specification: https://webaudio.github.io/Audio-EQ-Cookbook/audio-eq-cookbook.html
- MusicDSP.org: https://www.musicdsp.org/en/latest/Filters/197-rbj-audio-eq-cookbook.html
- EarLevel Engineering: https://www.earlevel.com/main/2003/02/28/biquads/

### Numerical Stability
- Wikipedia: https://en.wikipedia.org/wiki/Digital_biquad_filter
- ARM CMSIS-DSP Documentation: https://arm-software.github.io/CMSIS-DSP/main/group__BiquadCascadeDF2T.html

## License

See the root `LICENSE` file.
