# Issue #55: Proposed Fixes

## Fix 1: Flat Preset — True Bypass (Easy)

**File:** `apps/mac/RadioformApp/Sources/Resources/Presets/Flat.json`

Changes:
- Set `limiter_enabled: false`
- Set all 10 bands to `enabled: false`

This makes Flat a true passthrough — no DSP processing, no artifacts.

## Fix 2: DSPProcessor.swift — Remove Limiter Override (Easy)

**File:** `packages/host/Sources/RadioformHost/Audio/DSPProcessor.swift`

Change `createFlatPreset()` to respect the C library defaults:

```swift
func createFlatPreset() -> radioform_preset_t {
    var preset = radioform_preset_t()
    radioform_dsp_preset_init_flat(&preset)
    // Don't override limiter_enabled — C library correctly sets it to false
    return preset
}
```

The C library (`preset.cpp:35`) already sets `limiter_enabled = false` and `preamp_db = 0.0` for flat presets. The Swift code was overriding this.

## Fix 3: All Presets — Raise Limiter Threshold (Easy)

All presets currently use `limiter_threshold_db: -1.0`, which is far too aggressive. The soft knee starts compressing from ~-3 dB.

Change all preset JSON files to use `limiter_threshold_db: -0.1` (just below 0 dBFS). This makes the limiter a safety ceiling rather than an always-on compressor.

Affected files:
- `apps/mac/.../Presets/Acoustic.json`
- `apps/mac/.../Presets/Classical.json`
- `apps/mac/.../Presets/Electronic.json`
- `apps/mac/.../Presets/Hip-Hop.json`
- `apps/mac/.../Presets/Pop.json`
- `apps/mac/.../Presets/R&B.json`
- `apps/mac/.../Presets/Rock.json`

## Fix 4: Volume Architecture (Hard — Needs Design Decision)

**The problem:** Physical device is locked to 100%, maxing the analog amplifier. This makes everything too loud.

**The constraint:** We want full dynamic range for DSP processing.

**The reality:** For a ±12 dB parametric EQ in float32, full dynamic range from 100% physical is unnecessary. Float32 has ~1530 dB of dynamic range. Even at 30% physical volume, the signal has far more headroom than the ±12 dB EQ range needs.

### Option A: Don't Lock Physical Device (Recommended)

**Changes:**
1. `AudioEngine.swift:120` — Remove `setPhysicalDeviceVolume(device.id, volume: 1.0)`
2. `AudioEngine.swift:206` — Remove `setPhysicalDeviceVolume(deviceID, volume: 1.0)` in `switchDevice`
3. Remove `addVolumeListener` / `removeVolumeListener` / `handleVolumeChanged` — stop re-locking volume
4. Remove `isRelockingVolume` flag

The user's existing physical device volume is preserved. macOS volume slider works naturally. DSP works fine regardless.

**Pros:** Simple, zero risk, fixes the bug immediately
**Cons:** Slightly less dynamic range (negligible in practice for float32 EQ)

### Option B: Post-DSP Volume Stage

Keep physical at 100% but add output attenuation after DSP:

1. Add an `output_gain` field to the DSP engine (applied after limiter)
2. Mirror the virtual device's volume control to `output_gain`
3. The virtual device volume slider effectively becomes a post-DSP master volume

**Pros:** Full dynamic range for DSP, clean architecture
**Cons:** More complex, need to intercept virtual device volume changes, potential latency in volume response

### Option C: Hybrid — Save/Restore Physical Volume

1. On startup: save the user's current physical device volume
2. Lock physical to 100% for DSP processing
3. On shutdown: restore the saved volume
4. Apply a compensating output gain = saved_volume, applied post-DSP

**Pros:** Full dynamic range, user doesn't notice volume jump
**Cons:** Complex, race conditions on crash/unexpected exit

### Research TODO

Look at how these open-source projects handle this:
- **eqMac** (github.com/bitgapp/eqMac) — macOS EQ with virtual device
- **BackgroundMusic** (github.com/kyleneideck/BackgroundMusic) — volume control per-app
- **BlackHole** (github.com/ExistentialAudio/BlackHole) — virtual audio routing
- **libASPL examples** — ASPL-based volume handling patterns

Key questions to answer:
1. Does eqMac lock physical device to 100%? How does it handle volume?
2. Does BackgroundMusic forward volume between virtual and physical?
3. How do ASPL devices handle `OnWriteMixedOutput` + volume controls?
