# Issue #55: Audio Considerably Louder When Radioform Running

## Bug Summary

When Radioform is running, audio is considerably louder than expected — even with EQ off or "Flat" profile, and even with the volume slider turned down. One user reports "1 notch = 9 notches" and background "fuzz" at any volume level.

Headphones tested: Sennheiser HD6XX, Grado SR60X, Moondrop Aria (all via headphone jack).

---

## Root Cause Analysis

There are **two independent issues** contributing to this bug.

### Issue A: Physical Device Locked to 100% (Primary — causes loudness)

**File:** `packages/host/Sources/RadioformHost/Audio/AudioEngine.swift:120`

```swift
setPhysicalDeviceVolume(device.id, volume: 1.0)
```

The architecture locks the physical output device to 100% volume on setup. A volume listener (line 323-378) also re-locks the device to 100% if anything changes it below 95%.

**Why this causes the bug:**
- Before Radioform: macOS volume controls both **digital gain** AND **analog amplifier level** on the physical device
- With Radioform: Physical device analog amp is maxed at 100%. Only digital attenuation on the virtual device remains
- The headphone amplifier at 100% output is far louder than typical listening levels
- Even small digital signal levels produce high SPL because the analog stage is cranked
- The volume curve feels compressed — "1 notch = 9 notches"

### Issue B: Flat Preset Isn't Truly Flat (Secondary — causes fuzz/distortion)

Three inconsistencies make the "Flat" path non-transparent:

| Location | Problem |
|---|---|
| `apps/mac/.../Presets/Flat.json:76` | `limiter_enabled: true` with threshold `-1.0 dB` |
| `apps/mac/.../Presets/Flat.json` all bands | All 10 bands `enabled: true` at 0 dB gain |
| `packages/host/.../DSPProcessor.swift:45` | `createFlatPreset()` overrides C library's `limiter_enabled = false` to `true` |

The C library (`packages/dsp/src/preset.cpp:35`) correctly sets `limiter_enabled = false` for flat presets, but the Swift host overrides it.

**Limiter causes the "fuzz":**
- Threshold at `-1.0 dB` means soft-knee compression starts at ~`-2.0 dB` (knee_start = threshold * 0.8)
- Most normal audio has peaks above -2 dB, so the limiter is constantly compressing
- The rational-function soft clipper introduces subtle harmonic distortion
- This is the "fuzz" the second reporter describes

---

## Audio Signal Flow (for reference)

```
App Audio
  |
  v
Radioform Virtual Device (ASPL, EnableMixing=true)
  |  <- macOS volume slider applies digital attenuation here (CoreAudio mixer)
  v
HAL Driver (Plugin.cpp) — OnWriteMixedOutput
  |  <- Converts to float32 interleaved, no gain applied
  v
Shared Memory Ring Buffer (RFSharedAudio)
  |
  v
Host AudioRenderer (AudioRenderer.swift)
  |  <- Reads from ring buffer via rf_ring_read
  v
DSP Engine (engine.cpp)
  |  <- Preamp gain -> 10x Biquad EQ bands -> DC Blocker (5Hz HPF) -> Soft Limiter
  v
Physical Output Device (AudioEngine.swift)
  <- LOCKED TO 100% VOLUME
```

---

## Key Files

| File | Role |
|---|---|
| `packages/host/Sources/RadioformHost/Audio/AudioEngine.swift` | Sets physical device to 100%, volume listener |
| `packages/host/Sources/RadioformHost/Audio/AudioRenderer.swift` | Render callback, reads ring buffer, calls DSP |
| `packages/host/Sources/RadioformHost/Audio/DSPProcessor.swift` | Swift wrapper for C DSP, `createFlatPreset()` |
| `packages/dsp/src/engine.cpp` | Main DSP processing loop |
| `packages/dsp/src/preset.cpp` | Preset init/validation, `radioform_dsp_preset_init_flat()` |
| `packages/dsp/src/limiter.h` | SoftLimiter — rational-function soft clipper |
| `packages/dsp/src/biquad.h` | Biquad filter (RBJ cookbook) |
| `packages/dsp/src/smoothing.h` | Parameter smoothing, `db_to_gain()` |
| `packages/dsp/src/dc_blocker.h` | DC offset removal (5Hz HPF) |
| `packages/driver/src/Plugin.cpp` | HAL driver, `OnWriteMixedOutput`, ring buffer writes |
| `apps/mac/.../Resources/Presets/Flat.json` | Flat preset JSON |

---

## What's NOT the Problem

- **Biquad math**: Peak filter at 0 dB gain is mathematically unity regardless of Q. Verified: when gain_db=0, A=1.0, and the transfer function collapses to H(z)=1.
- **Driver**: Passes audio through cleanly with no gain applied.
- **Preamp**: At 0 dB correctly applies 1.0x gain via `db_to_gain(0) = 1.0`.
- **Ring buffer**: Format conversion is correct, no gain issues.

---

## Limiter Details

**File:** `packages/dsp/src/limiter.h`

```cpp
void setThreshold(float threshold_db) {
    threshold_ = std::pow(10.0f, threshold_db / 20.0f);
    knee_start_ = threshold_ * 0.8f;  // Soft knee at 80% of threshold
}
```

For `-1.0 dB` threshold:
- threshold_ = 0.891 (linear)
- knee_start_ = 0.713 (linear) = ~-2.9 dB

For `-0.1 dB` threshold (DSPProcessor.swift default):
- threshold_ = 0.989 (linear)
- knee_start_ = 0.791 (linear) = ~-2.0 dB

The soft-knee region is wide. Any audio peaking above -3 dB gets compressed.

---

## All Presets Have limiter_enabled: true

Checked `Rock.json` — also has `limiter_enabled: true, limiter_threshold_db: -1.0`. This likely applies to all presets. The limiter should be a safety net at 0 dB (or disabled), not an always-on compressor at -1 dB.
