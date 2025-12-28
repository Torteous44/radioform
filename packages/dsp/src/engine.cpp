/**
 * @file engine.cpp
 * @brief Main DSP engine implementation
 *
 * This implements the public C API defined in radioform_dsp.h.
 * It's a clean, self-contained parametric EQ with no external dependencies.
 */

#include "radioform_dsp.h"
#include "biquad.h"
#include "smoothing.h"
#include "limiter.h"

#include <cstring>
#include <cmath>
#include <atomic>
#include <array>

using namespace radioform;

// ============================================================================
// Engine Internal Structure
// ============================================================================

struct radioform_dsp_engine {
    // Sample rate
    uint32_t sample_rate;

    // EQ bands (each biquad handles stereo)
    std::array<Biquad, RADIOFORM_MAX_BANDS> bands;
    uint32_t num_active_bands;

    // Current preset configuration
    radioform_preset_t current_preset;

    // Parameter smoothing
    ParameterSmoother preamp_smoother;

    // Limiter
    SoftLimiter limiter;
    bool limiter_enabled;

    // Bypass (atomic for lock-free realtime control)
    std::atomic<bool> bypass;

    // Statistics
    std::atomic<uint64_t> frames_processed;
    std::atomic<uint32_t> underrun_count;

    // Constructor
    radioform_dsp_engine(uint32_t sr)
        : sample_rate(sr)
        , num_active_bands(0)
        , limiter_enabled(true)
        , bypass(false)
        , frames_processed(0)
        , underrun_count(0)
    {
        // Initialize with flat preset
        radioform_dsp_preset_init_flat(&current_preset);

        // Initialize all biquads
        for (auto& bq : bands) {
            bq.init();
        }

        // Initialize smoothers
        preamp_smoother.init(static_cast<float>(sample_rate), 10.0f); // 10ms ramp
        preamp_smoother.setValue(1.0f); // 0dB = gain of 1.0

        // Initialize limiter
        limiter.init(-0.1f); // -0.1 dB threshold
    }
};

// ============================================================================
// Engine Lifecycle
// ============================================================================

radioform_dsp_engine_t* radioform_dsp_create(uint32_t sample_rate) {
    if (sample_rate < 8000 || sample_rate > 384000) {
        return nullptr; // Invalid sample rate
    }

    try {
        return new radioform_dsp_engine(sample_rate);
    } catch (...) {
        return nullptr;
    }
}

void radioform_dsp_destroy(radioform_dsp_engine_t* engine) {
    if (engine) {
        delete engine;
    }
}

void radioform_dsp_reset(radioform_dsp_engine_t* engine) {
    if (!engine) return;

    // Reset all filter state
    for (auto& bq : engine->bands) {
        bq.reset();
    }

    // Reset statistics
    engine->frames_processed.store(0);
    engine->underrun_count.store(0);
}

radioform_error_t radioform_dsp_set_sample_rate(
    radioform_dsp_engine_t* engine,
    uint32_t sample_rate
) {
    if (!engine) return RADIOFORM_ERROR_NULL_POINTER;
    if (sample_rate < 8000 || sample_rate > 384000) {
        return RADIOFORM_ERROR_INVALID_PARAM;
    }

    engine->sample_rate = sample_rate;

    // Reinitialize smoothers with new sample rate
    engine->preamp_smoother.init(static_cast<float>(sample_rate), 10.0f);

    // Recalculate filter coefficients
    return radioform_dsp_apply_preset(engine, &engine->current_preset);
}

// ============================================================================
// Audio Processing (REALTIME-SAFE)
// ============================================================================

void radioform_dsp_process_interleaved(
    radioform_dsp_engine_t* engine,
    const float* input,
    float* output,
    uint32_t num_frames
) {
    if (!engine || !input || !output || num_frames == 0) return;

    // Check bypass
    if (engine->bypass.load(std::memory_order_relaxed)) {
        // Passthrough
        if (input != output) {
            std::memcpy(output, input, num_frames * 2 * sizeof(float));
        }
        return;
    }

    // Process each frame
    for (uint32_t i = 0; i < num_frames; i++) {
        // Deinterleave
        float left = input[i * 2];
        float right = input[i * 2 + 1];

        // Apply preamp (with smoothing)
        const float preamp_gain = engine->preamp_smoother.next();
        left *= preamp_gain;
        right *= preamp_gain;

        // Process through EQ bands
        for (uint32_t band = 0; band < engine->num_active_bands; band++) {
            if (engine->current_preset.bands[band].enabled) {
                // Each biquad processes both channels
                engine->bands[band].processSample(left, right, &left, &right);
            }
        }

        // Apply limiter if enabled
        if (engine->limiter_enabled) {
            engine->limiter.processSampleStereo(&left, &right);
        }

        // Interleave output
        output[i * 2] = left;
        output[i * 2 + 1] = right;
    }

    // Update statistics
    engine->frames_processed.fetch_add(num_frames, std::memory_order_relaxed);
}

void radioform_dsp_process_planar(
    radioform_dsp_engine_t* engine,
    const float* input_left,
    const float* input_right,
    float* output_left,
    float* output_right,
    uint32_t num_frames
) {
    if (!engine || !input_left || !input_right || !output_left || !output_right || num_frames == 0) {
        return;
    }

    // Check bypass
    if (engine->bypass.load(std::memory_order_relaxed)) {
        // Passthrough
        if (input_left != output_left) {
            std::memcpy(output_left, input_left, num_frames * sizeof(float));
        }
        if (input_right != output_right) {
            std::memcpy(output_right, input_right, num_frames * sizeof(float));
        }
        return;
    }

    // Copy input to output first (we'll process in-place)
    if (input_left != output_left) {
        std::memcpy(output_left, input_left, num_frames * sizeof(float));
    }
    if (input_right != output_right) {
        std::memcpy(output_right, input_right, num_frames * sizeof(float));
    }

    // Apply preamp (with smoothing)
    for (uint32_t i = 0; i < num_frames; i++) {
        const float preamp_gain = engine->preamp_smoother.next();
        output_left[i] *= preamp_gain;
        output_right[i] *= preamp_gain;
    }

    // Process through EQ bands
    for (uint32_t band = 0; band < engine->num_active_bands; band++) {
        if (engine->current_preset.bands[band].enabled) {
            // Each biquad processes both channels
            engine->bands[band].processBuffer(
                output_left, output_right,
                output_left, output_right,
                num_frames
            );
        }
    }

    // Apply limiter if enabled
    if (engine->limiter_enabled) {
        engine->limiter.processBuffer(output_left, output_right, num_frames);
    }

    // Update statistics
    engine->frames_processed.fetch_add(num_frames, std::memory_order_relaxed);
}

// ============================================================================
// Preset Management (NOT realtime-safe)
// ============================================================================

radioform_error_t radioform_dsp_apply_preset(
    radioform_dsp_engine_t* engine,
    const radioform_preset_t* preset
) {
    if (!engine || !preset) {
        return RADIOFORM_ERROR_NULL_POINTER;
    }

    // Validate preset
    radioform_error_t err = radioform_dsp_preset_validate(preset);
    if (err != RADIOFORM_OK) {
        return err;
    }

    // Copy preset
    std::memcpy(&engine->current_preset, preset, sizeof(radioform_preset_t));
    engine->num_active_bands = preset->num_bands;

    // Update filter coefficients for each band
    for (uint32_t i = 0; i < preset->num_bands; i++) {
        const radioform_band_t& band = preset->bands[i];

        if (band.enabled) {
            engine->bands[i].setCoeffs(band, static_cast<float>(engine->sample_rate));
        } else {
            // Disabled band - set to flat response
            engine->bands[i].setCoeffsFlat();
        }
    }

    // Update preamp
    float preamp_gain = db_to_gain(preset->preamp_db);
    engine->preamp_smoother.setTarget(preamp_gain);

    // Update limiter
    engine->limiter_enabled = preset->limiter_enabled;
    if (preset->limiter_enabled) {
        engine->limiter.setThreshold(preset->limiter_threshold_db);
    }

    return RADIOFORM_OK;
}

radioform_error_t radioform_dsp_get_preset(
    radioform_dsp_engine_t* engine,
    radioform_preset_t* preset
) {
    if (!engine || !preset) {
        return RADIOFORM_ERROR_NULL_POINTER;
    }

    std::memcpy(preset, &engine->current_preset, sizeof(radioform_preset_t));
    return RADIOFORM_OK;
}

// ============================================================================
// Realtime Parameter Updates (Lock-free)
// ============================================================================

void radioform_dsp_set_bypass(radioform_dsp_engine_t* engine, bool bypass) {
    if (engine) {
        engine->bypass.store(bypass, std::memory_order_relaxed);
    }
}

bool radioform_dsp_get_bypass(const radioform_dsp_engine_t* engine) {
    return engine ? engine->bypass.load(std::memory_order_relaxed) : true;
}

void radioform_dsp_update_band_gain(
    radioform_dsp_engine_t* engine,
    uint32_t band_index,
    float gain_db
) {
    if (!engine || band_index >= engine->num_active_bands) return;

    // Clamp gain
    gain_db = std::max(-12.0f, std::min(12.0f, gain_db));

    // Update preset
    engine->current_preset.bands[band_index].gain_db = gain_db;

    // Recalculate coefficients
    const radioform_band_t& band = engine->current_preset.bands[band_index];
    engine->bands[band_index].setCoeffs(band, static_cast<float>(engine->sample_rate));
}

void radioform_dsp_update_preamp(
    radioform_dsp_engine_t* engine,
    float gain_db
) {
    if (!engine) return;

    // Clamp gain
    gain_db = std::max(-12.0f, std::min(12.0f, gain_db));

    // Update preset
    engine->current_preset.preamp_db = gain_db;

    // Update smoother target
    float target_gain = db_to_gain(gain_db);
    engine->preamp_smoother.setTarget(target_gain);
}

// ============================================================================
// Diagnostics
// ============================================================================

void radioform_dsp_get_stats(
    const radioform_dsp_engine_t* engine,
    radioform_stats_t* stats
) {
    if (!engine || !stats) return;

    stats->frames_processed = engine->frames_processed.load(std::memory_order_relaxed);
    stats->underrun_count = engine->underrun_count.load(std::memory_order_relaxed);
    stats->cpu_load_percent = 0.0f; // TODO: implement CPU load measurement
    stats->bypass_active = engine->bypass.load(std::memory_order_relaxed);
    stats->sample_rate = engine->sample_rate;
}
