/**
 * @file test_frequency_response.cpp
 * @brief Frequency response validation tests (the gold standard for EQ testing)
 */

#include "test_utils.h"
#include "radioform_dsp.h"

using namespace dsp_test;

TEST(freq_response_flat_preset_is_transparent) {
    auto* engine = radioform_dsp_create(48000);
    ASSERT(engine != nullptr);

    // Apply flat preset
    radioform_preset_t preset;
    radioform_dsp_preset_init_flat(&preset);
    radioform_dsp_apply_preset(engine, &preset);
    radioform_dsp_set_bypass(engine, false);

    // Test frequencies across spectrum
    const float test_freqs[] = {100.0f, 500.0f, 1000.0f, 5000.0f, 10000.0f};

    for (float freq : test_freqs) {
        // Generate sine at this frequency
        auto input_left = generate_sine(4800, freq, 48000.0f);
        auto input_right = input_left; // Stereo duplicate
        std::vector<float> output_left(input_left.size());
        std::vector<float> output_right(input_right.size());

        // Process
        radioform_dsp_process_planar(
            engine,
            input_left.data(), input_right.data(),
            output_left.data(), output_right.data(),
            input_left.size()
        );

        // Measure input and output levels (left channel)
        float input_rms = measure_rms(input_left);
        float output_rms = measure_rms(output_left);

        // Ratio should be close to 1.0 (flat response)
        float ratio = output_rms / input_rms;
        ASSERT_NEAR(ratio, 1.0f, 0.1f); // Within 0.8dB
    }

    radioform_dsp_destroy(engine);
    PASS();
}

TEST(freq_response_peak_filter_at_1khz) {
    auto* engine = radioform_dsp_create(48000);
    ASSERT(engine != nullptr);

    // Create preset with +6dB peak at 1kHz
    radioform_preset_t preset;
    radioform_dsp_preset_init_flat(&preset);

    preset.num_bands = 1;
    preset.bands[0].enabled = true;
    preset.bands[0].frequency_hz = 1000.0f;
    preset.bands[0].gain_db = 6.0f;
    preset.bands[0].q_factor = 2.0f;
    preset.bands[0].type = RADIOFORM_FILTER_PEAK;

    radioform_dsp_apply_preset(engine, &preset);
    radioform_dsp_set_bypass(engine, false);

    // Test at center frequency (1000 Hz) - should have boost
    auto input_1k_left = generate_sine(4800, 1000.0f, 48000.0f);
    auto input_1k_right = input_1k_left;
    std::vector<float> output_1k_left(input_1k_left.size());
    std::vector<float> output_1k_right(input_1k_right.size());

    radioform_dsp_process_planar(
        engine,
        input_1k_left.data(), input_1k_right.data(),
        output_1k_left.data(), output_1k_right.data(),
        input_1k_left.size()
    );

    float input_1k_rms = measure_rms(input_1k_left);
    float output_1k_rms = measure_rms(output_1k_left);
    float boost_1k_db = gain_to_db(output_1k_rms / input_1k_rms);

    // Should have approximately +6dB boost at center frequency
    ASSERT_NEAR(boost_1k_db, 6.0f, 1.0f);

    // Test off-center (100 Hz) - should have minimal boost
    auto input_100_left = generate_sine(4800, 100.0f, 48000.0f);
    auto input_100_right = input_100_left;
    std::vector<float> output_100_left(input_100_left.size());
    std::vector<float> output_100_right(input_100_right.size());

    // Reset for clean measurement
    radioform_dsp_reset(engine);
    radioform_dsp_apply_preset(engine, &preset);

    radioform_dsp_process_planar(
        engine,
        input_100_left.data(), input_100_right.data(),
        output_100_left.data(), output_100_right.data(),
        input_100_left.size()
    );

    float input_100_rms = measure_rms(input_100_left);
    float output_100_rms = measure_rms(output_100_left);
    float boost_100_db = gain_to_db(output_100_rms / input_100_rms);

    // Should have minimal boost far from center
    ASSERT(boost_100_db < 1.0f);

    radioform_dsp_destroy(engine);
    PASS();
}

TEST(freq_response_low_shelf_boosts_bass) {
    auto* engine = radioform_dsp_create(48000);
    ASSERT(engine != nullptr);

    // Create low shelf at 250 Hz, +6dB
    radioform_preset_t preset;
    radioform_dsp_preset_init_flat(&preset);

    preset.num_bands = 1;
    preset.bands[0].enabled = true;
    preset.bands[0].frequency_hz = 250.0f;
    preset.bands[0].gain_db = 6.0f;
    preset.bands[0].q_factor = 0.707f;
    preset.bands[0].type = RADIOFORM_FILTER_LOW_SHELF;

    radioform_dsp_apply_preset(engine, &preset);
    radioform_dsp_set_bypass(engine, false);

    // Test low frequency (100 Hz) - should be boosted
    auto input_low_left = generate_sine(4800, 100.0f, 48000.0f);
    auto input_low_right = input_low_left;
    std::vector<float> output_low_left(input_low_left.size());
    std::vector<float> output_low_right(input_low_right.size());

    radioform_dsp_process_planar(
        engine,
        input_low_left.data(), input_low_right.data(),
        output_low_left.data(), output_low_right.data(),
        input_low_left.size()
    );

    float input_low_rms = measure_rms(input_low_left);
    float output_low_rms = measure_rms(output_low_left);
    float boost_low_db = gain_to_db(output_low_rms / input_low_rms);

    // Low frequencies should be boosted
    ASSERT(boost_low_db > 3.0f); // At least +3dB

    // Test high frequency (2000 Hz) - should be unaffected
    radioform_dsp_reset(engine);
    radioform_dsp_apply_preset(engine, &preset);

    auto input_high_left = generate_sine(4800, 2000.0f, 48000.0f);
    auto input_high_right = input_high_left;
    std::vector<float> output_high_left(input_high_left.size());
    std::vector<float> output_high_right(input_high_right.size());

    radioform_dsp_process_planar(
        engine,
        input_high_left.data(), input_high_right.data(),
        output_high_left.data(), output_high_right.data(),
        input_high_left.size()
    );

    float input_high_rms = measure_rms(input_high_left);
    float output_high_rms = measure_rms(output_high_left);
    float boost_high_db = gain_to_db(output_high_rms / input_high_rms);

    // High frequencies should be relatively unaffected
    ASSERT(boost_high_db < 1.0f);

    radioform_dsp_destroy(engine);
    PASS();
}

TEST(freq_response_high_shelf_boosts_treble) {
    auto* engine = radioform_dsp_create(48000);
    ASSERT(engine != nullptr);

    // Create high shelf at 4 kHz, +6dB
    radioform_preset_t preset;
    radioform_dsp_preset_init_flat(&preset);

    preset.num_bands = 1;
    preset.bands[0].enabled = true;
    preset.bands[0].frequency_hz = 4000.0f;
    preset.bands[0].gain_db = 6.0f;
    preset.bands[0].q_factor = 0.707f;
    preset.bands[0].type = RADIOFORM_FILTER_HIGH_SHELF;

    radioform_dsp_apply_preset(engine, &preset);
    radioform_dsp_set_bypass(engine, false);

    // Test high frequency (8000 Hz) - should be boosted
    auto input_high_left = generate_sine(4800, 8000.0f, 48000.0f);
    auto input_high_right = input_high_left;
    std::vector<float> output_high_left(input_high_left.size());
    std::vector<float> output_high_right(input_high_right.size());

    radioform_dsp_process_planar(
        engine,
        input_high_left.data(), input_high_right.data(),
        output_high_left.data(), output_high_right.data(),
        input_high_left.size()
    );

    float input_high_rms = measure_rms(input_high_left);
    float output_high_rms = measure_rms(output_high_left);
    float boost_high_db = gain_to_db(output_high_rms / input_high_rms);

    // High frequencies should be boosted
    ASSERT(boost_high_db > 3.0f);

    // Test low frequency (500 Hz) - should be unaffected
    radioform_dsp_reset(engine);
    radioform_dsp_apply_preset(engine, &preset);

    auto input_low_left = generate_sine(4800, 500.0f, 48000.0f);
    auto input_low_right = input_low_left;
    std::vector<float> output_low_left(input_low_left.size());
    std::vector<float> output_low_right(input_low_right.size());

    radioform_dsp_process_planar(
        engine,
        input_low_left.data(), input_low_right.data(),
        output_low_left.data(), output_low_right.data(),
        input_low_left.size()
    );

    float input_low_rms = measure_rms(input_low_left);
    float output_low_rms = measure_rms(output_low_left);
    float boost_low_db = gain_to_db(output_low_rms / input_low_rms);

    // Low frequencies should be relatively unaffected
    ASSERT(boost_low_db < 1.0f);

    radioform_dsp_destroy(engine);
    PASS();
}

TEST(freq_response_multi_band_eq) {
    auto* engine = radioform_dsp_create(48000);
    ASSERT(engine != nullptr);

    // Create a "V-shaped" EQ (boost bass and treble, cut mids)
    radioform_preset_t preset;
    radioform_dsp_preset_init_flat(&preset);

    preset.num_bands = 3;

    // Bass boost (low shelf)
    preset.bands[0].enabled = true;
    preset.bands[0].frequency_hz = 100.0f;
    preset.bands[0].gain_db = 6.0f;
    preset.bands[0].q_factor = 0.707f;
    preset.bands[0].type = RADIOFORM_FILTER_LOW_SHELF;

    // Mid cut (peak)
    preset.bands[1].enabled = true;
    preset.bands[1].frequency_hz = 1000.0f;
    preset.bands[1].gain_db = -6.0f;
    preset.bands[1].q_factor = 1.0f;
    preset.bands[1].type = RADIOFORM_FILTER_PEAK;

    // Treble boost (high shelf)
    preset.bands[2].enabled = true;
    preset.bands[2].frequency_hz = 8000.0f;
    preset.bands[2].gain_db = 6.0f;
    preset.bands[2].q_factor = 0.707f;
    preset.bands[2].type = RADIOFORM_FILTER_HIGH_SHELF;

    radioform_dsp_apply_preset(engine, &preset);
    radioform_dsp_set_bypass(engine, false);

    // Test bass (50 Hz) - should be boosted
    auto input_bass_left = generate_sine(4800, 50.0f, 48000.0f);
    auto input_bass_right = input_bass_left;
    std::vector<float> output_bass_left(input_bass_left.size());
    std::vector<float> output_bass_right(input_bass_right.size());

    radioform_dsp_process_planar(
        engine,
        input_bass_left.data(), input_bass_right.data(),
        output_bass_left.data(), output_bass_right.data(),
        input_bass_left.size()
    );

    float bass_boost = gain_to_db(measure_rms(output_bass_left) / measure_rms(input_bass_left));
    ASSERT(bass_boost > 3.0f);

    // Test mids (1000 Hz) - should be cut
    radioform_dsp_reset(engine);
    radioform_dsp_apply_preset(engine, &preset);

    auto input_mid_left = generate_sine(4800, 1000.0f, 48000.0f);
    auto input_mid_right = input_mid_left;
    std::vector<float> output_mid_left(input_mid_left.size());
    std::vector<float> output_mid_right(input_mid_right.size());

    radioform_dsp_process_planar(
        engine,
        input_mid_left.data(), input_mid_right.data(),
        output_mid_left.data(), output_mid_right.data(),
        input_mid_left.size()
    );

    float mid_boost = gain_to_db(measure_rms(output_mid_left) / measure_rms(input_mid_left));
    ASSERT(mid_boost < -3.0f); // Should be cut

    // Test treble (10 kHz) - should be boosted
    radioform_dsp_reset(engine);
    radioform_dsp_apply_preset(engine, &preset);

    auto input_treble_left = generate_sine(4800, 10000.0f, 48000.0f);
    auto input_treble_right = input_treble_left;
    std::vector<float> output_treble_left(input_treble_left.size());
    std::vector<float> output_treble_right(input_treble_right.size());

    radioform_dsp_process_planar(
        engine,
        input_treble_left.data(), input_treble_right.data(),
        output_treble_left.data(), output_treble_right.data(),
        input_treble_left.size()
    );

    float treble_boost = gain_to_db(measure_rms(output_treble_left) / measure_rms(input_treble_left));
    ASSERT(treble_boost > 3.0f);

    radioform_dsp_destroy(engine);
    PASS();
}

TEST(freq_response_thd_remains_low) {
    auto* engine = radioform_dsp_create(48000);
    ASSERT(engine != nullptr);

    // Create preset with moderate boost
    radioform_preset_t preset;
    radioform_dsp_preset_init_flat(&preset);

    preset.num_bands = 1;
    preset.bands[0].enabled = true;
    preset.bands[0].frequency_hz = 1000.0f;
    preset.bands[0].gain_db = 6.0f;
    preset.bands[0].q_factor = 1.0f;
    preset.bands[0].type = RADIOFORM_FILTER_PEAK;

    radioform_dsp_apply_preset(engine, &preset);
    radioform_dsp_set_bypass(engine, false);

    // Generate clean sine wave at 1kHz
    auto input_left = generate_sine(48000, 1000.0f, 48000.0f); // 1 second
    auto input_right = input_left;
    std::vector<float> output_left(input_left.size());
    std::vector<float> output_right(input_right.size());

    radioform_dsp_process_planar(
        engine,
        input_left.data(), input_right.data(),
        output_left.data(), output_right.data(),
        input_left.size()
    );

    // Measure THD - should be very low for a linear EQ
    float thd = compute_thd(output_left, 1000.0f, 48000.0f, 5);

    // THD should be < 0.1% for a clean parametric EQ
    ASSERT(thd < 0.001f);

    radioform_dsp_destroy(engine);
    PASS();
}
