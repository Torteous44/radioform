/**
 * @file limiter.h
 * @brief Simple soft limiter to prevent clipping
 */

#ifndef RADIOFORM_LIMITER_H
#define RADIOFORM_LIMITER_H

#include <cstdint>
#include <cmath>
#include <algorithm>

namespace radioform {

/**
 * @brief soft-knee limiter
 *
 * Uses a rational function soft clipping curve that is smoother and more
 * transparent than tanh, with the same computational cost.
 *
 * This is not a look-ahead limiter, so it's very low latency but may
 * still clip on extremely fast transients. The rational function provides
 * cleaner harmonics and less "grunge" than tanh.
 */
class SoftLimiter {
public:
    /**
     * @brief Initialize limiter
     *
     * @param threshold_db Threshold in dB below 0dBFS (e.g., -0.1)
     */
    void init(float threshold_db = -0.1f) {
        setThreshold(threshold_db);
    }

    /**
     * @brief Set limiter threshold
     *
     * @param threshold_db Threshold in dB (typically -6.0 to 0.0)
     */
    void setThreshold(float threshold_db) {
        threshold_ = std::pow(10.0f, threshold_db / 20.0f);
        // Knee width for smooth transition (starts softening at 80% of threshold)
        knee_start_ = threshold_ * 0.8f;
    }

    /**
     * @brief Process one sample (in-place)
     */
    inline float processSample(float input) {
        const float abs_input = std::abs(input);

        // Below knee: pass through
        if (abs_input <= knee_start_) {
            return input;
        }

        // Above knee: apply soft limiting
        // Using rational function: x / (1 + |x|)
        // This is smoother than tanh and produces cleaner harmonics
        const float scaled = (abs_input - knee_start_) / (threshold_ - knee_start_);
        const float limited = knee_start_ + (threshold_ - knee_start_) *
                             (scaled / (1.0f + scaled));

        // Preserve sign
        return (input < 0.0f) ? -limited : limited;
    }

    /**
     * @brief Process stereo sample (in-place)
     */
    inline void processSampleStereo(float* left, float* right) {
        *left = processSample(*left);
        *right = processSample(*right);
    }

    /**
     * @brief Process buffer (planar stereo)
     */
    void processBuffer(
        float* left, float* right,
        uint32_t num_frames
    ) {
        for (uint32_t i = 0; i < num_frames; ++i) {
            left[i] = processSample(left[i]);
            right[i] = processSample(right[i]);
        }
    }

private:
    float threshold_ = 0.99f;    // ~-0.1 dB
    float knee_start_ = 0.792f;  // 80% of threshold
};

/**
 * @brief Hard clipper (simpler, more aggressive)
 *
 * Just clamps values to [-threshold, +threshold].
 * Can cause harsh distortion but is very fast.
 */
class HardClipper {
public:
    void init(float threshold = 1.0f) {
        threshold_ = threshold;
    }

    inline float processSample(float input) {
        return std::clamp(input, -threshold_, threshold_);
    }

    void processBuffer(float* left, float* right, uint32_t num_frames) {
        for (uint32_t i = 0; i < num_frames; ++i) {
            left[i] = processSample(left[i]);
            right[i] = processSample(right[i]);
        }
    }

private:
    float threshold_ = 1.0f;
};

} // namespace radioform

#endif // RADIOFORM_LIMITER_H
