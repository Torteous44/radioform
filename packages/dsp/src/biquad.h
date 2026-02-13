/**
 * @file biquad.h
 * @brief Self-contained biquad filter using RBJ cookbook formulas
 */

#ifndef RADIOFORM_BIQUAD_H
#define RADIOFORM_BIQUAD_H

#include "radioform_types.h"
#include <cmath>
#include <cstring>

namespace radioform {

static constexpr float PI = 3.14159265358979323846f;

/**
 * @brief Biquad filter coefficients
 */
struct BiquadCoeffs {
    float b0, b1, b2;  // Numerator coefficients
    float a1, a2;      // Denominator coefficients (a0 is normalized to 1.0)
};

/**
 * @brief Biquad filter state (per channel)
 */
struct BiquadState {
    float z1 = 0.0f;  // Delay line state 1
    float z2 = 0.0f;  // Delay line state 2
};

/**
 * @brief Single biquad filter section
 */
class Biquad {
public:
    /**
     * @brief Initialize filter
     */
    void init() {
        reset();
        setCoeffsFlat();
    }

    /**
     * @brief Reset filter state (clear delay line)
     */
    void reset() {
        state_left_ = {};
        state_right_ = {};
        transition_remaining_ = 0;
    }

    /**
     * @brief Set coefficients to flat response (passthrough)
     */
    void setCoeffsFlat() {
        coeffs_.b0 = 1.0f;
        coeffs_.b1 = 0.0f;
        coeffs_.b2 = 0.0f;
        coeffs_.a1 = 0.0f;
        coeffs_.a2 = 0.0f;
        transition_remaining_ = 0;
    }

    /**
     * @brief Set coefficients from band configuration (instant, no smoothing)
     */
    void setCoeffs(const radioform_band_t& band, float sample_rate) {
        BiquadCoeffs c = calculateCoeffs(band, sample_rate);
        if (isFinite(c)) {
            coeffs_ = c;
        } else {
            setCoeffsFlat();
        }
        transition_remaining_ = 0;
    }

    /**
     * @brief Set coefficients with linear interpolation to prevent zipper noise
     *
     * Linearly interpolates from current coefficients to target over
     * transition_samples. Zero overhead once transition completes.
     *
     * @param band Band configuration
     * @param sample_rate Sample rate in Hz
     * @param transition_samples Number of samples to interpolate over (~10ms)
     */
    void setCoeffsSmooth(const radioform_band_t& band, float sample_rate, int transition_samples) {
        BiquadCoeffs c = calculateCoeffs(band, sample_rate);
        if (!isFinite(c)) {
            setCoeffsFlat();
            return;
        }
        target_coeffs_ = c;

        if (transition_samples <= 0) {
            coeffs_ = target_coeffs_;
            transition_remaining_ = 0;
            return;
        }

        const float inv_n = 1.0f / static_cast<float>(transition_samples);
        coeffs_delta_.b0 = (target_coeffs_.b0 - coeffs_.b0) * inv_n;
        coeffs_delta_.b1 = (target_coeffs_.b1 - coeffs_.b1) * inv_n;
        coeffs_delta_.b2 = (target_coeffs_.b2 - coeffs_.b2) * inv_n;
        coeffs_delta_.a1 = (target_coeffs_.a1 - coeffs_.a1) * inv_n;
        coeffs_delta_.a2 = (target_coeffs_.a2 - coeffs_.a2) * inv_n;
        transition_remaining_ = transition_samples;
    }

    /**
     * @brief Process one sample (stereo)
     */
    inline void processSample(float in_l, float in_r, float* out_l, float* out_r) {
        *out_l = processSampleMono(in_l, state_left_);
        *out_r = processSampleMono(in_r, state_right_);
    }

    /**
     * @brief Process buffer (planar stereo)
     */
    void processBuffer(
        const float* in_l, const float* in_r,
        float* out_l, float* out_r,
        uint32_t num_frames
    ) {
        for (uint32_t i = 0; i < num_frames; i++) {
            out_l[i] = processSampleMono(in_l[i], state_left_);
            out_r[i] = processSampleMono(in_r[i], state_right_);
        }
    }

    /**
     * @brief Check if all coefficients are finite (not NaN or Inf)
     */
    static bool isFinite(const BiquadCoeffs& c) {
        return std::isfinite(c.b0) && std::isfinite(c.b1) && std::isfinite(c.b2)
            && std::isfinite(c.a1) && std::isfinite(c.a2);
    }

private:
    /**
     * @brief Process one sample (mono) using Direct Form 2 Transposed
     *
     * During coefficient transitions, linearly interpolates coefficients
     * per sample to prevent zipper noise. Zero overhead when stable.
     */
    inline float processSampleMono(float input, BiquadState& state) {
        // Interpolate coefficients during transition (branch predicted not-taken when stable)
        if (transition_remaining_ > 0) {
            coeffs_.b0 += coeffs_delta_.b0;
            coeffs_.b1 += coeffs_delta_.b1;
            coeffs_.b2 += coeffs_delta_.b2;
            coeffs_.a1 += coeffs_delta_.a1;
            coeffs_.a2 += coeffs_delta_.a2;
            if (--transition_remaining_ == 0) {
                // Snap to target to prevent float drift
                coeffs_ = target_coeffs_;
            }
        }

        float output = coeffs_.b0 * input + state.z1;
        state.z1 = coeffs_.b1 * input - coeffs_.a1 * output + state.z2;
        state.z2 = coeffs_.b2 * input - coeffs_.a2 * output;

        // Protect against NaN/Inf from filter state blowup
        if (!std::isfinite(output)) {
            state.z1 = 0.0f;
            state.z2 = 0.0f;
            return input;
        }

        return output;
    }

    /**
     * @brief Calculate biquad coefficients from band parameters
     *
     * Using Robert Bristow-Johnson's cookbook formulas with audiophile enhancements:
     * - Enhanced bandwidth prewarping for peak filters (reduces cramping at high frequencies)
     * - Standard RBJ formulas for shelving filters (well-tested, reliable)
     * https://www.w3.org/TR/audio-eq-cookbook/
     */
    BiquadCoeffs calculateCoeffs(const radioform_band_t& band, float sample_rate) {
        BiquadCoeffs c;

        const float freq = band.frequency_hz;
        const float gain_db = band.gain_db;
        const float Q = band.q_factor;

        const float w0 = 2.0f * PI * freq / sample_rate;
        const float cos_w0 = std::cos(w0);
        const float sin_w0 = std::sin(w0);

        // Enhanced bandwidth prewarping for peak filters
        // This compensates for bandwidth cramping at high frequencies
        // Warp factor approaches 1.0 at low frequencies, increases at high frequencies
        const float warp_factor = (w0 < 0.01f) ? 1.0f : w0 / std::sin(w0);
        const float alpha = sin_w0 / (2.0f * Q * warp_factor);

        const float A = std::pow(10.0f, gain_db / 40.0f); // Sqrt of gain

        switch (band.type) {
            case RADIOFORM_FILTER_PEAK: {
                // Parametric peaking EQ with enhanced bandwidth prewarping
                const float a0 = 1.0f + alpha / A;
                c.b0 = (1.0f + alpha * A) / a0;
                c.b1 = (-2.0f * cos_w0) / a0;
                c.b2 = (1.0f - alpha * A) / a0;
                c.a1 = (-2.0f * cos_w0) / a0;
                c.a2 = (1.0f - alpha / A) / a0;
                break;
            }

            case RADIOFORM_FILTER_LOW_SHELF: {
                // Low shelf (RBJ cookbook - well-tested formula)
                const float beta = std::sqrt(A) / Q;
                const float a0 = (A + 1.0f) + (A - 1.0f) * cos_w0 + beta * sin_w0;

                c.b0 = (A * ((A + 1.0f) - (A - 1.0f) * cos_w0 + beta * sin_w0)) / a0;
                c.b1 = (2.0f * A * ((A - 1.0f) - (A + 1.0f) * cos_w0)) / a0;
                c.b2 = (A * ((A + 1.0f) - (A - 1.0f) * cos_w0 - beta * sin_w0)) / a0;
                c.a1 = (-2.0f * ((A - 1.0f) + (A + 1.0f) * cos_w0)) / a0;
                c.a2 = ((A + 1.0f) + (A - 1.0f) * cos_w0 - beta * sin_w0) / a0;
                break;
            }

            case RADIOFORM_FILTER_HIGH_SHELF: {
                // High shelf (RBJ cookbook - well-tested formula)
                const float beta = std::sqrt(A) / Q;
                const float a0 = (A + 1.0f) - (A - 1.0f) * cos_w0 + beta * sin_w0;

                c.b0 = (A * ((A + 1.0f) + (A - 1.0f) * cos_w0 + beta * sin_w0)) / a0;
                c.b1 = (-2.0f * A * ((A - 1.0f) + (A + 1.0f) * cos_w0)) / a0;
                c.b2 = (A * ((A + 1.0f) + (A - 1.0f) * cos_w0 - beta * sin_w0)) / a0;
                c.a1 = (2.0f * ((A - 1.0f) - (A + 1.0f) * cos_w0)) / a0;
                c.a2 = ((A + 1.0f) - (A - 1.0f) * cos_w0 - beta * sin_w0) / a0;
                break;
            }

            case RADIOFORM_FILTER_LOW_PASS: {
                // Low-pass filter
                const float a0 = 1.0f + alpha;
                c.b0 = ((1.0f - cos_w0) / 2.0f) / a0;
                c.b1 = (1.0f - cos_w0) / a0;
                c.b2 = ((1.0f - cos_w0) / 2.0f) / a0;
                c.a1 = (-2.0f * cos_w0) / a0;
                c.a2 = (1.0f - alpha) / a0;
                break;
            }

            case RADIOFORM_FILTER_HIGH_PASS: {
                // High-pass filter
                const float a0 = 1.0f + alpha;
                c.b0 = ((1.0f + cos_w0) / 2.0f) / a0;
                c.b1 = (-(1.0f + cos_w0)) / a0;
                c.b2 = ((1.0f + cos_w0) / 2.0f) / a0;
                c.a1 = (-2.0f * cos_w0) / a0;
                c.a2 = (1.0f - alpha) / a0;
                break;
            }

            case RADIOFORM_FILTER_NOTCH: {
                // Notch filter
                const float a0 = 1.0f + alpha;
                c.b0 = 1.0f / a0;
                c.b1 = (-2.0f * cos_w0) / a0;
                c.b2 = 1.0f / a0;
                c.a1 = (-2.0f * cos_w0) / a0;
                c.a2 = (1.0f - alpha) / a0;
                break;
            }

            case RADIOFORM_FILTER_BAND_PASS: {
                // Band-pass filter
                const float a0 = 1.0f + alpha;
                c.b0 = alpha / a0;
                c.b1 = 0.0f;
                c.b2 = -alpha / a0;
                c.a1 = (-2.0f * cos_w0) / a0;
                c.a2 = (1.0f - alpha) / a0;
                break;
            }

            default:
                // Fallback to flat response
                c.b0 = 1.0f;
                c.b1 = 0.0f;
                c.b2 = 0.0f;
                c.a1 = 0.0f;
                c.a2 = 0.0f;
                break;
        }

        return c;
    }

    BiquadCoeffs coeffs_;
    BiquadCoeffs target_coeffs_;
    BiquadCoeffs coeffs_delta_;
    int transition_remaining_ = 0;
    BiquadState state_left_;
    BiquadState state_right_;
};

} // namespace radioform

#endif // RADIOFORM_BIQUAD_H
