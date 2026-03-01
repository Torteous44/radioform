# Radioform Host

`RadioformHost` is the background audio process used by Radioform on macOS.
It discovers physical output devices, creates shared memory endpoints for the HAL driver, runs DSP, and renders audio to the selected physical device.

## What It Does

- Enumerates physical output devices (excluding Radioform/Netcat and virtual/aggregate devices)
- Validates candidate devices (active channels, display-audio jack status, format/rate checks)
- Chooses an operating sample rate at startup from the current/selected physical device
- Creates one shared-memory file per physical device (`/tmp/radioform-<sanitized-uid>`)
- Writes the driver control file (`/tmp/radioform-devices.txt`)
- Starts heartbeat updates for driver/host health signaling
- Starts a CoreAudio HAL output unit and renders `ring buffer -> DSP -> hardware`
- Auto-switches system output to the matching proxy device and forwards proxy volume/mute to the physical device
- Monitors device list/default output changes and sleep/wake recovery hooks

## Architecture

```
RadioformHost
  |- DeviceDiscovery      (enumerate + validate physical devices)
  |- DeviceRegistry       (tracks devices, writes /tmp/radioform-devices.txt)
  |- SharedMemoryManager  (creates /tmp/radioform-<uid>, heartbeat timer)
  |- ProxyDeviceManager   (proxy<->physical mapping, auto-select, volume/mute forwarding)
  |- DSPProcessor         (CRadioformDSP wrapper)
  |- AudioRenderer        (reads ring buffer, processes DSP, writes output buffers)
  |- AudioEngine          (HAL output unit setup/start/stop/switch)
  |- DeviceMonitor        (CoreAudio listeners for device/default-output changes)
  |- PresetMonitor        (polls preset file and applies updates)
  |- SleepWakeMonitor     (IOKit notifications and wake recovery)
```

## Runtime Flow

Startup sequence in `main.swift`:

1. Ensures app support/log directories and migrates old preset path
2. Enumerates physical output devices and records validation status
3. Resolves preferred output device and reads nominal sample rate
4. Sets `RadioformConfig.activeSampleRate`
5. Registers device/default-output listeners
6. Creates shared memory for devices
7. Writes `/tmp/radioform-devices.txt`
8. Starts host heartbeat timer
9. Waits for driver proxy creation, then auto-selects proxy
10. Initializes DSP (applies flat preset, and updates sample rate when needed)
11. Sets up/starts HAL output unit
12. Starts preset monitoring and signal handlers

Shutdown path:

- Stops heartbeat and audio engine
- Restores physical output device when possible
- Removes control file and unmaps shared memory
- Attempts to restart `coreaudiod` during cleanup

## Device and Sample Rate Behavior

- Supported nominal sample rates are snapped to one of:
  `44100, 48000, 88200, 96000, 176400, 192000`.
- The operating sample rate is chosen at startup from the resolved physical output device.
- Device change handling switches output device routing; current code does not perform a full end-to-end pipeline rebuild on every switch.

## Paths and IPC

- Control file: `/tmp/radioform-devices.txt`
- Shared memory per device: `/tmp/radioform-<sanitized-uid>`
- Preset file: `~/Library/Application Support/Radioform/preset.json`

## Key Configuration (`Constants.swift`)

| Setting | Value / Meaning |
|---|---|
| `activeSampleRate` | Runtime-selected sample rate |
| `defaultSampleRate` | Fallback/default sample rate (48000) |
| `defaultChannels` | 2 |
| `defaultFormat` | `RF_FORMAT_FLOAT32` |
| `defaultDurationMs` | 100 |
| `heartbeatInterval` | 1.0s |
| `presetMonitorInterval` | 0.5s |
| `deviceWaitTimeout` | 2.0s |
| `cleanupWaitTimeout` | 1.2s |
| `physicalDeviceSwitchDelay` | 0.5s |
| `wakeRecoveryDelay` | 1.5s |

## Build

```bash
cd packages/host
swift build -c release
```

## Run

```bash
cd packages/host
./start_host.sh
```

`start_host.sh` launches `.build/release/RadioformHost` when available, otherwise `.build/debug/RadioformHost`.

## Logging

The host logs to stdout/stderr using step-oriented messages from `main.swift` and component-specific prefixes (for example `[AudioEngine]`, `[DeviceMonitor]`, `[Heartbeat]`, `[Cleanup]`).

## Dependencies

- `CRadioformAudio` (shared memory/ring-buffer C interface)
- `CRadioformDSP` (DSP C API)
- Apple frameworks: `CoreAudio`, `AudioToolbox`, `CoreFoundation`, `IOKit`
