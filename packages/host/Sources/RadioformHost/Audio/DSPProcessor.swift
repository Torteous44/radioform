import Foundation
import CRadioformDSP

class DSPProcessor {
    private var engine: OpaquePointer?

    init(sampleRate: UInt32) {
        engine = radioform_dsp_create(sampleRate)
    }

    deinit {
        if let engine = engine {
            radioform_dsp_destroy(engine)
        }
    }

    func applyPreset(_ preset: radioform_preset_t) -> Bool {
        guard let engine = engine else { return false }

        var mutablePreset = preset
        if radioform_dsp_apply_preset(engine, &mutablePreset) == RADIOFORM_OK {
            return true
        }
        return false
    }

    func processInterleaved(
        _ input: [Float],
        output: inout [Float],
        frameCount: UInt32
    ) {
        guard let engine = engine else { return }
        radioform_dsp_process_interleaved(engine, input, &output, frameCount)
    }

    func createBassBoostPreset() -> radioform_preset_t {
        var preset = radioform_preset_t()
        radioform_dsp_preset_init_flat(&preset)
        preset.num_bands = 2

        preset.bands.0.frequency_hz = 100
        preset.bands.0.gain_db = 6.0
        preset.bands.0.q_factor = 0.707
        preset.bands.0.type = RADIOFORM_FILTER_LOW_SHELF
        preset.bands.0.enabled = true

        preset.bands.1.frequency_hz = 60
        preset.bands.1.gain_db = 3.0
        preset.bands.1.q_factor = 1.0
        preset.bands.1.type = RADIOFORM_FILTER_PEAK
        preset.bands.1.enabled = true

        preset.preamp_db = 0.0
        preset.limiter_enabled = true
        preset.limiter_threshold_db = -1.0

        return preset
    }
}
