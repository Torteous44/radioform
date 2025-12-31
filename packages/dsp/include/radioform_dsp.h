/**
 * @file radioform_dsp.h
 * @brief Public C API for Radioform DSP engine
 *
 * This is the main API for the Radioform DSP library. It provides a clean,
 * stable C interface that can be called from C++, Objective-C++, and Swift.
 *
 * Thread Safety:
 * - Engine creation/destruction: NOT thread-safe (call from main thread)
 * - Parameter updates: Thread-safe (can call from any thread)
 * - Process function: Realtime-safe (call only from audio thread)
 *
 * Realtime Safety:
 * - radioform_dsp_process_*() functions are lock-free and allocation-free
 * - radioform_dsp_set_bypass() is lock-free
 * - All other functions may allocate and should not be called from audio thread
 */

#ifndef RADIOFORM_DSP_H
#define RADIOFORM_DSP_H

#include "radioform_types.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Opaque handle to DSP engine instance
 */
typedef struct radioform_dsp_engine radioform_dsp_engine_t;

// ============================================================================
// Engine Lifecycle
// ============================================================================

/**
 * @brief Create a new DSP engine instance
 *
 * @param sample_rate Sample rate in Hz (typically 44100 or 48000)
 * @return Pointer to engine instance, or NULL on failure
 *
 * @note This function allocates memory. Do NOT call from audio thread.
 * @note Caller must call radioform_dsp_destroy() to free resources.
 */
radioform_dsp_engine_t* radioform_dsp_create(uint32_t sample_rate);

/**
 * @brief Destroy a DSP engine instance
 *
 * @param engine Engine instance to destroy (must not be NULL)
 *
 * @note This function deallocates memory. Do NOT call from audio thread.
 * @note After calling this, the engine pointer is invalid.
 */
void radioform_dsp_destroy(radioform_dsp_engine_t* engine);

/**
 * @brief Reset engine state (clear filter history)
 *
 * @param engine Engine instance (must not be NULL)
 *
 * @note Useful when seeking in audio or recovering from underrun.
 * @note This is NOT realtime-safe (may allocate).
 */
void radioform_dsp_reset(radioform_dsp_engine_t* engine);

/**
 * @brief Change sample rate (requires reset)
 *
 * @param engine Engine instance (must not be NULL)
 * @param sample_rate New sample rate in Hz
 * @return RADIOFORM_OK on success, error code otherwise
 *
 * @note This will reset filter state and recalculate coefficients.
 * @note NOT realtime-safe.
 */
radioform_error_t radioform_dsp_set_sample_rate(
    radioform_dsp_engine_t* engine,
    uint32_t sample_rate
);

// ============================================================================
// Audio Processing (REALTIME-SAFE)
// ============================================================================

/**
 * @brief Process stereo audio (interleaved format)
 *
 * @param engine Engine instance (must not be NULL)
 * @param input Interleaved input buffer [L0, R0, L1, R1, ...]
 * @param output Interleaved output buffer [L0, R0, L1, R1, ...]
 * @param num_frames Number of stereo frames to process
 *
 * @note REALTIME-SAFE: No allocations, no locks, no system calls
 * @note Buffers must be at least num_frames * 2 samples in size
 * @note Input and output may point to the same buffer (in-place processing)
 */
void radioform_dsp_process_interleaved(
    radioform_dsp_engine_t* engine,
    const float* input,
    float* output,
    uint32_t num_frames
);

/**
 * @brief Process stereo audio (planar format)
 *
 * @param engine Engine instance (must not be NULL)
 * @param input_left Left channel input buffer
 * @param input_right Right channel input buffer
 * @param output_left Left channel output buffer
 * @param output_right Right channel output buffer
 * @param num_frames Number of frames to process per channel
 *
 * @note REALTIME-SAFE: No allocations, no locks, no system calls
 * @note Buffers must be at least num_frames samples in size
 * @note Input and output may point to the same buffers (in-place processing)
 */
void radioform_dsp_process_planar(
    radioform_dsp_engine_t* engine,
    const float* input_left,
    const float* input_right,
    float* output_left,
    float* output_right,
    uint32_t num_frames
);

// ============================================================================
// Preset Management (NOT realtime-safe)
// ============================================================================

/**
 * @brief Apply a complete preset to the engine
 *
 * @param engine Engine instance (must not be NULL)
 * @param preset Preset configuration (must not be NULL)
 * @return RADIOFORM_OK on success, error code otherwise
 *
 * @note NOT realtime-safe (recalculates filter coefficients)
 * @note Changes will be smoothly ramped in over ~50ms to avoid clicks
 * @note Call this from UI thread, not audio thread
 */
radioform_error_t radioform_dsp_apply_preset(
    radioform_dsp_engine_t* engine,
    const radioform_preset_t* preset
);

/**
 * @brief Get the currently active preset
 *
 * @param engine Engine instance (must not be NULL)
 * @param preset Pointer to preset struct to fill (must not be NULL)
 * @return RADIOFORM_OK on success, error code otherwise
 */
radioform_error_t radioform_dsp_get_preset(
    radioform_dsp_engine_t* engine,
    radioform_preset_t* preset
);

/**
 * @brief Create a flat preset (all bands disabled, 0dB gain)
 *
 * @param preset Pointer to preset struct to initialize (must not be NULL)
 *
 * @note Useful for creating a baseline preset to modify
 */
void radioform_dsp_preset_init_flat(radioform_preset_t* preset);

/**
 * @brief Validate preset parameters are within valid ranges
 *
 * @param preset Preset to validate (must not be NULL)
 * @return RADIOFORM_OK if valid, error code otherwise
 */
radioform_error_t radioform_dsp_preset_validate(const radioform_preset_t* preset);

// ============================================================================
// Realtime Parameter Updates (Lock-free)
// ============================================================================

/**
 * @brief Set bypass mode (REALTIME-SAFE)
 *
 * @param engine Engine instance (must not be NULL)
 * @param bypass true to bypass DSP (passthrough), false to process
 *
 * @note REALTIME-SAFE: Uses atomic operation, safe to call from any thread
 * @note Bypass is instant (no ramping) to preserve audio in emergency
 */
void radioform_dsp_set_bypass(radioform_dsp_engine_t* engine, bool bypass);

/**
 * @brief Get current bypass state (REALTIME-SAFE)
 *
 * @param engine Engine instance (must not be NULL)
 * @return true if bypassed, false if processing
 */
bool radioform_dsp_get_bypass(const radioform_dsp_engine_t* engine);

/**
 * @brief Update a single band's gain in realtime (REALTIME-SAFE)
 *
 * @param engine Engine instance (must not be NULL)
 * @param band_index Band index (0 to num_bands-1)
 * @param gain_db New gain in dB (-12.0 to +12.0)
 *
 * @note REALTIME-SAFE: Queues parameter change, applied with smoothing
 * @note Safe to call from UI thread while audio is processing
 * @note Changes are applied over ~10ms to avoid zipper noise
 */
void radioform_dsp_update_band_gain(
    radioform_dsp_engine_t* engine,
    uint32_t band_index,
    float gain_db
);

/**
 * @brief Update preamp gain in realtime (REALTIME-SAFE)
 *
 * @param engine Engine instance (must not be NULL)
 * @param gain_db New preamp gain in dB (-12.0 to +12.0)
 *
 * @note REALTIME-SAFE: Queues parameter change, applied with smoothing
 */
void radioform_dsp_update_preamp(
    radioform_dsp_engine_t* engine,
    float gain_db
);

/**
 * @brief Update a band's frequency in realtime (REALTIME-SAFE)
 *
 * @param engine Engine instance (must not be NULL)
 * @param band_index Band index (0 to num_bands-1)
 * @param frequency_hz New center frequency in Hz (20.0 to 20000.0)
 *
 * @note REALTIME-SAFE: Changes are applied with smoothing to avoid clicks
 * @note Safe to call from UI thread while audio is processing
 */
void radioform_dsp_update_band_frequency(
    radioform_dsp_engine_t* engine,
    uint32_t band_index,
    float frequency_hz
);

/**
 * @brief Update a band's Q factor in realtime (REALTIME-SAFE)
 *
 * @param engine Engine instance (must not be NULL)
 * @param band_index Band index (0 to num_bands-1)
 * @param q_factor New Q factor (0.1 to 10.0)
 *
 * @note REALTIME-SAFE: Changes are applied with smoothing to avoid clicks
 * @note Safe to call from UI thread while audio is processing
 */
void radioform_dsp_update_band_q(
    radioform_dsp_engine_t* engine,
    uint32_t band_index,
    float q_factor
);

// ============================================================================
// Diagnostics
// ============================================================================

/**
 * @brief Get engine statistics
 *
 * @param engine Engine instance (must not be NULL)
 * @param stats Pointer to stats struct to fill (must not be NULL)
 *
 * @note Safe to call from any thread (reads atomic counters)
 */
void radioform_dsp_get_stats(
    const radioform_dsp_engine_t* engine,
    radioform_stats_t* stats
);

/**
 * @brief Get library version string
 *
 * @return Version string (e.g., "1.0.0")
 */
const char* radioform_dsp_get_version(void);

// ============================================================================
// Performance Optimizations
// ============================================================================

/**
 * @brief Enable denormal number suppression on current thread
 *
 * Denormal (subnormal) floating-point numbers can cause severe performance
 * degradation (10-100x slowdown) on some CPUs. This function enables
 * hardware flush-to-zero (FTZ) and denormals-are-zero (DAZ) modes.
 *
 * @note This affects only the calling thread
 * @note Automatically called in radioform_dsp_create(), but you should
 *       also call this once from your audio thread for best performance
 * @note REALTIME-SAFE: No allocations, just sets CPU flags
 *
 * Example usage:
 * @code
 * // In your audio thread initialization:
 * radioform_dsp_enable_denormal_suppression();
 * @endcode
 */
void radioform_dsp_enable_denormal_suppression(void);

#ifdef __cplusplus
}
#endif

#endif // RADIOFORM_DSP_H
