/**
 * @file cpu_util.h
 * @brief CPU-specific utilities and optimizations
 */

#ifndef RADIOFORM_CPU_UTIL_H
#define RADIOFORM_CPU_UTIL_H

#include <cstdint>

// Include platform-specific headers at file scope
#if defined(__x86_64__) || defined(_M_X64) || defined(__i386__) || defined(_M_IX86)
    #include <xmmintrin.h>  // SSE
    #include <pmmintrin.h>  // SSE3 for DAZ
#endif

namespace radioform {

/**
 * @brief Enable denormal (subnormal) suppression for performance
 *
 * Denormal numbers (very small floats near zero) can cause 10-100x
 * performance degradation on some CPUs. This function enables hardware
 * flush-to-zero (FTZ) and denormals-are-zero (DAZ) modes.
 *
 * @note This affects the current thread only
 * @note Call this once at audio thread initialization
 */
inline void enable_denormal_suppression() {
#if defined(__x86_64__) || defined(_M_X64) || defined(__i386__) || defined(_M_IX86)
    // x86/x86_64: Use SSE control register
    // Flush-to-zero (FTZ): underflow results become zero
    _MM_SET_FLUSH_ZERO_MODE(_MM_FLUSH_ZERO_ON);

    // Denormals-are-zero (DAZ): denormal inputs treated as zero
    _MM_SET_DENORMALS_ZERO_MODE(_MM_DENORMALS_ZERO_ON);

#elif defined(__aarch64__) || defined(__arm64__) || defined(_M_ARM64)
    // ARM64/AArch64: Use FPCR register
    // FZ bit (bit 24): Flush-to-zero mode
    uint64_t fpcr;
    __asm__ __volatile__("mrs %0, fpcr" : "=r"(fpcr));
    fpcr |= (1 << 24);  // Enable FZ
    __asm__ __volatile__("msr fpcr, %0" :: "r"(fpcr));

#elif defined(__arm__) || defined(_M_ARM)
    // ARM32: Use FPSCR register
    uint32_t fpscr;
    __asm__ __volatile__("vmrs %0, fpscr" : "=r"(fpscr));
    fpscr |= (1 << 24);  // Enable FZ
    __asm__ __volatile__("vmsr fpscr, %0" :: "r"(fpscr));

#endif
    // If platform not recognized, do nothing (graceful degradation)
}

/**
 * @brief Disable denormal suppression (restore normal IEEE 754 behavior)
 */
inline void disable_denormal_suppression() {
#if defined(__x86_64__) || defined(_M_X64) || defined(__i386__) || defined(_M_IX86)
    _MM_SET_FLUSH_ZERO_MODE(_MM_FLUSH_ZERO_OFF);
    _MM_SET_DENORMALS_ZERO_MODE(_MM_DENORMALS_ZERO_OFF);

#elif defined(__aarch64__) || defined(__arm64__) || defined(_M_ARM64)
    uint64_t fpcr;
    __asm__ __volatile__("mrs %0, fpcr" : "=r"(fpcr));
    fpcr &= ~(1 << 24);  // Disable FZ
    __asm__ __volatile__("msr fpcr, %0" :: "r"(fpcr));

#elif defined(__arm__) || defined(_M_ARM)
    uint32_t fpscr;
    __asm__ __volatile__("vmrs %0, fpscr" : "=r"(fpscr));
    fpscr &= ~(1 << 24);  // Disable FZ
    __asm__ __volatile__("vmsr fpscr, %0" :: "r"(fpscr));

#endif
}

/**
 * @brief Add tiny DC offset to prevent denormals in feedback loops
 *
 * This is an alternative/complement to FTZ/DAZ - injects a tiny
 * constant to prevent filter state from collapsing to denormals.
 *
 * @param value Input value
 * @return Value with tiny offset added (< -300dB, inaudible)
 */
inline float denormal_offset(float value) {
    // 1e-20f is ~-400dB, completely inaudible but prevents denormals
    static constexpr float offset = 1.0e-20f;
    return value + offset;
}

} // namespace radioform

#endif // RADIOFORM_CPU_UTIL_H
