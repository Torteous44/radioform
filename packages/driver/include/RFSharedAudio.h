#ifndef RF_SHARED_AUDIO_H
#define RF_SHARED_AUDIO_H

#include <stdint.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <time.h>
#include <string.h>

#ifdef __cplusplus
extern "C" {
#endif

// Protocol version
#define RF_AUDIO_PROTOCOL_VERSION 0x00020000

// Audio format types
typedef enum {
    RF_FORMAT_FLOAT32 = 0,
    RF_FORMAT_FLOAT64 = 1,
    RF_FORMAT_INT16 = 2,
    RF_FORMAT_INT24 = 3,
    RF_FORMAT_INT32 = 4
} RFAudioFormat;

// Supported sample rates (like eqMac)
static const uint32_t RF_SUPPORTED_SAMPLE_RATES[] = {
    44100,   // CD quality
    48000,   // Standard digital audio
    88200,   // 2x CD
    96000,   // High-res
    176400,  // 4x CD
    192000   // Ultra high-res
};
#define RF_NUM_SAMPLE_RATES 6

// Channel configurations
#define RF_MAX_CHANNELS 8  // Support up to 7.1 surround

// Ring buffer capacity calculation
// We use milliseconds to be sample-rate independent
#define RF_RING_DURATION_MS_MIN 20    // Minimum 20ms
#define RF_RING_DURATION_MS_MAX 100   // Maximum 100ms
#define RF_RING_DURATION_MS_DEFAULT 40  // Default 40ms

// Calculate frames for given sample rate and duration
static inline uint32_t rf_frames_for_duration(uint32_t sample_rate, uint32_t duration_ms) {
    return (sample_rate * duration_ms) / 1000;
}

/**
 * Shared memory structure
 *
 * This version supports:
 * - Multiple sample rates (44.1 - 192 kHz)
 * - Multiple formats (float32, float64, int16, int24, int32)
 * - Variable channel counts (1-8 channels)
 * - Dynamic buffer sizing based on sample rate
 * - Format negotiation between driver and host
 */
typedef struct {
    // ===== PROTOCOL INFO =====
    uint32_t protocol_version;        // RF_AUDIO_PROTOCOL_VERSION
    uint32_t header_size;             // Size of this header (for future expansion)

    // ===== AUDIO FORMAT (negotiated) =====
    uint32_t sample_rate;             // Current sample rate (44100-192000)
    uint32_t channels;                // Current channel count (1-8)
    uint32_t format;                  // RFAudioFormat enum value
    uint32_t bytes_per_sample;        // Bytes per single sample (4 for float32, etc.)
    uint32_t bytes_per_frame;         // bytes_per_sample * channels

    // ===== RING BUFFER CONFIG =====
    uint32_t ring_capacity_frames;    // Total frames in ring buffer
    uint32_t ring_duration_ms;        // Duration in milliseconds

    // ===== CAPABILITY FLAGS =====
    uint32_t driver_capabilities;     // Bit flags for driver features
    uint32_t host_capabilities;       // Bit flags for host features

    // ===== TIMING & SYNC =====
    uint64_t creation_timestamp;      // Unix timestamp
    _Atomic uint64_t format_change_counter;  // Increments on format change

    // ===== ATOMIC INDICES =====
    _Atomic uint64_t write_index;     // Producer write position (frames)
    _Atomic uint64_t read_index;      // Consumer read position (frames)

    // ===== STATISTICS =====
    _Atomic uint64_t total_frames_written;
    _Atomic uint64_t total_frames_read;
    _Atomic uint64_t overrun_count;
    _Atomic uint64_t underrun_count;
    _Atomic uint64_t format_mismatch_count;  // Format negotiation failures

    // ===== STATUS FLAGS =====
    _Atomic uint32_t driver_connected;   // 1 if driver is connected
    _Atomic uint32_t host_connected;     // 1 if host is connected
    _Atomic uint64_t driver_heartbeat;   // Increments every second
    _Atomic uint64_t host_heartbeat;     // Increments every second

    // Padding to 256 bytes for future expansion
    uint8_t _reserved[256 - 136];

    // ===== RING BUFFER DATA =====
    // Interleaved audio data in the negotiated format
    // Size is: ring_capacity_frames * channels * bytes_per_sample
    // This MUST be the last field (flexible array member)
    uint8_t audio_data[];

} RFSharedAudio;

// Capability flags
#define RF_CAP_MULTI_SAMPLE_RATE    (1 << 0)  // Supports multiple sample rates
#define RF_CAP_MULTI_FORMAT         (1 << 1)  // Supports multiple formats
#define RF_CAP_MULTI_CHANNEL        (1 << 2)  // Supports multiple channel counts
#define RF_CAP_SAMPLE_RATE_CONVERT  (1 << 3)  // Has sample rate converter
#define RF_CAP_FORMAT_CONVERT       (1 << 4)  // Has format converter
#define RF_CAP_AUTO_RECONNECT       (1 << 5)  // Supports auto-reconnect
#define RF_CAP_HEARTBEAT_MONITOR    (1 << 6)  // Monitors connection health

/**
 * Calculate total size needed for shared memory
 */
static inline size_t rf_shared_audio_size(uint32_t capacity_frames,
                                              uint32_t channels,
                                              uint32_t bytes_per_sample) {
    return sizeof(RFSharedAudio) + (capacity_frames * channels * bytes_per_sample);
}

/**
 * Initialize shared memory with format specification
 */
static inline void rf_shared_audio_init(
    RFSharedAudio* mem,
    uint32_t sample_rate,
    uint32_t channels,
    RFAudioFormat format,
    uint32_t duration_ms)
{
    memset(mem, 0, sizeof(RFSharedAudio));

    mem->protocol_version = RF_AUDIO_PROTOCOL_VERSION;
    mem->header_size = sizeof(RFSharedAudio);

    // Audio format
    mem->sample_rate = sample_rate;
    mem->channels = channels;
    mem->format = format;

    // Calculate bytes per sample based on format
    switch (format) {
        case RF_FORMAT_FLOAT32: mem->bytes_per_sample = 4; break;
        case RF_FORMAT_FLOAT64: mem->bytes_per_sample = 8; break;
        case RF_FORMAT_INT16:   mem->bytes_per_sample = 2; break;
        case RF_FORMAT_INT24:   mem->bytes_per_sample = 3; break;
        case RF_FORMAT_INT32:   mem->bytes_per_sample = 4; break;
        default:                mem->bytes_per_sample = 4; break;
    }

    mem->bytes_per_frame = mem->bytes_per_sample * channels;

    // Ring buffer sizing
    mem->ring_capacity_frames = rf_frames_for_duration(sample_rate, duration_ms);
    mem->ring_duration_ms = duration_ms;

    // Capabilities - driver advertises what it supports
    mem->driver_capabilities =
        RF_CAP_MULTI_SAMPLE_RATE |
        RF_CAP_MULTI_FORMAT |
        RF_CAP_MULTI_CHANNEL |
        RF_CAP_FORMAT_CONVERT |
        RF_CAP_AUTO_RECONNECT |
        RF_CAP_HEARTBEAT_MONITOR;

    mem->creation_timestamp = (uint64_t)time(NULL);

    // Initialize atomics
    atomic_store(&mem->format_change_counter, 0);
    atomic_store(&mem->write_index, 0);
    atomic_store(&mem->read_index, 0);
    atomic_store(&mem->total_frames_written, 0);
    atomic_store(&mem->total_frames_read, 0);
    atomic_store(&mem->overrun_count, 0);
    atomic_store(&mem->underrun_count, 0);
    atomic_store(&mem->format_mismatch_count, 0);
    atomic_store(&mem->driver_connected, 0);
    atomic_store(&mem->host_connected, 1);  // Host creates the memory
    atomic_store(&mem->driver_heartbeat, 0);
    atomic_store(&mem->host_heartbeat, 0);
}

/**
 * Check if sample rate is supported
 */
static inline bool rf_is_sample_rate_supported(uint32_t sample_rate) {
    for (int i = 0; i < RF_NUM_SAMPLE_RATES; i++) {
        if (RF_SUPPORTED_SAMPLE_RATES[i] == sample_rate) {
            return true;
        }
    }
    return false;
}

/**
 * Get bytes per sample for a format
 */
static inline uint32_t rf_bytes_per_sample(RFAudioFormat format) {
    switch (format) {
        case RF_FORMAT_FLOAT32: return 4;
        case RF_FORMAT_FLOAT64: return 8;
        case RF_FORMAT_INT16:   return 2;
        case RF_FORMAT_INT24:   return 3;
        case RF_FORMAT_INT32:   return 4;
        default:                return 4;
    }
}

/**
 * Check if both sides are connected and healthy
 */
static inline bool rf_is_connection_healthy(const RFSharedAudio* mem) {
    uint32_t driver_conn = atomic_load(&mem->driver_connected);
    uint32_t host_conn = atomic_load(&mem->host_connected);

    if (driver_conn == 0 || host_conn == 0) {
        return false;
    }

    // Check heartbeats (should be incrementing)
    uint64_t driver_hb = atomic_load(&mem->driver_heartbeat);
    uint64_t host_hb = atomic_load(&mem->host_heartbeat);

    // Both should be non-zero if connection is established
    return (driver_hb > 0 && host_hb > 0);
}

/**
 * Write frames to ring buffer with automatic format conversion
 *
 * This version accepts float32 input and converts to the ring buffer's format
 */
static inline uint32_t rf_ring_write(
    RFSharedAudio* mem,
    const float* input_frames,  // Always float32 input
    uint32_t num_frames)
{
    uint64_t write_idx = atomic_load(&mem->write_index);
    uint64_t read_idx = atomic_load(&mem->read_index);
    uint32_t capacity = mem->ring_capacity_frames;

    // Check for overflow - advance read_index to keep producer timeline intact
    uint64_t used = write_idx - read_idx;
    if (used + num_frames > capacity) {
        uint32_t frames_to_drop = (uint32_t)((used + num_frames) - capacity);
        atomic_store(&mem->read_index, read_idx + frames_to_drop);
        atomic_fetch_add(&mem->overrun_count, 1);
    }

    // Write with format conversion
    for (uint32_t frame = 0; frame < num_frames; frame++) {
        uint32_t ring_pos = (uint32_t)((write_idx + frame) % capacity);
        uint8_t* dest = &mem->audio_data[ring_pos * mem->bytes_per_frame];

        for (uint32_t ch = 0; ch < mem->channels; ch++) {
            float sample = input_frames[frame * mem->channels + ch];

            switch (mem->format) {
                case RF_FORMAT_FLOAT32: {
                    float* ptr = (float*)dest;
                    ptr[ch] = sample;
                    break;
                }
                case RF_FORMAT_FLOAT64: {
                    double* ptr = (double*)dest;
                    ptr[ch] = (double)sample;
                    break;
                }
                case RF_FORMAT_INT16: {
                    int16_t* ptr = (int16_t*)dest;
                    // Clamp to [-1.0, 1.0] and scale to int16 range
                    if (sample > 1.0f) sample = 1.0f;
                    if (sample < -1.0f) sample = -1.0f;
                    ptr[ch] = (int16_t)(sample * 32767.0f);
                    break;
                }
                case RF_FORMAT_INT32: {
                    int32_t* ptr = (int32_t*)dest;
                    if (sample > 1.0f) sample = 1.0f;
                    if (sample < -1.0f) sample = -1.0f;
                    ptr[ch] = (int32_t)(sample * 2147483647.0f);
                    break;
                }
                case RF_FORMAT_INT24: {
                    // 24-bit packed (3 bytes)
                    if (sample > 1.0f) sample = 1.0f;
                    if (sample < -1.0f) sample = -1.0f;
                    int32_t val24 = (int32_t)(sample * 8388607.0f);
                    uint8_t* ptr = dest + (ch * 3);
                    ptr[0] = (val24 >> 0) & 0xFF;
                    ptr[1] = (val24 >> 8) & 0xFF;
                    ptr[2] = (val24 >> 16) & 0xFF;
                    break;
                }
            }
        }
    }

    atomic_store(&mem->write_index, write_idx + num_frames);
    atomic_fetch_add(&mem->total_frames_written, num_frames);

    return num_frames;
}

/**
 * Read frames from ring buffer with automatic format conversion
 *
 * This version outputs float32 regardless of ring buffer format
 */
static inline uint32_t rf_ring_read(
    RFSharedAudio* mem,
    float* output_frames,  // Always float32 output
    uint32_t num_frames)
{
    uint64_t write_idx = atomic_load(&mem->write_index);
    uint64_t read_idx = atomic_load(&mem->read_index);
    uint32_t capacity = mem->ring_capacity_frames;
    uint32_t available = (uint32_t)(write_idx - read_idx);

    uint32_t frames_to_read = (available < num_frames) ? available : num_frames;

    // Read with format conversion
    for (uint32_t frame = 0; frame < frames_to_read; frame++) {
        uint32_t ring_pos = (uint32_t)((read_idx + frame) % capacity);
        const uint8_t* src = &mem->audio_data[ring_pos * mem->bytes_per_frame];

        for (uint32_t ch = 0; ch < mem->channels; ch++) {
            float sample = 0.0f;

            switch (mem->format) {
                case RF_FORMAT_FLOAT32: {
                    const float* ptr = (const float*)src;
                    sample = ptr[ch];
                    break;
                }
                case RF_FORMAT_FLOAT64: {
                    const double* ptr = (const double*)src;
                    sample = (float)ptr[ch];
                    break;
                }
                case RF_FORMAT_INT16: {
                    const int16_t* ptr = (const int16_t*)src;
                    sample = (float)ptr[ch] / 32768.0f;
                    break;
                }
                case RF_FORMAT_INT32: {
                    const int32_t* ptr = (const int32_t*)src;
                    sample = (float)ptr[ch] / 2147483648.0f;
                    break;
                }
                case RF_FORMAT_INT24: {
                    const uint8_t* ptr = src + (ch * 3);
                    int32_t val24 = (int32_t)((ptr[0] << 0) | (ptr[1] << 8) | (ptr[2] << 16));
                    // Sign extend from 24 to 32 bits
                    if (val24 & 0x800000) {
                        val24 |= 0xFF000000;
                    }
                    sample = (float)val24 / 8388608.0f;
                    break;
                }
            }

            output_frames[frame * mem->channels + ch] = sample;
        }
    }

    // Fill remaining with silence if underrun
    if (frames_to_read < num_frames) {
        atomic_fetch_add(&mem->underrun_count, 1);
        for (uint32_t frame = frames_to_read; frame < num_frames; frame++) {
            for (uint32_t ch = 0; ch < mem->channels; ch++) {
                output_frames[frame * mem->channels + ch] = 0.0f;
            }
        }
    }

    atomic_store(&mem->read_index, read_idx + frames_to_read);
    atomic_fetch_add(&mem->total_frames_read, frames_to_read);

    return num_frames;
}

/**
 * Update heartbeat (call every ~1 second)
 */
static inline void rf_update_driver_heartbeat(RFSharedAudio* mem) {
    atomic_fetch_add(&mem->driver_heartbeat, 1);
    atomic_store(&mem->driver_connected, 1);
}

static inline void rf_update_host_heartbeat(RFSharedAudio* mem) {
    atomic_fetch_add(&mem->host_heartbeat, 1);
    atomic_store(&mem->host_connected, 1);
}

/**
 * Check if format change is needed
 * Returns true if current format doesn't match requested format
 */
static inline bool rf_needs_format_change(
    const RFSharedAudio* mem,
    uint32_t new_sample_rate,
    uint32_t new_channels,
    RFAudioFormat new_format)
{
    return (mem->sample_rate != new_sample_rate ||
            mem->channels != new_channels ||
            mem->format != new_format);
}

#ifdef __cplusplus
}
#endif

#endif // RF_SHARED_AUDIO_H
