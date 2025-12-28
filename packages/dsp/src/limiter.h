/**
 * @file limiter.h
 * @brief Simple soft limiter to prevent clipping
 */

#ifndef RADIOFORM_LIMITER_H
#define RADIOFORM_LIMITER_H

#include <cmath>
#include <algorithm>

namespace radioform {

/**
 * @brief Simple soft-knee limiter
 *
 * Uses a tanh-based soft clipping function to prevent harsh clipping.
 * This is not a look-ahead limiter, so it's very low latency but may
 * still clip on extremely fast transients.
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
    }

    /**
     * @brief Process one sample (in-place)
     */
    inline float processSample(float input) {
        // Soft clip using tanh
        // tanh(x) smoothly compresses values > 1.0
        const float scaled = input / threshold_;
        return threshold_ * std::tanh(scaled);
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
        for (uint32_t i = 0; i < num_frames; i++) {
            left[i] = processSample(left[i]);
            right[i] = processSample(right[i]);
        }
    }

private:
    float threshold_ = 0.99f; // ~-0.1 dB
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
        for (uint32_t i = 0; i < num_frames; i++) {
            left[i] = processSample(left[i]);
            right[i] = processSample(right[i]);
        }
    }

private:
    float threshold_ = 1.0f;
};

} // namespace radioform

#endif // RADIOFORM_LIMITER_H
