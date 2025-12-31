# Radioform Architecture

**Status:** Phase 2 Planning
**Last Updated:** December 28, 2025

## Quick Reference: Audio Contract

These concrete definitions prevent entire classes of bugs. Decided before Phase 2 implementation begins.

### Canonical Transport Format
```
Sample Rate:     48,000 Hz (fixed, no variation)
Sample Format:   float32 (32-bit floating point)
Channel Layout:  stereo interleaved (LRLRLR...)
Bytes per Frame: 8 (2 channels × 4 bytes)
```

### Ring Buffer Configuration
```
Target Size:     20-40 ms of audio (960-1920 frames at 48 kHz)
Implementation:  Lock-free SPSC (single-producer, single-consumer)
Alignment:       Cache-line aligned (64 bytes)
Indices:         Atomic uint64_t (never wrap, mask on read)
```

### Backpressure Policies
```
Overflow:  Drop OLDEST frames (advance read pointer)
Underrun:  Output SILENCE (zeros, no hold-last)
```

### Sample Rate Conversion (SRC)
```
HAL always presents:  48 kHz
System does:          SRC before HAL (any rate → 48 kHz)
Host does:            SRC to physical device if needed (48 kHz → device rate)
```

### Device-Follow Policy
```
1. Ignore virtual/aggregate devices created by Radioform
2. Prefer system default output (excluding Radioform)
3. Filter AirPlay/Continuity (optional, user configurable)
4. User override: "Pin to device X" vs "Follow system default"
5. Staged switching: arm new output, swap atomically on buffer boundary
```

### Clock Drift Strategy
```
Target fill:    50% of ring buffer
Monitor:        Fill level trends (averaged over 1 second)
Correction:
  - If fill > 60%: drop ~1ms audio every few seconds
  - If fill < 40%: insert ~1ms silence every few seconds
```

### Safe Mode (Host Disconnected)
```
HAL behavior:   Output SILENCE (zeros)
Reason:         Can't passthrough without becoming a router
Host:           Launch as LaunchAgent, KeepAlive=true
Recovery:       Auto-restart on crash (~1 second)
```

---

## Architecture Overview

See [PHASE2_PLAN.md](PHASE2_PLAN.md) for complete architecture diagrams, component responsibilities, and implementation roadmap.

### Key Components

1. **HAL Plug-in** (`RadioformDriver.driver`)
   - Minimal & boring (stability over cleverness)
   - Writes to shared memory ring buffer
   - Silence mode when host disconnected
   - 48 kHz float32 stereo only

2. **Audio Host Engine** (`packages/host/`)
   - Headless-capable (isolated from UI)
   - Pulls from ring buffer (non-blocking)
   - Applies DSP (Phase 1 library)
   - Auto-follows physical devices
   - Buffer fill controller for clock drift

3. **Control App** (`Radioform.app`)
   - SwiftUI menu bar UI
   - Talks to host via in-process API
   - Preset management
   - Never touches HAL directly

4. **DSP Library** (`libradioform_dsp.a`)
   - Phase 1 - LOCKED ✅
   - 10-band parametric EQ
   - <1% CPU, <0.1% THD

### IPC: Dual-Plane Strategy

**Control Plane (XPC):**
- Device selection, sample rate, heartbeat, stats, presets
- Occasional messages (Hz, not kHz)

**Audio Plane (Shared Memory):**
- Continuous 48 kHz audio buffers
- Lock-free ring buffer
- Zero-copy, <5ms latency
- **Never use XPC for audio** (causes jitter)

---

## Shared Memory Layout

```c
struct RadioformSharedMemory {
    // Header (cache-line aligned)
    uint32_t protocol_version;        // v1 = 0x00010000
    uint32_t sample_rate;             // 48000 (fixed in v1)
    uint32_t channels;                // 2 (stereo)
    uint32_t bytes_per_frame;         // 8 (float32 * 2)
    uint32_t ring_capacity_frames;    // 960-1920 (20-40ms at 48kHz)

    // Atomic indices (never wrap, mask on read)
    atomic_uint64_t write_index;      // Producer (HAL)
    atomic_uint64_t read_index;       // Consumer (Host)

    // Monotonic frame counter (for drift detection)
    atomic_uint64_t total_frames_written;

    // Padding to cache line
    uint8_t _padding[64 - 32];

    // Ring buffer data (cache-line aligned)
    float audio_data[ring_capacity_frames * 2];  // Interleaved stereo
};
```

---

## Statistics Schema (XPC)

```swift
struct AudioStatistics: Codable {
    let timestamp: Date
    let ringBufferFillPercent: Double      // 0.0-1.0
    let underrunCount: UInt64              // Total since start
    let overrunCount: UInt64               // Total since start
    let framesProcessed: UInt64            // Monotonic counter
    let dspCpuPercent: Double              // Phase 1 DSP load
    let currentOutputDevice: String        // Device UID
}
```

Reported every 1 second over XPC for monitoring/graphing.

---

## Reference Implementations

- **BlackHole** - Modern audio loopback driver (shared memory approach)
- **Background Music** - Similar architecture
- **libASPL** - C++17 library for HAL plug-ins

---

## Next Steps

1. **Prototype Phase (2-3 days):** Prove shared memory + ring buffer works for 30+ minutes glitch-free
2. **Milestone 1:** Full HAL plug-in with silence mode
3. **Milestone 2:** Dual-plane IPC + clock drift controller
4. **Milestone 3:** Auto-follow physical devices

See [PHASE2_PLAN.md](PHASE2_PLAN.md) for complete roadmap.
