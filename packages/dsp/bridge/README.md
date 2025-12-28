# Radioform DSP Bridge

This directory contains the Objective-C++ bridge that wraps the C DSP engine for easy consumption from Swift.

## Architecture

```
Swift App
    ↓
RadioformDSPEngine (ObjC++)  ← This bridge layer
    ↓
radioform_dsp.h (C API)
    ↓
C++ DSP Engine
```

## Files

- **RadioformDSPEngine.h** - Public Objective-C header
  - Swift-friendly API with Foundation types
  - NSError-based error handling
  - Object-oriented preset and band management

- **RadioformDSPEngine.mm** - Objective-C++ implementation
  - Wraps the C engine lifecycle
  - Converts between ObjC and C types
  - Memory management with ARC

## Usage from Swift

```swift
// Create engine
let engine = try RadioformDSPEngine(sampleRate: 48000)

// Create a preset
let preset = RadioformPreset.flatPreset()
let band = RadioformBand(frequency: 1000, gain: 6.0, qFactor: 2.0, filterType: .peak)
preset.bands = [band]

// Apply preset
try engine.apply(preset)

// Process audio
engine.processInterleaved(inputBuffer, output: outputBuffer, frameCount: 512)

// Realtime control
engine.bypass = true
engine.updateBandGain(0, gainDb: 3.0)
```

## Why an ObjC Bridge?

While Swift can call C directly, the ObjC bridge provides:

1. **Type Safety** - Foundation types (NSString, NSArray) instead of raw C types
2. **Memory Management** - ARC handles cleanup automatically
3. **Error Handling** - NSError instead of checking return codes
4. **Swift Ergonomics** - Properties, optional types, proper enums
5. **Reference Types** - Preset and Band objects can be passed by reference

## Building

The bridge is built as part of the main DSP library. Include both the DSP library and bridge in your Xcode project, and import the header in your bridging header:

```objc
// YourProject-Bridging-Header.h
#import "RadioformDSPEngine.h"
```

## Thread Safety

- **Audio Thread Safe:**
  - `processInterleaved()`
  - `processPlanarLeft:right:outputLeft:outputRight:frameCount:`
  - `bypass` (get/set)
  - `updateBandGain()`
  - `updatePreampGain()`

- **NOT Audio Thread Safe** (use on main/config thread):
  - `applyPreset()`
  - `setSampleRate()`
  - `reset()`
  - `currentPreset()`

## Testing

The bridge can be tested from Swift unit tests. See the test suite in the main app for examples.
