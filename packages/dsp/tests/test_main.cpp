/**
 * @file test_main.cpp
 * @brief Test suite entry point
 */

#include "test_utils.h"

// Declare test functions
// Preset tests
void test_preset_init_flat();
void test_preset_validate_valid();
void test_preset_validate_invalid_frequency();
void test_preset_validate_invalid_gain();
void test_preset_validate_invalid_q();

// Smoothing tests
void test_smoother_initialization();
void test_smoother_set_value_immediate();
void test_smoother_ramps_to_target();
void test_smoother_no_zipper_noise();
void test_db_to_gain_conversion();

// Biquad tests
void test_biquad_passthrough_when_flat();
void test_biquad_impulse_response_peak_filter();
void test_biquad_low_pass_attenuates_high_freq();
void test_biquad_high_pass_attenuates_low_freq();
void test_biquad_peak_filter_boosts_at_center_freq();
void test_biquad_reset_clears_state();

// Engine tests
void test_engine_create_destroy();
void test_engine_invalid_sample_rate();
void test_engine_bypass_is_bit_perfect();
void test_engine_bypass_interleaved_is_bit_perfect();
void test_engine_apply_flat_preset();
void test_engine_process_with_flat_preset();
void test_engine_peak_filter_boosts_signal();
void test_engine_limiter_prevents_clipping();
void test_engine_update_band_gain_realtime();
void test_engine_statistics_tracking();
void test_engine_reset_clears_state();

// Frequency response tests
void test_freq_response_flat_preset_is_transparent();
void test_freq_response_peak_filter_at_1khz();
void test_freq_response_low_shelf_boosts_bass();
void test_freq_response_high_shelf_boosts_treble();
void test_freq_response_multi_band_eq();
void test_freq_response_thd_remains_low();

int main(int argc, char** argv) {
    // Register all tests
    REGISTER_TEST(preset_init_flat);
    REGISTER_TEST(preset_validate_valid);
    REGISTER_TEST(preset_validate_invalid_frequency);
    REGISTER_TEST(preset_validate_invalid_gain);
    REGISTER_TEST(preset_validate_invalid_q);

    REGISTER_TEST(smoother_initialization);
    REGISTER_TEST(smoother_set_value_immediate);
    REGISTER_TEST(smoother_ramps_to_target);
    REGISTER_TEST(smoother_no_zipper_noise);
    REGISTER_TEST(db_to_gain_conversion);

    REGISTER_TEST(biquad_passthrough_when_flat);
    REGISTER_TEST(biquad_impulse_response_peak_filter);
    REGISTER_TEST(biquad_low_pass_attenuates_high_freq);
    REGISTER_TEST(biquad_high_pass_attenuates_low_freq);
    REGISTER_TEST(biquad_peak_filter_boosts_at_center_freq);
    REGISTER_TEST(biquad_reset_clears_state);

    REGISTER_TEST(engine_create_destroy);
    REGISTER_TEST(engine_invalid_sample_rate);
    REGISTER_TEST(engine_bypass_is_bit_perfect);
    REGISTER_TEST(engine_bypass_interleaved_is_bit_perfect);
    REGISTER_TEST(engine_apply_flat_preset);
    REGISTER_TEST(engine_process_with_flat_preset);
    REGISTER_TEST(engine_peak_filter_boosts_signal);
    REGISTER_TEST(engine_limiter_prevents_clipping);
    REGISTER_TEST(engine_update_band_gain_realtime);
    REGISTER_TEST(engine_statistics_tracking);
    REGISTER_TEST(engine_reset_clears_state);

    REGISTER_TEST(freq_response_flat_preset_is_transparent);
    REGISTER_TEST(freq_response_peak_filter_at_1khz);
    REGISTER_TEST(freq_response_low_shelf_boosts_bass);
    REGISTER_TEST(freq_response_high_shelf_boosts_treble);
    REGISTER_TEST(freq_response_multi_band_eq);
    REGISTER_TEST(freq_response_thd_remains_low);

    // Run all tests
    return run_all_tests();
}
