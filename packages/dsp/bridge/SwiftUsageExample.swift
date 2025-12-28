/**
 * Swift Usage Example for Radioform DSP Bridge
 *
 * This demonstrates how to use the Objective-C++ bridge from Swift.
 * Add RadioformDSPEngine.h to your bridging header to use these APIs.
 */

import Foundation

// ============================================================================
// Example 1: Basic Setup
// ============================================================================

func example1_BasicSetup() throws {
    // Create engine with 48kHz sample rate
    let engine = try RadioformDSPEngine(sampleRate: 48000)

    // Apply a flat preset (transparent processing)
    let preset = RadioformPreset.flatPreset()
    try engine.apply(preset)

    print("Engine created and flat preset applied")
}

// ============================================================================
// Example 2: Creating Custom Presets
// ============================================================================

func example2_CustomPreset() throws {
    let engine = try RadioformDSPEngine(sampleRate: 48000)

    // Create a "Bass Boost" preset
    let bassShelf = RadioformBand(
        frequency: 100.0,    // 100 Hz
        gain: 6.0,           // +6 dB boost
        qFactor: 0.707,      // Standard shelf slope
        filterType: .lowShelf
    )

    let preset = RadioformPreset.preset(
        withName: "Bass Boost",
        bands: [bassShelf]
    )
    preset.preampDb = -3.0  // Reduce preamp to prevent clipping
    preset.limiterEnabled = true

    try engine.apply(preset)
    print("Bass Boost preset applied")
}

// ============================================================================
// Example 3: 10-Band Graphic EQ
// ============================================================================

func example3_GraphicEQ() throws {
    let engine = try RadioformDSPEngine(sampleRate: 48000)

    // Standard 10-band graphic EQ frequencies
    let frequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    let gains: [Float] = [3, 2, 0, -2, -3, -2, 0, 2, 4, 3] // "V-shaped" curve

    var bands: [RadioformBand] = []
    for (freq, gain) in zip(frequencies, gains) {
        let band = RadioformBand(
            frequency: freq,
            gain: gain,
            qFactor: 1.0,
            filterType: .peak
        )
        bands.append(band)
    }

    let preset = RadioformPreset.preset(withName: "V-Shaped", bands: bands)
    try engine.apply(preset)
    print("10-band graphic EQ applied")
}

// ============================================================================
// Example 4: Audio Processing
// ============================================================================

func example4_ProcessAudio() throws {
    let engine = try RadioformDSPEngine(sampleRate: 48000)

    // Apply some EQ
    let band = RadioformBand(frequency: 1000, gain: 6.0, qFactor: 2.0, filterType: .peak)
    let preset = RadioformPreset.preset(withName: "Test", bands: [band])
    try engine.apply(preset)

    // Allocate audio buffers (512 frames stereo)
    let frameCount: UInt32 = 512
    var inputBuffer = [Float](repeating: 0.0, count: Int(frameCount * 2))
    var outputBuffer = [Float](repeating: 0.0, count: Int(frameCount * 2))

    // Fill input with test signal (1kHz sine wave)
    for i in 0..<Int(frameCount) {
        let phase = Float(i) / 48000.0 * 1000.0 * 2.0 * Float.pi
        let sample = sin(phase)
        inputBuffer[i * 2] = sample      // Left
        inputBuffer[i * 2 + 1] = sample  // Right
    }

    // Process audio (interleaved format)
    engine.processInterleaved(
        inputBuffer,
        output: &outputBuffer,
        frameCount: frameCount
    )

    print("Processed \(frameCount) frames")
}

// ============================================================================
// Example 5: Realtime Parameter Updates
// ============================================================================

class AudioProcessor {
    let engine: RadioformDSPEngine

    init(sampleRate: UInt32 = 48000) throws {
        engine = try RadioformDSPEngine(sampleRate: sampleRate)

        // Set up initial preset
        let bands = [
            RadioformBand(frequency: 100, gain: 0, qFactor: 0.707, filterType: .lowShelf),
            RadioformBand(frequency: 1000, gain: 0, qFactor: 1.0, filterType: .peak),
            RadioformBand(frequency: 8000, gain: 0, qFactor: 0.707, filterType: .highShelf)
        ]
        let preset = RadioformPreset.preset(withName: "Dynamic EQ", bands: bands)
        try engine.apply(preset)
    }

    // Called from UI thread
    func updateBass(gain: Float) {
        // Safe to call from any thread
        engine.updateBandGain(0, gainDb: gain)
    }

    func updateMid(gain: Float) {
        engine.updateBandGain(1, gainDb: gain)
    }

    func updateTreble(gain: Float) {
        engine.updateBandGain(2, gainDb: gain)
    }

    func setBypass(_ enabled: Bool) {
        engine.bypass = enabled
    }

    // Called from audio thread
    func processAudio(inputLeft: UnsafePointer<Float>,
                     inputRight: UnsafePointer<Float>,
                     outputLeft: UnsafeMutablePointer<Float>,
                     outputRight: UnsafeMutablePointer<Float>,
                     frameCount: UInt32) {
        engine.processPlanar(
            inputLeft,
            right: inputRight,
            outputLeft: outputLeft,
            outputRight: outputRight,
            frameCount: frameCount
        )
    }
}

// ============================================================================
// Example 6: Statistics and Monitoring
// ============================================================================

func example6_Statistics() throws {
    let engine = try RadioformDSPEngine(sampleRate: 48000)

    // Process some audio...
    let frameCount: UInt32 = 512
    var buffer = [Float](repeating: 0.5, count: Int(frameCount * 2))
    engine.processInterleaved(buffer, output: &buffer, frameCount: frameCount)

    // Get statistics
    let stats = engine.statistics()
    print("Frames processed: \(stats.framesProcessed)")
    print("Sample rate: \(stats.sampleRate)")
    print("Bypass active: \(stats.bypassActive)")
    print("CPU load: \(stats.cpuLoadPercent)%")
}

// ============================================================================
// Example 7: Error Handling
// ============================================================================

func example7_ErrorHandling() {
    do {
        // Invalid sample rate
        let engine = try RadioformDSPEngine(sampleRate: 1000)
        print("Should not reach here")
    } catch let error as NSError {
        print("Error creating engine: \(error.localizedDescription)")
        print("Error code: \(error.code)")
    }

    // Valid engine
    do {
        let engine = try RadioformDSPEngine(sampleRate: 48000)

        // Invalid preset (frequency out of range)
        let preset = RadioformPreset.flatPreset()
        let badBand = RadioformBand(
            frequency: 30000,  // Too high!
            gain: 0,
            qFactor: 1.0,
            filterType: .peak
        )
        preset.bands = [badBand]

        // Validate before applying
        if preset.isValid() {
            try engine.apply(preset)
        } else {
            print("Preset validation failed")
        }
    } catch {
        print("Error: \(error)")
    }
}

// ============================================================================
// Example 8: Preset Management
// ============================================================================

class PresetManager {
    private var presets: [String: RadioformPreset] = [:]

    init() {
        // Add default presets
        presets["Flat"] = .flatPreset()
        presets["Bass Boost"] = createBassBoost()
        presets["Treble Boost"] = createTrebleBoost()
        presets["Vocal Enhance"] = createVocalEnhance()
    }

    func createBassBoost() -> RadioformPreset {
        let bands = [
            RadioformBand(frequency: 60, gain: 8, qFactor: 0.707, filterType: .lowShelf),
            RadioformBand(frequency: 200, gain: 3, qFactor: 1.0, filterType: .peak)
        ]
        return RadioformPreset.preset(withName: "Bass Boost", bands: bands)
    }

    func createTrebleBoost() -> RadioformPreset {
        let bands = [
            RadioformBand(frequency: 8000, gain: 6, qFactor: 0.707, filterType: .highShelf)
        ]
        return RadioformPreset.preset(withName: "Treble Boost", bands: bands)
    }

    func createVocalEnhance() -> RadioformPreset {
        let bands = [
            RadioformBand(frequency: 200, gain: -3, qFactor: 1.0, filterType: .highPass),
            RadioformBand(frequency: 3000, gain: 4, qFactor: 2.0, filterType: .peak),
            RadioformBand(frequency: 8000, gain: -2, qFactor: 1.0, filterType: .peak)
        ]
        let preset = RadioformPreset.preset(withName: "Vocal Enhance", bands: bands)
        preset.limiterEnabled = true
        return preset
    }

    func getPreset(_ name: String) -> RadioformPreset? {
        return presets[name]
    }

    func savePreset(_ preset: RadioformPreset, name: String) {
        presets[name] = preset.copy() as? RadioformPreset
    }
}

// ============================================================================
// Usage Notes
// ============================================================================

/*
 THREAD SAFETY:

 Audio Thread Safe (realtime):
 - processInterleaved()
 - processPlanarLeft:right:outputLeft:outputRight:frameCount:
 - bypass (get/set)
 - updateBandGain()
 - updatePreampGain()

 NOT Audio Thread Safe (use on config thread):
 - applyPreset()
 - setSampleRate()
 - reset()
 - currentPreset()
 - statistics()

 PERFORMANCE:
 - The DSP engine is designed for realtime audio processing
 - Typical CPU usage: <1% on Apple Silicon for 48kHz stereo
 - All filters use optimized biquad cascade architecture
 - No heap allocations in audio processing path

 INTEGRATION:
 1. Add RadioformDSPEngine.h to your bridging header
 2. Link libradioform_dsp.a and libradioform_dsp_bridge.a
 3. Create engine in your audio setup code
 4. Call process() from your audio callback
 5. Update parameters from UI thread as needed
 */
