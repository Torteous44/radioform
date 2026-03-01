# Radioform DSP Library

Digital signal processing core for Radioform. The library provides a C ABI (`include/radioform_dsp.h`) over a C++ implementation (`src/`) and an Objective-C++ bridge (`bridge/`) for Swift integration.

## Features

- 10-band parametric EQ (`RADIOFORM_MAX_BANDS = 10`)
- Seven filter types: peak, low shelf, high shelf, low pass, high pass, notch, band pass
- Stereo processing in interleaved and planar formats
- Preamp control and optional soft limiter
- DC blocker stage to reduce offset buildup
- C ABI with POD types for C / ObjC++ / Swift interop
- Objective-C++ wrapper (`RadioformDSPEngine`) for Foundation-friendly Swift usage

## Architecture

```
Swift App
    |
    v
RadioformDSPEngine (ObjC++)   bridge/RadioformDSPEngine.{h,mm}
    |
    v
C API                         include/radioform_dsp.h
    |
    v
C++ Engine                    src/engine.cpp + filter/smoother/limiter modules
```

## Directory Structure

```
packages/dsp/
├── include/
│   ├── radioform_types.h
│   └── radioform_dsp.h
├── src/
│   ├── engine.cpp
│   ├── biquad.h / biquad.cpp
│   ├── smoothing.h / smoothing.cpp
│   ├── limiter.h / limiter.cpp
│   ├── dc_blocker.h
│   ├── cpu_util.h
│   ├── preset.cpp
│   └── version.cpp
├── bridge/
│   ├── RadioformDSPEngine.h
│   ├── RadioformDSPEngine.mm
│   ├── SwiftUsageExample.swift
│   └── README.md
├── tests/
│   ├── test_main.cpp
│   ├── test_utils.h
│   ├── test_preset.cpp
│   ├── test_smoothing.cpp
│   ├── test_biquad.cpp
│   ├── test_engine.cpp
│   └── test_frequency_response.cpp
├── tools/
│   └── wav_processor.cpp
└── CMakeLists.txt
```

## Quick Start

### Build

```bash
cd packages/dsp
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

### Run Tests

```bash
./build/tests/radioform_dsp_tests
```

### Process WAV Files

```bash
./build/tools/wav_processor input.wav output_bass.wav bass
./build/tools/wav_processor input.wav output_treble.wav treble
./build/tools/wav_processor input.wav output_vocal.wav vocal
```

## Swift Usage

See `bridge/SwiftUsageExample.swift` for examples.

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

- Supported sample rate range: 8,000 Hz to 384,000 Hz (`radioform_dsp_create` validation)
- Sample format: 32-bit float
- Channels: stereo (left/right)
- Supported buffer layout: interleaved (`radioform_dsp_process_interleaved`)
- Supported buffer layout: planar (`radioform_dsp_process_planar`)
- EQ gain range (preset validation): -12 dB to +12 dB
- EQ frequency range (preset validation): 20 Hz to 20,000 Hz
- EQ Q range (preset validation): 0.1 to 10.0
- Limiter threshold range: -6 dB to 0 dB

## Tests and Verification

`tests/test_main.cpp` registers 33 automated tests covering:

- Preset initialization and validation
- Parameter smoothing behavior
- Biquad behavior and frequency-dependent attenuation/boost
- Engine lifecycle, bypass behavior, limiter behavior, statistics
- Frequency response scenarios and THD check (`freq_response_thd_remains_low` asserts THD < 0.001)

## Realtime/Threading Notes

- `radioform_dsp_process_interleaved` and `radioform_dsp_process_planar` are implemented without heap allocation.
- Bypass state is controlled via `std::atomic<bool>`.
- Use the API thread-safety contract in `include/radioform_dsp.h` as the authoritative reference for calling patterns.

## Build Options

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake -B build -DCMAKE_BUILD_TYPE=Debug
cmake -B build -DBUILD_TESTS=OFF
cmake -B build -DBUILD_BRIDGE=OFF
cmake -B build -DBUILD_TOOLS=OFF
```

## Documentation

- `include/radioform_dsp.h` — public C API contract
- `include/radioform_types.h` — public types and enums
- `bridge/README.md` — Objective-C++ bridge details
- `bridge/SwiftUsageExample.swift` — Swift usage patterns
- `tests/README.md` — test suite overview

## References

- W3C Audio EQ Cookbook: https://www.w3.org/TR/audio-eq-cookbook/
- Web Audio Cookbook mirror: https://webaudio.github.io/Audio-EQ-Cookbook/audio-eq-cookbook.html
- MusicDSP RBJ notes: https://www.musicdsp.org/en/latest/Filters/197-rbj-audio-eq-cookbook.html
- EarLevel biquad notes: https://www.earlevel.com/main/2003/02/28/biquads/

## License

See the repository root `LICENSE` file.
