/**
 * @file preset.cpp
 * @brief Preset validation and initialization
 */

#include "radioform_dsp.h"
#include <cstring>
#include <cmath>

void radioform_dsp_preset_init_flat(radioform_preset_t* preset) {
    if (!preset) return;

    // Clear all memory
    std::memset(preset, 0, sizeof(radioform_preset_t));

    // Initialize with flat response (all bands disabled)
    preset->num_bands = RADIOFORM_MAX_BANDS;

    // Default 10-band EQ frequencies (standard graphic EQ)
    const float default_frequencies[RADIOFORM_MAX_BANDS] = {
        32.0f, 64.0f, 125.0f, 250.0f, 500.0f,
        1000.0f, 2000.0f, 4000.0f, 8000.0f, 16000.0f
    };

    for (uint32_t i = 0; i < RADIOFORM_MAX_BANDS; i++) {
        preset->bands[i].frequency_hz = default_frequencies[i];
        preset->bands[i].gain_db = 0.0f;
        preset->bands[i].q_factor = 1.0f; // Default Q
        preset->bands[i].type = RADIOFORM_FILTER_PEAK;
        preset->bands[i].enabled = false; // Disabled by default
    }

    // Initialize global settings
    preset->preamp_db = 0.0f;
    preset->limiter_enabled = false; // Disabled for flat preset (transparent testing)
    preset->limiter_threshold_db = -0.1f; // Just below 0dB

    // Set default name
    std::strncpy(preset->name, "Flat", sizeof(preset->name) - 1);
    preset->name[sizeof(preset->name) - 1] = '\0';
}

radioform_error_t radioform_dsp_preset_validate(const radioform_preset_t* preset) {
    if (!preset) {
        return RADIOFORM_ERROR_NULL_POINTER;
    }

    // Validate number of bands
    if (preset->num_bands == 0 || preset->num_bands > RADIOFORM_MAX_BANDS) {
        return RADIOFORM_ERROR_INVALID_PARAM;
    }

    // Validate each band
    for (uint32_t i = 0; i < preset->num_bands; i++) {
        const radioform_band_t* band = &preset->bands[i];

        // Validate frequency (20 Hz to 20 kHz)
        if (band->frequency_hz < 20.0f || band->frequency_hz > 20000.0f) {
            return RADIOFORM_ERROR_INVALID_PARAM;
        }

        // Validate gain (-12 dB to +12 dB)
        if (band->gain_db < -12.0f || band->gain_db > 12.0f) {
            return RADIOFORM_ERROR_INVALID_PARAM;
        }

        // Validate Q factor (0.1 to 10.0)
        if (band->q_factor < 0.1f || band->q_factor > 10.0f) {
            return RADIOFORM_ERROR_INVALID_PARAM;
        }

        // Validate filter type
        if (band->type < RADIOFORM_FILTER_PEAK || band->type > RADIOFORM_FILTER_BAND_PASS) {
            return RADIOFORM_ERROR_INVALID_PARAM;
        }
    }

    // Validate preamp (-12 dB to +12 dB)
    if (preset->preamp_db < -12.0f || preset->preamp_db > 12.0f) {
        return RADIOFORM_ERROR_INVALID_PARAM;
    }

    // Validate limiter threshold (-6 dB to 0 dB)
    if (preset->limiter_threshold_db < -6.0f || preset->limiter_threshold_db > 0.0f) {
        return RADIOFORM_ERROR_INVALID_PARAM;
    }

    // Check for NaN or infinity
    if (std::isnan(preset->preamp_db) || std::isinf(preset->preamp_db)) {
        return RADIOFORM_ERROR_INVALID_PARAM;
    }

    return RADIOFORM_OK;
}
