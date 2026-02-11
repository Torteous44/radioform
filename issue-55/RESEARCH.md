# Issue #55: Open Source Research

## BackgroundMusic (most relevant)

**Repo:** https://github.com/kyleneideck/BackgroundMusic

**Architecture: Volume Forwarding**

BackgroundMusic's approach is the most relevant to our problem. From their DEVELOPING.md:

- BGMDevice (virtual device) is set as the system default output
- When users adjust system volume, only BGMDevice's volume changes
- **BGMApp listens for volume changes on BGMDevice and sets the physical output device's volume to match**
- The virtual device itself does NOT apply volume to its audio stream — it keeps the signal at full level
- The app forwards the volume control to the real device

This means:
1. Audio signal stays at full level through the virtual device (full dynamic range for processing)
2. The physical device's analog volume is changed to match what the user set
3. macOS volume slider experience is completely natural
4. No need to lock physical device at 100%

**Implementation pattern:**
- HAL property listener on virtual device for `kAudioDevicePropertyVolumeScalar`
- When virtual device volume changes → read the value → set same value on physical device
- BGM_Device.cpp handles the property notifications

## SoundMax

**Repo:** https://github.com/snap-sites/SoundMax

Uses BlackHole as the virtual driver. Applies all adjustments — including volume — in software through the signal processing chain. Has a "software volume slider" specifically for HDMI outputs where macOS disables hardware volume control.

Signal flow: Apps → BlackHole (virtual driver) → SoundMax (processing) → Physical Output

Saves per-device volume and EQ settings.

## Proxy Audio Device

**Repo:** https://github.com/briankendall/proxy-audio-device

Purpose: "Make it possible to use macOS's system volume controls to change the volume of external audio interfaces that don't allow it."

A virtual audio driver that forwards all audio to another output device. Implementation details not documented in README but the concept is volume forwarding from virtual to physical.

## eqMac

**Repo:** https://github.com/bitgapp/eqMac

Open source version is v1.3.2 — newer versions are on a private fork. The driver grabs system audio, app processes it, sends to output device. Volume handling details are in the private fork so we can't inspect them.

Advertises "volume and balance support for HDMI, DisplayPort, and any other audio device" with ability to boost beyond 100%.

---

## Recommended Approach for Radioform (based on research)

**Use BackgroundMusic's "Volume Forwarding" pattern:**

1. Stop locking physical device to 100%
2. When the Radioform virtual device's volume changes (user adjusts macOS slider), listen for the HAL property change
3. Forward that volume value to the physical output device
4. The virtual device's audio stream stays at full level (CoreAudio mixer at 100% on the virtual device? OR the ASPL device doesn't apply volume to the mixed output — need to verify)

**Key question to resolve:** With ASPL's `EnableMixing = true`, does CoreAudio's mixer attenuate the signal in `OnWriteMixedOutput` based on the virtual device's volume? If yes, we need to either:
- Disable mixing and handle it ourselves
- Or accept that the signal is pre-attenuated (still fine for float32 ±12 dB EQ)

**Simplest implementation:**
- We already HAVE a volume listener in AudioEngine.swift (it currently re-locks to 100%)
- Instead of re-locking, **forward the virtual device volume to the physical device**
- This reuses existing infrastructure with minimal changes

**Files to change:**
- `AudioEngine.swift` — change `handleVolumeChanged()` to forward instead of re-lock
- Need to add a listener on the **virtual device** (not physical) for volume changes
- Forward virtual device volume → physical device volume
