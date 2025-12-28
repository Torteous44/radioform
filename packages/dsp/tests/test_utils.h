/**
 * @file test_utils.h
 * @brief Testing utilities and mini test framework
 */

#ifndef TEST_UTILS_H
#define TEST_UTILS_H

#include <iostream>
#include <cmath>
#include <string>
#include <vector>
#include <functional>

// ============================================================================
// Simple Test Framework
// ============================================================================

struct TestStats {
    int passed = 0;
    int failed = 0;
};

static TestStats g_test_stats;

// Test registry - using explicit function to avoid static init issues
static std::vector<std::pair<std::string, std::function<void()>>>& get_test_registry() {
    static std::vector<std::pair<std::string, std::function<void()>>> registry;
    return registry;
}

#define TEST(name) \
    void test_##name(); \
    void test_##name()

#define REGISTER_TEST(name) \
    get_test_registry().push_back({#name, test_##name})

#define ASSERT(condition) \
    do { \
        if (!(condition)) { \
            std::cerr << "❌ FAIL: " << __FILE__ << ":" << __LINE__ << ": " \
                      << #condition << std::endl; \
            g_test_stats.failed++; \
            return; \
        } \
    } while(0)

#define ASSERT_NEAR(a, b, epsilon) \
    do { \
        double _a = (a); \
        double _b = (b); \
        double _epsilon = (epsilon); \
        if (std::abs(_a - _b) > _epsilon) { \
            std::cerr << "❌ FAIL: " << __FILE__ << ":" << __LINE__ << ": " \
                      << #a << " (" << _a << ") not near " \
                      << #b << " (" << _b << ") " \
                      << "within " << _epsilon << " (diff: " << std::abs(_a - _b) << ")" \
                      << std::endl; \
            g_test_stats.failed++; \
            return; \
        } \
    } while(0)

#define ASSERT_EQ(a, b) \
    do { \
        auto _a = (a); \
        auto _b = (b); \
        if (_a != _b) { \
            std::cerr << "❌ FAIL: " << __FILE__ << ":" << __LINE__ << ": " \
                      << #a << " (" << _a << ") != " << #b << " (" << _b << ")" \
                      << std::endl; \
            g_test_stats.failed++; \
            return; \
        } \
    } while(0)

#define PASS() g_test_stats.passed++

static int run_all_tests() {
    std::cout << "\n========================================\n";
    std::cout << "Running Radioform DSP Test Suite\n";
    std::cout << "========================================\n\n";

    auto& tests = get_test_registry();
    std::cout << "Found " << tests.size() << " tests\n\n";

    for (const auto& [name, func] : tests) {
        std::cout << "Running: " << name << "..." << std::flush;
        int failed_before = g_test_stats.failed;

        func();

        if (g_test_stats.failed == failed_before) {
            std::cout << " ✓" << std::endl;
        } else {
            std::cout << " ✗" << std::endl;
        }
    }

    std::cout << "\n========================================\n";
    std::cout << "Results: " << g_test_stats.passed << " passed, "
              << g_test_stats.failed << " failed\n";
    std::cout << "========================================\n\n";

    return (g_test_stats.failed == 0) ? 0 : 1;
}

// ============================================================================
// DSP Testing Utilities
// ============================================================================

namespace dsp_test {

/** Generate impulse signal (1.0 at t=0, 0.0 elsewhere) */
inline std::vector<float> generate_impulse(size_t length) {
    std::vector<float> impulse(length, 0.0f);
    if (length > 0) {
        impulse[0] = 1.0f;
    }
    return impulse;
}

/** Generate sine wave at specified frequency */
inline std::vector<float> generate_sine(size_t length, float frequency, float sample_rate) {
    std::vector<float> sine(length);
    const float omega = 2.0f * M_PI * frequency / sample_rate;
    for (size_t i = 0; i < length; i++) {
        sine[i] = std::sin(omega * i);
    }
    return sine;
}

/** Generate white noise */
inline std::vector<float> generate_white_noise(size_t length, float amplitude = 1.0f) {
    std::vector<float> noise(length);
    for (size_t i = 0; i < length; i++) {
        noise[i] = amplitude * (2.0f * (float)rand() / RAND_MAX - 1.0f);
    }
    return noise;
}

/** Measure RMS level of signal */
inline float measure_rms(const std::vector<float>& signal) {
    if (signal.empty()) return 0.0f;

    float sum = 0.0f;
    for (float sample : signal) {
        sum += sample * sample;
    }
    return std::sqrt(sum / signal.size());
}

/** Measure peak level of signal */
inline float measure_peak(const std::vector<float>& signal) {
    float peak = 0.0f;
    for (float sample : signal) {
        peak = std::max(peak, std::abs(sample));
    }
    return peak;
}

/** Compute simple FFT magnitude at specific frequency (DFT bin) */
inline float measure_magnitude_at_frequency(
    const std::vector<float>& signal,
    float frequency,
    float sample_rate
) {
    if (signal.empty()) return 0.0f;

    // Simple DFT for single frequency
    const float omega = 2.0f * M_PI * frequency / sample_rate;
    float real = 0.0f;
    float imag = 0.0f;

    for (size_t i = 0; i < signal.size(); i++) {
        real += signal[i] * std::cos(omega * i);
        imag += signal[i] * std::sin(omega * i);
    }

    real /= signal.size();
    imag /= signal.size();

    return std::sqrt(real * real + imag * imag);
}

/** Compute THD (Total Harmonic Distortion) */
inline float compute_thd(
    const std::vector<float>& signal,
    float fundamental_freq,
    float sample_rate,
    int num_harmonics = 5
) {
    // Measure fundamental
    float fundamental = measure_magnitude_at_frequency(signal, fundamental_freq, sample_rate);

    // Measure harmonics
    float harmonic_sum = 0.0f;
    for (int h = 2; h <= num_harmonics + 1; h++) {
        float harmonic = measure_magnitude_at_frequency(signal, fundamental_freq * h, sample_rate);
        harmonic_sum += harmonic * harmonic;
    }

    return std::sqrt(harmonic_sum) / fundamental;
}

/** Check if signal is silent (all zeros within epsilon) */
inline bool is_silent(const std::vector<float>& signal, float epsilon = 1e-6f) {
    for (float sample : signal) {
        if (std::abs(sample) > epsilon) {
            return false;
        }
    }
    return true;
}

/** Check if two signals are identical (bit-perfect) */
inline bool signals_identical(const std::vector<float>& a, const std::vector<float>& b) {
    if (a.size() != b.size()) return false;

    for (size_t i = 0; i < a.size(); i++) {
        if (a[i] != b[i]) { // Exact comparison (bit-perfect)
            return false;
        }
    }
    return true;
}

/** Check if signal has discontinuities (zipper noise) */
inline bool has_discontinuities(const std::vector<float>& signal, float max_delta = 0.1f) {
    for (size_t i = 1; i < signal.size(); i++) {
        if (std::abs(signal[i] - signal[i-1]) > max_delta) {
            return true;
        }
    }
    return false;
}

/** Convert dB to linear gain */
inline float db_to_gain(float db) {
    return std::pow(10.0f, db / 20.0f);
}

/** Convert linear gain to dB */
inline float gain_to_db(float gain) {
    return 20.0f * std::log10(gain);
}

} // namespace dsp_test

#endif // TEST_UTILS_H
