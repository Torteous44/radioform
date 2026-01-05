/**
 * @file smoothing.h
 * @brief Parameter smoothing to prevent zipper noise
 */

#ifndef RADIOFORM_SMOOTHING_H
#define RADIOFORM_SMOOTHING_H

#include <cstdint>
#include <cmath>

namespace radioform {

/**
 * @brief Zero-zipper parameter smoother with polynomial ramping
 *
 * Uses exponential smoothing with improved ramping characteristics.
 * This prevents audible clicks/zippers when parameters change, with
 * smoother transitions than simple one-pole filters.
 */
class ParameterSmoother {
public:
    /**
     * @brief Initialize smoother
     *
     * @param sample_rate Sample rate in Hz
     * @param time_constant_ms Time to reach ~63% of target value (in milliseconds)
     */
    void init(float sample_rate, float time_constant_ms = 10.0f) {
        sample_rate_ = sample_rate;
        setTimeConstant(time_constant_ms);
        current_ = 0.0f;
        target_ = 0.0f;
        velocity_ = 0.0f;
    }

    /**
     * @brief Set the time constant for smoothing
     *
     * @param time_constant_ms Time constant in milliseconds
     */
    void setTimeConstant(float time_constant_ms) {
        // Calculate one-pole filter coefficient
        // tau = time_constant * sample_rate / 1000
        // coeff = exp(-1 / tau)
        float tau = time_constant_ms * sample_rate_ / 1000.0f;
        if (tau > 0.0f) {
            coeff_ = std::exp(-1.0f / tau);
        } else {
            coeff_ = 0.0f; // Instant change
        }

        // Velocity damping coefficient (slightly faster than main coeff)
        velocity_coeff_ = coeff_ * 0.95f;
    }

    /**
     * @brief Set target value
     *
     * @param target New target value
     */
    void setTarget(float target) {
        target_ = target;
    }

    /**
     * @brief Set current value immediately (no smoothing)
     *
     * @param value Value to set
     */
    void setValue(float value) {
        current_ = value;
        target_ = value;
        velocity_ = 0.0f;
    }

    /**
     * @brief Get next smoothed value (zero-zipper algorithm)
     *
     * Uses velocity tracking for smoother parameter transitions.
     * This eliminates subtle phase modulation artifacts during parameter sweeps.
     *
     * @return Smoothed value (moves toward target)
     */
    inline float next() {
        // Calculate error
        const float error = target_ - current_;

        // Update velocity with damping
        velocity_ = velocity_coeff_ * velocity_ + (1.0f - velocity_coeff_) * error;

        // Update current value using velocity (second-order smoothing)
        current_ = coeff_ * current_ + (1.0f - coeff_) * (target_ - velocity_ * 0.5f);

        return current_;
    }

    /**
     * @brief Check if value has reached target (within epsilon)
     *
     * @param epsilon Tolerance (default 0.0001)
     * @return true if current value is close enough to target
     */
    bool isStable(float epsilon = 0.0001f) const {
        return std::abs(current_ - target_) < epsilon && std::abs(velocity_) < epsilon;
    }

    /**
     * @brief Get current value (without advancing)
     */
    float getCurrent() const { return current_; }

    /**
     * @brief Get target value
     */
    float getTarget() const { return target_; }

private:
    float sample_rate_ = 48000.0f;
    float coeff_ = 0.0f;
    float velocity_coeff_ = 0.0f;
    float current_ = 0.0f;
    float target_ = 0.0f;
    float velocity_ = 0.0f;  // Tracks rate of change for smoother transitions
};

/**
 * @brief Convert dB to linear gain
 */
inline float db_to_gain(float db) {
    return std::pow(10.0f, db / 20.0f);
}

/**
 * @brief Convert linear gain to dB
 */
inline float gain_to_db(float gain) {
    return 20.0f * std::log10(gain);
}

} // namespace radioform

#endif // RADIOFORM_SMOOTHING_H
