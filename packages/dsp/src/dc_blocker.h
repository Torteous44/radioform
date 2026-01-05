/**
 * @file dc_blocker.h
 * @brief DC offset removal filter
 *
 * Prevents DC offset buildup that can occur with cascaded filters.
 * Uses a very simple one-pole high-pass filter at ~5Hz.
 */

#ifndef RADIOFORM_DC_BLOCKER_H
#define RADIOFORM_DC_BLOCKER_H

#include <cstdint>
#include <cmath>

namespace radioform {

/**
 * @brief DC blocking filter (one-pole HPF at ~5Hz)
 *
 * This prevents DC offset from accumulating
 * through the filter chain. It's essentially free in terms of CPU cost
 * (one multiply-add per sample).
 *
 * The filter is a simple first-order high-pass:
 * y[n] = x[n] - x[n-1] + coeff * y[n-1]
 */
class DCBlocker {
public:
    /**
     * @brief Initialize DC blocker
     *
     * @param sample_rate Sample rate in Hz
     * @param cutoff_hz Cutoff frequency (default 5Hz)
     */
    void init(float sample_rate, float cutoff_hz = 5.0f) {
        // Calculate coefficient for one-pole HPF
        // coeff = 1 - (2 * pi * fc / fs)
        // For 5Hz @ 48kHz: coeff ~= 0.9993
        const float w_c = 2.0f * M_PI * cutoff_hz / sample_rate;
        coeff_ = 1.0f - w_c;

        // Clamp to valid range
        if (coeff_ < 0.95f) coeff_ = 0.95f;
        if (coeff_ > 0.9999f) coeff_ = 0.9999f;

        reset();
    }

    /**
     * @brief Reset filter state
     */
    void reset() {
        x_prev_ = 0.0f;
        y_prev_ = 0.0f;
    }

    /**
     * @brief Process one sample
     */
    inline float process(float input) {
        // One-pole high-pass: y[n] = x[n] - x[n-1] + coeff * y[n-1]
        const float output = input - x_prev_ + coeff_ * y_prev_;
        x_prev_ = input;
        y_prev_ = output;
        return output;
    }

    /**
     * @brief Process stereo sample (in-place)
     */
    inline void processSampleStereo(float* left, float* right) {
        *left = process(*left);
        *right = process(*right);
    }

    /**
     * @brief Process buffer (planar stereo)
     */
    void processBuffer(
        float* left, float* right,
        uint32_t num_frames
    ) {
        for (uint32_t i = 0; i < num_frames; ++i) {
            left[i] = process(left[i]);
            right[i] = process(right[i]);
        }
    }

private:
    float coeff_ = 0.9993f;  // ~5Hz @ 48kHz
    float x_prev_ = 0.0f;    // Previous input
    float y_prev_ = 0.0f;    // Previous output
};

/**
 * @brief Stereo DC blocker (separate state for L/R channels)
 */
class StereoDCBlocker {
public:
    void init(float sample_rate, float cutoff_hz = 5.0f) {
        left_.init(sample_rate, cutoff_hz);
        right_.init(sample_rate, cutoff_hz);
    }

    void reset() {
        left_.reset();
        right_.reset();
    }

    inline void processStereo(float in_l, float in_r, float* out_l, float* out_r) {
        *out_l = left_.process(in_l);
        *out_r = right_.process(in_r);
    }

    void processBuffer(
        const float* in_l, const float* in_r,
        float* out_l, float* out_r,
        uint32_t num_frames
    ) {
        for (uint32_t i = 0; i < num_frames; ++i) {
            out_l[i] = left_.process(in_l[i]);
            out_r[i] = right_.process(in_r[i]);
        }
    }

private:
    DCBlocker left_;
    DCBlocker right_;
};

} // namespace radioform

#endif // RADIOFORM_DC_BLOCKER_H
