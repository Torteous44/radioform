# RadioformAudioHost

CoreAudio engine + device management layer.

## Purpose

The "always on" engine that:
- Receives audio from the virtual device
- Runs DSP processing
- Outputs to the selected physical device
- Handles device switching, hot-swaps, and recovery

## Components to Implement

### Engine
- `AudioGraphController`: state machine (stopped → starting → running → recovering)
- Stream format negotiation (sample rate, channels, bit depth)
- Clean startup/shutdown sequences

### Devices
- Device discovery and selection
- "Follow default output" implementation
- Handle disappear/reappear (AirPods, HDMI, dock scenarios)

### IO
- CoreAudio callbacks / IOProc implementation
- Ring buffers and lock-free queues
- Zero-allocation realtime path

### Resampling
- Sample rate conversion when device rates differ
- Configuration and quality settings

### DSP Integration
- Bridge bindings to `packages/bridge`
- Bypass path (when DSP is disabled)
- Preamp and limiter stages

### Diagnostics
- Underrun watchdog
- CPU load meter
- Safe-mode triggers (auto-bypass on overload)
- Structured logging
- "Generate diagnostics" bundle export

## Deliverable

This target should be runnable **headless** (as a launch agent), so the menu bar app can crash or restart without killing audio.
