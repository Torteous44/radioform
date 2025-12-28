#ifndef RF_SHARED_AUDIO_H
#define RF_SHARED_AUDIO_H

#include <stdint.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <time.h>

#ifdef __cplusplus
extern "C" {
#endif

// Protocol version
#define RF_AUDIO_PROTOCOL_VERSION 0x00010000

// Audio format (FIXED - never change in v1)
#define RF_SAMPLE_RATE 48000
#define RF_CHANNELS 2
#define RF_BYTES_PER_FRAME 8  // float32 * 2 channels

// Ring buffer capacity (frames)
#define RF_RING_MIN_FRAMES 960   // 20ms at 48kHz
#define RF_RING_MAX_FRAMES 1920  // 40ms at 48kHz
#define RF_RING_DEFAULT_FRAMES 1440  // 30ms at 48kHz

/**
 * Shared memory structure for realtime audio transport.
 *
 * Layout is cache-line aligned (64 bytes) to prevent false sharing.
 * Ring buffer uses atomic indices that never wrap; indices are reduced modulo
 * capacity when accessing the backing array.
 *
 * INVARIANT: (write_index - read_index) <= ring_capacity_frames MUST ALWAYS HOLD
 *
 * If violated:
 *   - Producer: drop oldest frames (advance read_index)
 *   - Consumer: resync to write_index, output silence
 */
typedef struct {
    // ===== HEADER (cache-line aligned) =====
    uint32_t protocol_version;        // RF_AUDIO_PROTOCOL_VERSION
    uint32_t sample_rate;             // RF_SAMPLE_RATE (48000)
    uint32_t channels;                // RF_CHANNELS (2)
    uint32_t bytes_per_frame;         // RF_BYTES_PER_FRAME (8)
    uint32_t ring_capacity_frames;    // Actual ring size (960-1920)
    uint64_t creation_timestamp;      // Unix timestamp when shm was created

    // ===== ATOMIC INDICES =====
    // These never wrap - reduce with modulo capacity when indexing
    _Atomic uint64_t write_index;     // Producer (HAL) write position
    _Atomic uint64_t read_index;      // Consumer (Host) read position

    // ===== STATISTICS =====
    _Atomic uint64_t total_frames_written;   // Monotonic counter for drift detection
    _Atomic uint64_t overrun_count;          // Producer had to drop frames
    _Atomic uint64_t underrun_count;         // Consumer had no data

    // Padding to cache line (64 bytes total so far)
    uint8_t _padding[64 - 48];

    // ===== RING BUFFER DATA =====
    // Interleaved stereo float32 (LRLRLR...)
    // Actual size is ring_capacity_frames * 2 floats
    // This is a flexible array member - must be last
    float audio_data[];

} RFSharedAudioV1;

/**
 * Calculate total size needed for shared memory allocation.
 */
static inline size_t rf_shared_audio_size(uint32_t capacity_frames) {
    return sizeof(RFSharedAudioV1) + (capacity_frames * 2 * sizeof(float));
}

/**
 * Get creation timestamp (for debugging).
 */
static inline uint64_t rf_get_creation_timestamp(const RFSharedAudioV1* mem) {
    return mem->creation_timestamp;
}

/**
 * Initialize shared memory header.
 * Call this on the host side after allocating shared memory.
 */
static inline void rf_shared_audio_init(RFSharedAudioV1* mem, uint32_t capacity_frames) {
    mem->protocol_version = RF_AUDIO_PROTOCOL_VERSION;
    mem->sample_rate = RF_SAMPLE_RATE;
    mem->channels = RF_CHANNELS;
    mem->bytes_per_frame = RF_BYTES_PER_FRAME;
    mem->ring_capacity_frames = capacity_frames;
    mem->creation_timestamp = (uint64_t)time(NULL);  // Current unix timestamp

    atomic_store(&mem->write_index, 0);
    atomic_store(&mem->read_index, 0);
    atomic_store(&mem->total_frames_written, 0);
    atomic_store(&mem->overrun_count, 0);
    atomic_store(&mem->underrun_count, 0);
}

/**
 * Get available frames for writing (producer/HAL side).
 * Returns number of frames that can be written without overrun.
 */
static inline uint32_t rf_ring_available_write(const RFSharedAudioV1* mem) {
    uint64_t write_idx = atomic_load(&mem->write_index);
    uint64_t read_idx = atomic_load(&mem->read_index);
    uint64_t used = write_idx - read_idx;

    if (used >= mem->ring_capacity_frames) {
        return 0;  // Ring is full
    }
    return mem->ring_capacity_frames - (uint32_t)used;
}

/**
 * Get available frames for reading (consumer/host side).
 * Returns number of frames available to read.
 */
static inline uint32_t rf_ring_available_read(const RFSharedAudioV1* mem) {
    uint64_t write_idx = atomic_load(&mem->write_index);
    uint64_t read_idx = atomic_load(&mem->read_index);
    return (uint32_t)(write_idx - read_idx);
}

/**
 * Helpers for reading atomic indices from Swift/ObjC (where _Atomic fields
 * are not directly importable).
 */
static inline uint64_t rf_ring_get_write_index(const RFSharedAudioV1* mem) {
    return atomic_load(&mem->write_index);
}

static inline uint64_t rf_ring_get_read_index(const RFSharedAudioV1* mem) {
    return atomic_load(&mem->read_index);
}

/**
 * Write frames to ring buffer (producer/HAL side).
 * Returns number of frames actually written.
 * If buffer is full, drops OLDEST frames to make space.
 */
static inline uint32_t rf_ring_write(RFSharedAudioV1* mem, const float* frames, uint32_t num_frames) {
    uint64_t write_idx = atomic_load(&mem->write_index);
    uint64_t read_idx = atomic_load(&mem->read_index);
    uint32_t capacity = mem->ring_capacity_frames;

    // Check if we would overflow
    uint64_t used = write_idx - read_idx;
    if (used + num_frames > capacity) {
        // Drop oldest frames by advancing read pointer
        uint32_t frames_to_drop = (uint32_t)((used + num_frames) - capacity);
        atomic_store(&mem->read_index, read_idx + frames_to_drop);
        atomic_fetch_add(&mem->overrun_count, 1);
    }

    // Write frames (interleaved stereo)
    for (uint32_t i = 0; i < num_frames; i++) {
        uint32_t pos = (uint32_t)((write_idx + i) % capacity);
        mem->audio_data[pos * 2 + 0] = frames[i * 2 + 0];  // Left
        mem->audio_data[pos * 2 + 1] = frames[i * 2 + 1];  // Right
    }

    // Advance write pointer
    atomic_store(&mem->write_index, write_idx + num_frames);
    atomic_fetch_add(&mem->total_frames_written, num_frames);

    return num_frames;
}

/**
 * Read frames from ring buffer (consumer/host side).
 * Returns number of frames actually read.
 * If buffer is empty, outputs silence and returns requested count.
 */
static inline uint32_t rf_ring_read(RFSharedAudioV1* mem, float* frames, uint32_t num_frames) {
    uint64_t write_idx = atomic_load(&mem->write_index);
    uint64_t read_idx = atomic_load(&mem->read_index);
    uint32_t capacity = mem->ring_capacity_frames;
    uint32_t available = (uint32_t)(write_idx - read_idx);

    if (available < num_frames) {
        // Underrun - output silence for missing frames
        atomic_fetch_add(&mem->underrun_count, 1);

        // Read what we have
        for (uint32_t i = 0; i < available; i++) {
            uint32_t pos = (uint32_t)((read_idx + i) % capacity);
            frames[i * 2 + 0] = mem->audio_data[pos * 2 + 0];
            frames[i * 2 + 1] = mem->audio_data[pos * 2 + 1];
        }

        // Fill rest with silence
        for (uint32_t i = available; i < num_frames; i++) {
            frames[i * 2 + 0] = 0.0f;
            frames[i * 2 + 1] = 0.0f;
        }

        atomic_store(&mem->read_index, read_idx + available);
        return num_frames;  // Return requested count, rest is silence
    }

    // Normal case - read requested frames
    for (uint32_t i = 0; i < num_frames; i++) {
        uint32_t pos = (uint32_t)((read_idx + i) % capacity);
        frames[i * 2 + 0] = mem->audio_data[pos * 2 + 0];
        frames[i * 2 + 1] = mem->audio_data[pos * 2 + 1];
    }

    atomic_store(&mem->read_index, read_idx + num_frames);
    return num_frames;
}

/**
 * Get ring buffer fill percentage (0.0 - 1.0).
 * Used for drift detection and monitoring.
 */
static inline double rf_ring_fill_percent(const RFSharedAudioV1* mem) {
    uint64_t write_idx = atomic_load(&mem->write_index);
    uint64_t read_idx = atomic_load(&mem->read_index);
    uint64_t used = write_idx - read_idx;
    return (double)used / (double)mem->ring_capacity_frames;
}

#ifdef __cplusplus
}
#endif

#endif // RF_SHARED_AUDIO_H
