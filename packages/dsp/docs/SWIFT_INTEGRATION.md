# Swift Integration Guide

Complete guide for integrating Radioform DSP into your Swift macOS application.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Xcode Project Setup](#xcode-project-setup)
3. [Basic Usage](#basic-usage)
4. [Advanced Usage](#advanced-usage)
5. [Thread Safety](#thread-safety)
6. [Error Handling](#error-handling)
7. [Performance Optimization](#performance-optimization)
8. [Troubleshooting](#troubleshooting)

## Quick Start

### 1. Add Libraries to Xcode

1. Build the DSP library:
   ```bash
   cd packages/dsp
   mkdir -p build && cd build
   cmake .. -DCMAKE_BUILD_TYPE=Release
   cmake --build .
   ```

2. Add to your Xcode project:
   - `build/libradioform_dsp.a`
   - `build/bridge/libradioform_dsp_bridge.a`

3. In **Build Settings**:
   - **Header Search Paths**: Add `$(PROJECT_DIR)/packages/dsp/include` and `$(PROJECT_DIR)/packages/dsp/bridge`
   - **Library Search Paths**: Add `$(PROJECT_DIR)/packages/dsp/build` and `$(PROJECT_DIR)/packages/dsp/build/bridge`

### 2. Create Bridging Header

Create `YourApp-Bridging-Header.h`:

```objc
#import "RadioformDSPEngine.h"
```

### 3. Configure Bridging Header

In **Build Settings**, set:
- **Objective-C Bridging Header**: `YourApp/YourApp-Bridging-Header.h`

### 4. Use in Swift

```swift
import Foundation

class AudioProcessor {
    let engine: RadioformDSPEngine

    init() throws {
        engine = try RadioformDSPEngine(sampleRate: 48000)

        // Apply bass boost
        let band = RadioformBand(frequency: 100, gain: 6.0, qFactor: 0.707, filterType: .lowShelf)
        let preset = RadioformPreset.preset(withName: "Bass Boost", bands: [band])
        try engine.apply(preset)
    }

    func process(input: UnsafePointer<Float>, output: UnsafeMutablePointer<Float>, frames: UInt32) {
        engine.processInterleaved(input, output: output, frameCount: frames)
    }
}
```

## Xcode Project Setup

### Framework Linking

1. **Link Libraries**:
   - Go to **Target** → **Build Phases** → **Link Binary With Libraries**
   - Add `libradioform_dsp.a`
   - Add `libradioform_dsp_bridge.a`
   - Add `Accelerate.framework`
   - Add `Foundation.framework`

2. **Enable ARC for Bridge**:
   The ObjC++ bridge uses ARC - no additional configuration needed.

### Build Settings

```
HEADER_SEARCH_PATHS = $(PROJECT_DIR)/packages/dsp/include $(PROJECT_DIR)/packages/dsp/bridge
LIBRARY_SEARCH_PATHS = $(PROJECT_DIR)/packages/dsp/build $(PROJECT_DIR)/packages/dsp/build/bridge
SWIFT_OBJC_BRIDGING_HEADER = YourApp/YourApp-Bridging-Header.h
CLANG_ENABLE_OBJC_ARC = YES
```

## Basic Usage

### Creating an Engine

```swift
do {
    let engine = try RadioformDSPEngine(sampleRate: 48000)
} catch {
    print("Failed to create engine: \(error)")
}
```

### Creating Presets

#### Flat (Transparent)

```swift
let flat = RadioformPreset.flatPreset()
try engine.apply(flat)
```

#### Custom EQ

```swift
// Create bands
let bassBoost = RadioformBand(
    frequency: 100,
    gain: 6.0,
    qFactor: 0.707,
    filterType: .lowShelf
)

let midCut = RadioformBand(
    frequency: 1000,
    gain: -3.0,
    qFactor: 1.0,
    filterType: .peak
)

let trebleBoost = RadioformBand(
    frequency: 8000,
    gain: 4.0,
    qFactor: 0.707,
    filterType: .highShelf
)

// Create preset
let preset = RadioformPreset.preset(
    withName: "My EQ",
    bands: [bassBoost, midCut, trebleBoost]
)

preset.preampDb = -3.0  // Reduce overall gain
preset.limiterEnabled = true

try engine.apply(preset)
```

### Processing Audio

#### Interleaved Format (LRLRLR...)

```swift
let frameCount: UInt32 = 512
var inputBuffer = [Float](repeating: 0, count: Int(frameCount * 2))
var outputBuffer = [Float](repeating: 0, count: Int(frameCount * 2))

// Fill input buffer with audio...

engine.processInterleaved(
    inputBuffer,
    output: &outputBuffer,
    frameCount: frameCount
)
```

#### Planar Format (LLL...RRR...)

```swift
let frameCount: UInt32 = 512
var leftIn = [Float](repeating: 0, count: Int(frameCount))
var rightIn = [Float](repeating: 0, count: Int(frameCount))
var leftOut = [Float](repeating: 0, count: Int(frameCount))
var rightOut = [Float](repeating: 0, count: Int(frameCount))

// Fill input buffers...

engine.processPlanar(
    leftIn,
    right: rightIn,
    outputLeft: &leftOut,
    outputRight: &rightOut,
    frameCount: frameCount
)
```

## Advanced Usage

### Realtime Parameter Updates

Safe to call from any thread:

```swift
class EQController {
    let engine: RadioformDSPEngine

    func setBass(_ value: Float) {
        // Slider value -12 to +12 dB
        engine.updateBandGain(0, gainDb: value)
    }

    func setMid(_ value: Float) {
        engine.updateBandGain(1, gainDb: value)
    }

    func setTreble(_ value: Float) {
        engine.updateBandGain(2, gainDb: value)
    }

    func setMasterGain(_ value: Float) {
        engine.updatePreampGain(value)
    }

    func toggleBypass(_ enabled: Bool) {
        engine.bypass = enabled
    }
}
```

### CoreAudio Integration

```swift
import AVFoundation

class AudioEngine {
    private let dspEngine: RadioformDSPEngine
    private let audioEngine = AVAudioEngine()

    init() throws {
        // Create DSP engine
        let sampleRate = audioEngine.outputNode.outputFormat(forBus: 0).sampleRate
        dspEngine = try RadioformDSPEngine(sampleRate: UInt32(sampleRate))

        // Install tap on output node
        let format = audioEngine.outputNode.outputFormat(forBus: 0)
        audioEngine.outputNode.installTap(onBus: 0, bufferSize: 512, format: format) { [weak self] buffer, time in
            self?.processAudio(buffer)
        }

        try audioEngine.start()
    }

    private func processAudio(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let frameCount = buffer.frameLength

        // Process planar audio
        dspEngine.processPlanar(
            channelData[0],
            right: channelData[1],
            outputLeft: channelData[0],
            outputRight: channelData[1],
            frameCount: frameCount
        )
    }
}
```

### Preset Management

```swift
class PresetManager {
    private var presets: [String: RadioformPreset] = [:]

    func savePreset(_ preset: RadioformPreset, name: String) throws {
        // Validate before saving
        guard preset.isValid() else {
            throw PresetError.invalidPreset
        }

        presets[name] = preset.copy() as? RadioformPreset

        // Persist to disk
        try saveToUserDefaults(name: name, preset: preset)
    }

    func loadPreset(name: String) -> RadioformPreset? {
        return presets[name]
    }

    private func saveToUserDefaults(name: String, preset: RadioformPreset) throws {
        // Convert to dictionary for persistence
        var dict: [String: Any] = [
            "name": preset.name,
            "preampDb": preset.preampDb,
            "limiterEnabled": preset.limiterEnabled,
            "limiterThresholdDb": preset.limiterThresholdDb
        ]

        var bandsArray: [[String: Any]] = []
        for band in preset.bands {
            bandsArray.append([
                "frequency": band.frequencyHz,
                "gain": band.gainDb,
                "q": band.qFactor,
                "type": band.filterType.rawValue,
                "enabled": band.enabled
            ])
        }
        dict["bands"] = bandsArray

        UserDefaults.standard.set(dict, forKey: "preset_\(name)")
    }
}

enum PresetError: Error {
    case invalidPreset
}
```

## Thread Safety

### Audio Thread Safe ✅

These can be called from the realtime audio thread:

```swift
// Processing functions
engine.processInterleaved(_:output:frameCount:)
engine.processPlanar(_:right:outputLeft:outputRight:frameCount:)

// Realtime controls
engine.bypass = true
engine.updateBandGain(_:gainDb:)
engine.updatePreampGain(_:)
```

### NOT Audio Thread Safe ⚠️

Call these from the main/UI thread only:

```swift
// Configuration
engine.apply(_:)
engine.setSampleRate(_:)
engine.reset()
engine.currentPreset()
engine.statistics()
```

### Thread Safety Pattern

```swift
class ThreadSafeAudioProcessor {
    private let engine: RadioformDSPEngine
    private let configQueue = DispatchQueue(label: "com.radioform.config")

    // Called from audio thread - safe
    func processAudio(input: UnsafePointer<Float>,
                     output: UnsafeMutablePointer<Float>,
                     frames: UInt32) {
        engine.processInterleaved(input, output: output, frameCount: frames)
    }

    // Called from UI thread - safe
    func updateBass(_ gain: Float) {
        engine.updateBandGain(0, gainDb: gain)
    }

    // Called from UI thread - needs serialization
    func applyPreset(_ preset: RadioformPreset) throws {
        try configQueue.sync {
            try engine.apply(preset)
        }
    }
}
```

## Error Handling

### Handling Initialization Errors

```swift
do {
    let engine = try RadioformDSPEngine(sampleRate: 48000)
} catch let error as NSError {
    switch RadioformDSPError(rawValue: error.code) {
    case .invalidParameter:
        print("Invalid sample rate")
    case .outOfMemory:
        print("Out of memory")
    default:
        print("Unknown error: \(error)")
    }
}
```

### Validating Presets

```swift
let preset = RadioformPreset.flatPreset()
let band = RadioformBand(frequency: 30000, gain: 0, qFactor: 1.0, filterType: .peak)
preset.bands = [band]

if preset.isValid() {
    try engine.apply(preset)
} else {
    print("Preset validation failed")
    // Frequency 30000 Hz is out of range (max 20000 Hz)
}
```

### Robust Error Handling

```swift
class RobustAudioProcessor {
    private var engine: RadioformDSPEngine?

    func initialize(sampleRate: UInt32) -> Bool {
        do {
            engine = try RadioformDSPEngine(sampleRate: sampleRate)

            // Apply default preset
            let preset = RadioformPreset.flatPreset()
            try engine?.apply(preset)

            return true
        } catch {
            NSLog("Failed to initialize DSP: \(error)")
            return false
        }
    }

    func applyPreset(_ preset: RadioformPreset) -> Bool {
        guard let engine = engine else { return false }

        // Validate first
        guard preset.isValid() else {
            NSLog("Invalid preset")
            return false
        }

        do {
            try engine.apply(preset)
            return true
        } catch {
            NSLog("Failed to apply preset: \(error)")
            return false
        }
    }
}
```

## Performance Optimization

### Buffer Size

```swift
// Smaller buffer = lower latency, higher CPU
let lowLatency: UInt32 = 128

// Larger buffer = higher latency, lower CPU
let lowCPU: UInt32 = 2048

// Recommended: 512 frames at 48 kHz = 10.7 ms latency
let recommended: UInt32 = 512
```

### In-Place Processing

```swift
// Efficient: process in-place
var buffer = [Float](repeating: 0, count: 1024)
engine.processInterleaved(buffer, output: &buffer, frameCount: 512)

// Less efficient: separate buffers
let input = [Float](repeating: 0, count: 1024)
var output = [Float](repeating: 0, count: 1024)
engine.processInterleaved(input, output: &output, frameCount: 512)
```

### Minimize Allocations

```swift
class OptimizedProcessor {
    // Reuse buffers instead of allocating every frame
    private var processingBuffer: [Float]

    init(maxFrames: Int) {
        processingBuffer = [Float](repeating: 0, count: maxFrames * 2)
    }

    func process(input: UnsafePointer<Float>,
                output: UnsafeMutablePointer<Float>,
                frames: UInt32) {
        // No allocations in hot path
        engine.processInterleaved(input, output: output, frameCount: frames)
    }
}
```

### CPU Usage Monitoring

```swift
func checkPerformance() {
    let stats = engine.statistics()

    print("Frames processed: \(stats.framesProcessed)")
    print("CPU load: \(stats.cpuLoadPercent)%")
    print("Sample rate: \(stats.sampleRate) Hz")

    if stats.cpuLoadPercent > 80 {
        print("Warning: High CPU usage")
        // Consider reducing buffer size or simplifying EQ
    }
}
```

## Troubleshooting

### Audio Glitches/Clicks

**Problem**: Audible clicks or pops when changing parameters

**Solution**:
- Use `updateBandGain()` instead of `applyPreset()` for realtime changes
- The smoothing will prevent zipper noise

```swift
// ❌ Bad: causes clicks
func sliderChanged(_ value: Float) {
    let preset = createPresetWithGain(value)
    try? engine.apply(preset)
}

// ✅ Good: smooth
func sliderChanged(_ value: Float) {
    engine.updateBandGain(0, gainDb: value)
}
```

### Distortion/Clipping

**Problem**: Audio is distorted after applying EQ

**Solution**:
- Enable the limiter
- Reduce preamp gain
- Check total boost isn't excessive

```swift
let preset = RadioformPreset.preset(withName: "Heavy EQ", bands: bands)

// Calculate total boost
let totalBoost = bands.reduce(0) { $0 + max(0, $1.gainDb) }

// Compensate with preamp
preset.preampDb = -totalBoost / 2.0

// Enable safety limiter
preset.limiterEnabled = true
```

### Memory Issues

**Problem**: Memory usage growing over time

**Solution**:
- Ensure you're not creating new engines repeatedly
- Reuse audio buffers
- Use `autoreleasepool` in loops

```swift
// ❌ Bad: creates engine every time
func processFile() {
    let engine = try! RadioformDSPEngine(sampleRate: 48000)
    // ...
}

// ✅ Good: reuse engine
class Processor {
    let engine: RadioformDSPEngine
    init() { engine = try! RadioformDSPEngine(sampleRate: 48000) }
}
```

### Build Errors

**Problem**: `Use of undeclared type 'RadioformDSPEngine'`

**Solution**:
1. Check bridging header is set in Build Settings
2. Verify header path is correct
3. Clean build folder (Cmd+Shift+K)
4. Rebuild

**Problem**: `Undefined symbols for architecture arm64`

**Solution**:
1. Ensure both `.a` files are linked
2. Check library search paths
3. Verify architecture matches (arm64 for Apple Silicon)

## Examples

### Complete Audio Pipeline

```swift
import AVFoundation

class RadioformAudioPipeline {
    private let dspEngine: RadioformDSPEngine
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()

    init() throws {
        // Initialize DSP
        let sampleRate = audioEngine.outputNode.outputFormat(forBus: 0).sampleRate
        dspEngine = try RadioformDSPEngine(sampleRate: UInt32(sampleRate))

        // Setup audio graph
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: nil)

        // Install DSP tap
        let mixer = audioEngine.mainMixerNode
        let format = mixer.outputFormat(forBus: 0)

        mixer.installTap(onBus: 0, bufferSize: 512, format: format) { [weak self] buffer, _ in
            self?.processBuffer(buffer)
        }

        try audioEngine.start()
    }

    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        dspEngine.processPlanar(
            channelData[0],
            right: channelData[1],
            outputLeft: channelData[0],
            outputRight: channelData[1],
            frameCount: buffer.frameLength
        )
    }

    func playFile(url: URL) throws {
        let file = try AVAudioFile(forReading: url)
        playerNode.scheduleFile(file, at: nil)
        playerNode.play()
    }

    func applyBassBoost() throws {
        let band = RadioformBand(frequency: 100, gain: 8.0, qFactor: 0.707, filterType: .lowShelf)
        let preset = RadioformPreset.preset(withName: "Bass Boost", bands: [band])
        preset.preampDb = -4.0
        try dspEngine.apply(preset)
    }
}
```

### SwiftUI Integration

```swift
import SwiftUI

class EQViewModel: ObservableObject {
    @Published var bypass: Bool = false {
        didSet { engine.bypass = bypass }
    }

    @Published var bassGain: Float = 0 {
        didSet { engine.updateBandGain(0, gainDb: bassGain) }
    }

    @Published var midGain: Float = 0 {
        didSet { engine.updateBandGain(1, gainDb: midGain) }
    }

    @Published var trebleGain: Float = 0 {
        didSet { engine.updateBandGain(2, gainDb: trebleGain) }
    }

    private let engine: RadioformDSPEngine

    init() throws {
        engine = try RadioformDSPEngine(sampleRate: 48000)

        // Setup initial 3-band EQ
        let bands = [
            RadioformBand(frequency: 100, gain: 0, qFactor: 0.707, filterType: .lowShelf),
            RadioformBand(frequency: 1000, gain: 0, qFactor: 1.0, filterType: .peak),
            RadioformBand(frequency: 8000, gain: 0, qFactor: 0.707, filterType: .highShelf)
        ]
        let preset = RadioformPreset.preset(withName: "3-Band EQ", bands: bands)
        try engine.apply(preset)
    }
}

struct EQControlView: View {
    @StateObject var viewModel = try! EQViewModel()

    var body: some View {
        VStack {
            Toggle("Bypass", isOn: $viewModel.bypass)

            VStack {
                Text("Bass: \(viewModel.bassGain, specifier: "%.1f") dB")
                Slider(value: $viewModel.bassGain, in: -12...12)
            }

            VStack {
                Text("Mid: \(viewModel.midGain, specifier: "%.1f") dB")
                Slider(value: $viewModel.midGain, in: -12...12)
            }

            VStack {
                Text("Treble: \(viewModel.trebleGain, specifier: "%.1f") dB")
                Slider(value: $viewModel.trebleGain, in: -12...12)
            }
        }
        .padding()
    }
}
```

## Best Practices

1. **Initialize Once**: Create the DSP engine once and reuse it
2. **Validate Presets**: Always call `isValid()` before applying
3. **Use Realtime Updates**: Prefer `updateBandGain()` over `applyPreset()` for UI sliders
4. **Enable Limiter**: Always enable limiter for user-facing EQ to prevent clipping
5. **Thread Safety**: Never call non-realtime-safe functions from audio thread
6. **Error Handling**: Always handle initialization errors gracefully
7. **Buffer Reuse**: Reuse audio buffers instead of allocating each frame
8. **Monitor Performance**: Check CPU usage periodically

## Additional Resources

- **RBJ Audio EQ Cookbook**: Technical reference for filter formulas
- **Apple Audio Documentation**: CoreAudio and AVFoundation guides
- **Radioform Source**: See `bridge/SwiftUsageExample.swift` for more examples
