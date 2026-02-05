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

    func createFlatPreset() -> radioform_preset_t {
        var preset = radioform_preset_t()
        radioform_dsp_preset_init_flat(&preset)
        preset.num_bands = 0
        preset.preamp_db = 0.0
        preset.limiter_enabled = true
        preset.limiter_threshold_db = -0.1

        return preset
    }
}
