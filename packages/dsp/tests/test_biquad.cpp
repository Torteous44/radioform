/**
 * @file test_biquad.cpp
 * @brief Tests for biquad filter implementation
 */

#include "test_utils.h"
#include "biquad.h"

using namespace radioform;
using namespace dsp_test;

TEST(biquad_passthrough_when_flat) {
    Biquad bq;
    bq.init();
    bq.setCoeffsFlat();

    // Generate test signal
    auto input = generate_sine(1000, 1000.0f, 48000.0f);
    std::vector<float> output_left(input.size());
    std::vector<float> output_right(input.size());

    // Process
    bq.processBuffer(
        input.data(), input.data(),
        output_left.data(), output_right.data(),
        input.size()
    );

    // Output should equal input (bit-perfect passthrough)
    ASSERT(signals_identical(input, output_left));
    ASSERT(signals_identical(input, output_right));

    PASS();
}

TEST(biquad_impulse_response_peak_filter) {
    Biquad bq;
    bq.init();

    // Create peak filter at 1kHz, +6dB, Q=1.0
    radioform_band_t band;
    band.frequency_hz = 1000.0f;
    band.gain_db = 6.0f;
    band.q_factor = 1.0f;
    band.type = RADIOFORM_FILTER_PEAK;
    band.enabled = true;

    bq.setCoeffs(band, 48000.0f);

    // Generate impulse
    auto impulse = generate_impulse(256);
    std::vector<float> output_left(impulse.size());
    std::vector<float> output_right(impulse.size());

    // Process
    bq.processBuffer(
        impulse.data(), impulse.data(),
        output_left.data(), output_right.data(),
        impulse.size()
    );

    // Impulse response should not be silent
    ASSERT(!is_silent(output_left));

    // Impulse response should decay to near zero
    ASSERT_NEAR(output_left[output_left.size() - 1], 0.0f, 0.001f);

    PASS();
}

TEST(biquad_low_pass_attenuates_high_freq) {
    Biquad bq;
    bq.init();

    // Create low-pass filter at 1kHz
    radioform_band_t band;
    band.frequency_hz = 1000.0f;
    band.gain_db = 0.0f;
    band.q_factor = 0.707f; // Butterworth
    band.type = RADIOFORM_FILTER_LOW_PASS;
    band.enabled = true;

    bq.setCoeffs(band, 48000.0f);

    // Test with low frequency (500 Hz - should pass)
    auto low_freq = generate_sine(4800, 500.0f, 48000.0f);
    std::vector<float> low_output_l(low_freq.size());
    std::vector<float> low_output_r(low_freq.size());

    bq.processBuffer(
        low_freq.data(), low_freq.data(),
        low_output_l.data(), low_output_r.data(),
        low_freq.size()
    );

    float low_rms = measure_rms(low_output_l);

    // Reset filter for high frequency test
    bq.reset();
    bq.setCoeffs(band, 48000.0f);

    // Test with high frequency (5000 Hz - should be attenuated)
    auto high_freq = generate_sine(4800, 5000.0f, 48000.0f);
    std::vector<float> high_output_l(high_freq.size());
    std::vector<float> high_output_r(high_freq.size());

    bq.processBuffer(
        high_freq.data(), high_freq.data(),
        high_output_l.data(), high_output_r.data(),
        high_freq.size()
    );

    float high_rms = measure_rms(high_output_l);

    // High frequency should be significantly attenuated
    ASSERT(high_rms < low_rms * 0.5f); // At least -6dB attenuation

    PASS();
}

TEST(biquad_high_pass_attenuates_low_freq) {
    Biquad bq;
    bq.init();

    // Create high-pass filter at 1kHz
    radioform_band_t band;
    band.frequency_hz = 1000.0f;
    band.gain_db = 0.0f;
    band.q_factor = 0.707f;
    band.type = RADIOFORM_FILTER_HIGH_PASS;
    band.enabled = true;

    bq.setCoeffs(band, 48000.0f);

    // Test with low frequency (500 Hz - should be attenuated)
    auto low_freq = generate_sine(4800, 500.0f, 48000.0f);
    std::vector<float> low_output_l(low_freq.size());
    std::vector<float> low_output_r(low_freq.size());

    bq.processBuffer(
        low_freq.data(), low_freq.data(),
        low_output_l.data(), low_output_r.data(),
        low_freq.size()
    );

    float low_rms = measure_rms(low_output_l);

    // Reset filter
    bq.reset();
    bq.setCoeffs(band, 48000.0f);

    // Test with high frequency (5000 Hz - should pass)
    auto high_freq = generate_sine(4800, 5000.0f, 48000.0f);
    std::vector<float> high_output_l(high_freq.size());
    std::vector<float> high_output_r(high_freq.size());

    bq.processBuffer(
        high_freq.data(), high_freq.data(),
        high_output_l.data(), high_output_r.data(),
        high_freq.size()
    );

    float high_rms = measure_rms(high_output_l);

    // Low frequency should be significantly attenuated
    ASSERT(low_rms < high_rms * 0.5f);

    PASS();
}

TEST(biquad_peak_filter_boosts_at_center_freq) {
    Biquad bq;
    bq.init();

    // Create peak filter at 1kHz, +6dB
    radioform_band_t band;
    band.frequency_hz = 1000.0f;
    band.gain_db = 6.0f;
    band.q_factor = 2.0f; // Narrow peak
    band.type = RADIOFORM_FILTER_PEAK;
    band.enabled = true;

    bq.setCoeffs(band, 48000.0f);

    // Test at center frequency (1000 Hz)
    auto center_freq = generate_sine(4800, 1000.0f, 48000.0f);
    std::vector<float> center_output_l(center_freq.size());
    std::vector<float> center_output_r(center_freq.size());

    bq.processBuffer(
        center_freq.data(), center_freq.data(),
        center_output_l.data(), center_output_r.data(),
        center_freq.size()
    );

    float center_rms = measure_rms(center_output_l);

    // Reset filter
    bq.reset();
    bq.setCoeffs(band, 48000.0f);

    // Test off center (500 Hz - should have less boost)
    auto off_center = generate_sine(4800, 500.0f, 48000.0f);
    std::vector<float> off_output_l(off_center.size());
    std::vector<float> off_output_r(off_center.size());

    bq.processBuffer(
        off_center.data(), off_center.data(),
        off_output_l.data(), off_output_r.data(),
        off_center.size()
    );

    float off_rms = measure_rms(off_output_l);

    // Center frequency should be boosted more
    ASSERT(center_rms > off_rms * 1.3f); // At least +2.3dB more

    PASS();
}

TEST(biquad_reset_clears_state) {
    Biquad bq;
    bq.init();

    radioform_band_t band;
    band.frequency_hz = 1000.0f;
    band.gain_db = 6.0f;
    band.q_factor = 1.0f;
    band.type = RADIOFORM_FILTER_PEAK;
    band.enabled = true;

    bq.setCoeffs(band, 48000.0f);

    // Process some audio to build up state
    auto signal = generate_sine(1000, 1000.0f, 48000.0f);
    std::vector<float> output_l(signal.size());
    std::vector<float> output_r(signal.size());

    bq.processBuffer(
        signal.data(), signal.data(),
        output_l.data(), output_r.data(),
        signal.size()
    );

    // Reset
    bq.reset();

    // Process impulse - if reset worked, output should be predictable
    auto impulse = generate_impulse(256);
    std::vector<float> impulse_out_l(impulse.size());
    std::vector<float> impulse_out_r(impulse.size());

    bq.processBuffer(
        impulse.data(), impulse.data(),
        impulse_out_l.data(), impulse_out_r.data(),
        impulse.size()
    );

    // After reset, impulse response should be clean
    ASSERT(!is_silent(impulse_out_l));

    PASS();
}
