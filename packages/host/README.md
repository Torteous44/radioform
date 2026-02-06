# Radioform Host

The audio processing host for Radioform. Manages device discovery, shared memory communication with the HAL driver, and real-time DSP execution.

## Features

- Dynamic sample rate matching (44.1kHz–192kHz) for lossless audio quality
- Automatic device discovery and validation
- Shared memory ring buffer for driver communication
- Real-time DSP processing via the Radioform DSP library
- Automatic device switching with sample rate reconfiguration
- Volume locking to maximize dynamic range

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      RadioformHost                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐    ┌──────────────────────────────┐   │
│  │ DeviceDiscovery │───▶│ DeviceRegistry               │   │
│  │ - Enumerate     │    │ - Track physical devices     │   │
│  │ - Validate      │    │ - Write control file         │   │
│  │ - Sample rate   │    └──────────────────────────────┘   │
│  └─────────────────┘                                        │
│                                                             │
│  ┌─────────────────┐    ┌──────────────────────────────┐   │
│  │ DeviceMonitor   │───▶│ ProxyDeviceManager           │   │
│  │ - Device changes│    │ - Map proxy ↔ physical       │   │
│  │ - Rate changes  │    │ - Handle device switching    │   │
│  └─────────────────┘    └──────────────────────────────┘   │
│                                                             │
│  ┌─────────────────┐    ┌──────────────────────────────┐   │
│  │ AudioEngine     │───▶│ AudioRenderer                │   │
│  │ - HAL output    │    │ - Ring buffer read           │   │
│  │ - Format setup  │    │ - DSP processing             │   │
│  └─────────────────┘    └──────────────────────────────┘   │
│                                                             │
│  ┌─────────────────┐    ┌──────────────────────────────┐   │
│  │ SharedMemory    │◀──▶│ DSPProcessor                 │   │
│  │ Manager         │    │ - 10-band EQ                 │   │
│  │ - Ring buffers  │    │ - Preamp + limiter           │   │
│  │ - Heartbeat     │    │ - Sample rate updates        │   │
│  └─────────────────┘    └──────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
         │                           ▲
         │ Shared Memory             │ CoreAudio
         ▼                           │
┌─────────────────┐         ┌────────┴────────┐
│ Radioform       │         │ Physical Audio  │
│ HAL Driver      │         │ Device          │
└─────────────────┘         └─────────────────┘
```

## Dynamic Sample Rate

The host automatically matches the physical device's native sample rate to eliminate resampling artifacts:

1. **Startup**: Queries the preferred device's nominal sample rate and configures the entire pipeline (shared memory, DSP, audio engine) to match
2. **Device Switching**: Detects sample rate changes when switching devices and reconfigures on the fly
3. **Supported Rates**: 44.1kHz, 48kHz, 88.2kHz, 96kHz, 176.4kHz, 192kHz

This ensures bit-perfect audio when the source and device rates match, with no unnecessary resampling in the driver.

## Directory Structure

```
packages/host/
├── Sources/
│   ├── RadioformHost/
│   │   ├── main.swift              # Entry point, initialization
│   │   ├── Constants.swift         # Configuration (activeSampleRate, etc.)
│   │   ├── Audio/
│   │   │   ├── AudioEngine.swift       # CoreAudio HAL output
│   │   │   ├── AudioRenderer.swift     # Ring buffer → DSP → output
│   │   │   └── DSPProcessor.swift      # DSP library wrapper
│   │   ├── Devices/
│   │   │   ├── DeviceDiscovery.swift   # Enumerate physical devices
│   │   │   ├── DeviceRegistry.swift    # Device state management
│   │   │   ├── DeviceMonitor.swift     # Change detection + rate switching
│   │   │   └── ProxyDeviceManager.swift # Proxy ↔ physical mapping
│   │   ├── Memory/
│   │   │   └── SharedMemoryManager.swift # Ring buffer allocation
│   │   ├── Presets/
│   │   │   ├── PresetLoader.swift      # JSON preset loading
│   │   │   └── PresetMonitor.swift     # File change monitoring
│   │   └── Utilities/
│   │       └── PathManager.swift       # File paths
│   ├── CRadioformAudio/            # C bindings for shared memory
│   └── CRadioformDSP/              # C bindings for DSP library
└── Package.swift
```

## Key Components

### DeviceDiscovery

Enumerates physical audio devices and validates them for use:
- Filters out virtual/aggregate devices
- Checks for active output channels
- Validates jack connection for HDMI/DisplayPort
- Queries nominal sample rate for dynamic configuration

### SharedMemoryManager

Manages ring buffer shared memory for driver communication:
- Creates memory-mapped files per device
- Configures buffer size based on active sample rate
- Maintains heartbeat for health monitoring

### AudioEngine

Binds to physical devices via CoreAudio HAL:
- Configures stream format to match active sample rate
- Locks physical device volume to 100% for maximum dynamic range
- Handles device switching with automatic fallback

### DeviceMonitor

Listens for system audio changes:
- Detects default output device changes
- Triggers sample rate reconfiguration when switching to devices with different rates
- Coordinates stop → reconfigure → restart sequence

### DSPProcessor

Wraps the Radioform DSP library:
- Initializes with current sample rate
- Supports runtime sample rate changes via `setSampleRate()`
- Applies EQ presets and processes audio in real-time

## Configuration

Key settings in `Constants.swift`:

| Setting | Description |
|---------|-------------|
| `activeSampleRate` | Current operating sample rate (set at runtime) |
| `fallbackSampleRate` | Default rate if device query fails (48kHz) |
| `defaultChannels` | Stereo (2 channels) |
| `defaultDurationMs` | Ring buffer duration (40ms) |
| `heartbeatInterval` | Health check interval (1 second) |

## Build

```bash
cd packages/host
swift build -c release
```

The host executable is built as part of the main Radioform build process via the root Makefile.

## Runtime

The host is launched by the Radioform menu bar app and runs as a background process. It:

1. Discovers physical audio devices
2. Determines operating sample rate from preferred device
3. Creates shared memory ring buffers
4. Writes control file for driver device creation
5. Starts audio engine bound to physical device
6. Monitors for device changes and preset updates
7. Cleans up on SIGINT/SIGTERM

## Logging

The host outputs structured logs to stdout:

```
[Step 0] Setting up directories...
[Step 1] Discovering physical audio devices...
[Step 1.5] Operating sample rate: 96000 Hz (from USB Audio DAC)
[Step 2] Registering device change listeners...
...
[DeviceMonitor] Sample rate change: 96000 -> 44100 Hz
[DeviceMonitor] Audio engine restarted at 44100 Hz
```

## Dependencies

- **CRadioformAudio**: C library for shared memory ring buffer operations
- **CRadioformDSP**: C bindings for the Radioform DSP engine
- **CoreAudio**: macOS audio HAL framework
- **AudioToolbox**: Audio unit and format utilities
