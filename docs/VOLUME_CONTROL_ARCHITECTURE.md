# Volume Control Architecture

## Overview

Radioform implements a dual-device volume control architecture that differs from standard macOS audio behavior. This document explains how volume control works before and after Radioform is running.

## Volume Control: Before Radioform

In standard macOS operation (without Radioform):

```
User → System Volume Control → Physical Device Volume (0-100%) → Speakers/Headphones
```

- User adjusts volume in System Settings or via keyboard
- Physical audio device volume changes (e.g., 0% to 100%)
- Signal amplitude is reduced at the hardware level
- Lower volume settings can reduce effective bit depth and dynamic range

## Volume Control: With Radioform Running

When Radioform is active:

```
User → Radioform Virtual Device Volume (0-100%) → DSP Processing → Physical Device (locked at 100%) → Speakers/Headphones
```

- Physical device volume is automatically set to **100%** (maximum)
- User controls volume through the **Radioform virtual device**
- Volume adjustment happens in DSP (Digital Signal Processing) layer
- Full dynamic range preserved at all volume levels

## Why This Architecture?

### 1. Maximum Dynamic Range
Setting the physical device to 100% ensures the full audio signal reaches Radioform without hardware-level attenuation. This preserves:
- Full bit depth resolution
- Maximum signal-to-noise ratio
- Optimal headroom for DSP processing

### 2. Consistent Audio Quality
Volume control in the DSP layer (software) provides:
- Precise digital volume control
- No hardware-dependent variations
- Consistent behavior across different devices

### 3. Single Control Point
Users adjust volume through:
- Radioform virtual device in System Settings → Sound
- Standard macOS volume keys/controls
- Menu bar volume slider (when controlling Radioform device)

## Implementation Details

### Location in Codebase

The volume control architecture is implemented in:
- **File**: `/packages/host/Sources/RadioformHost/Audio/AudioEngine.swift`
- **Key function**: `setPhysicalDeviceVolume(_:volume:)` (lines 320-403)
- **Initialization**: Called during `setupWithDevice()` (line 113)

### Code Flow

1. **Device Setup** (line 113):
   ```swift
   setPhysicalDeviceVolume(device.id, volume: 1.0)
   ```

2. **Volume Setting** (lines 320-403):
   - Attempts to set master volume to 1.0 (100%)
   - Falls back to per-channel volume if master not supported
   - Verifies volume was actually set

3. **Warning System** (lines 376-388):
   - If physical device cannot reach 95%+ volume
   - Warns user: "Maximum effective volume will be limited"
   - Some devices don't support software volume control

### Device Compatibility

**Fully Compatible Devices:**
- Most modern USB audio interfaces
- Standard built-in Mac speakers
- Most Bluetooth headphones
- Devices that support software volume control

**Limited Compatibility:**
- Devices that don't reach 95%+ software volume
- Hardware that limits maximum software-controllable volume
- Some professional audio interfaces with fixed output levels

### Example Output

When Radioform initializes successfully:
```
Physical device initial volume: 50%
Set physical device master volume to 100%
Using device ID: 73
Physical device set to 100% (Radioform driver controls volume)
```

When device has limitations:
```
⚠ WARNING: Physical device volume is 75%
⚠ This device may not support software volume control.
⚠ Maximum effective volume will be limited to 75%
```

## User Experience

### Before Radioform
- Adjust volume: System Settings → Sound → Output Device slider
- Volume keys control physical device directly

### After Radioform
- Adjust volume: System Settings → Sound → Radioform (select matching device)
- Volume keys control Radioform virtual device
- Physical device stays at 100% (not user-controllable)

## Technical Benefits

1. **Bit Depth Preservation**: Operating at full volume prevents quantization errors from hardware volume reduction
2. **DSP Headroom**: Full signal amplitude allows proper limiter and preamp operation
3. **Consistency**: Same audio quality regardless of volume level
4. **Integration**: Works seamlessly with macOS audio system

## Related Components

- **DSP Engine** (`/packages/dsp`): Applies volume control in processing chain
- **Audio Driver** (`/packages/driver`): Presents Radioform virtual device to macOS
- **Audio Host** (`/packages/host`): Manages physical device configuration
- **Menu Bar App** (`/apps/mac`): Provides user interface for volume/EQ control

## See Also

- Main implementation: `/packages/host/Sources/RadioformHost/Audio/AudioEngine.swift`
- Audio engine tests: Look for volume-related test cases
- User documentation: README.md
