/**
 * @file test_smoothing.cpp
 * @brief Tests for parameter smoothing
 */

#include "test_utils.h"
#include "smoothing.h"

using namespace radioform;

TEST(smoother_initialization) {
    ParameterSmoother smoother;
    smoother.init(48000.0f, 10.0f);

    ASSERT_EQ(smoother.getCurrent(), 0.0f);
    ASSERT_EQ(smoother.getTarget(), 0.0f);

    PASS();
}

TEST(smoother_set_value_immediate) {
    ParameterSmoother smoother;
    smoother.init(48000.0f, 10.0f);

    smoother.setValue(1.0f);

    ASSERT_EQ(smoother.getCurrent(), 1.0f);
    ASSERT_EQ(smoother.getTarget(), 1.0f);

    PASS();
}

TEST(smoother_ramps_to_target) {
    ParameterSmoother smoother;
    smoother.init(48000.0f, 10.0f); // 10ms time constant

    smoother.setValue(0.0f);
    smoother.setTarget(1.0f);

    // Generate 2400 samples (~50ms at 48kHz, 5x time constant for convergence)
    std::vector<float> values;
    for (int i = 0; i < 2400; i++) {
        values.push_back(smoother.next());
    }

    // Check: should start near 0
    ASSERT_NEAR(values[0], 0.0f, 0.1f);

    // Check: should end near 1.0 (after 5 time constants = 99.3% convergence)
    ASSERT_NEAR(values[values.size() - 1], 1.0f, 0.01f);

    // Check: should be monotonically increasing
    for (size_t i = 1; i < values.size(); i++) {
        ASSERT(values[i] >= values[i-1]);
    }

    // Check: no discontinuities (zipper noise check)
    ASSERT(!dsp_test::has_discontinuities(values, 0.05f));

    PASS();
}

TEST(smoother_no_zipper_noise) {
    ParameterSmoother smoother;
    smoother.init(48000.0f, 5.0f); // Short 5ms ramp

    smoother.setValue(0.0f);
    smoother.setTarget(1.0f);

    // Generate smoothed values
    std::vector<float> values;
    for (int i = 0; i < 500; i++) {
        values.push_back(smoother.next());
    }

    // Check for discontinuities (max delta should be small)
    // At 48kHz with 5ms ramp, max step should be ~0.002
    ASSERT(!dsp_test::has_discontinuities(values, 0.01f));

    PASS();
}

TEST(db_to_gain_conversion) {
    // 0dB = 1.0
    ASSERT_NEAR(db_to_gain(0.0f), 1.0f, 0.0001f);

    // +6dB = ~2.0
    ASSERT_NEAR(db_to_gain(6.0f), 2.0f, 0.01f);

    // -6dB = ~0.5
    ASSERT_NEAR(db_to_gain(-6.0f), 0.5f, 0.01f);

    // +12dB = ~4.0
    ASSERT_NEAR(db_to_gain(12.0f), 4.0f, 0.1f);

    // -12dB = ~0.25
    ASSERT_NEAR(db_to_gain(-12.0f), 0.25f, 0.01f);

    PASS();
}
