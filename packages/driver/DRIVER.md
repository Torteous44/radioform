# Radioform HAL Driver

A CoreAudio HAL (Hardware Abstraction Layer) plugin that creates virtual proxy audio output devices on macOS. When an application sends audio to a proxy device, the driver captures it and writes it into a shared memory ring buffer. The Host process reads from this buffer, applies DSP, and plays the result on the real hardware device.

## How it works

```
Application audio
    │
    ▼
┌──────────────────────────┐
│  macOS CoreAudio (HAL)   │
│  routes output to proxy  │
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────────┐
│  RadioformDriver         │
│  (this plugin)           │
│                          │
│  OnWriteMixedOutput()    │
│  ├─ format conversion    │
│  ├─ sample rate convert  │
│  └─ ring buffer write    │
└──────────┬───────────────┘
           │  shared memory (mmap)
           │  /tmp/radioform-<uid>
           ▼
┌──────────────────────────┐
│  RadioformHost           │
│  ├─ ring buffer read     │
│  ├─ DSP processing       │
│  └─ real device output   │
└──────────────────────────┘
```

The driver runs inside `coreaudiod` (the system audio daemon), not as a standalone process. It is loaded automatically when installed to `/Library/Audio/Plug-Ins/HAL/`.

## Files

| File | Purpose |
|---|---|
| `src/Plugin.cpp` | All driver logic: device creation, audio capture, health monitoring, device sync |
| `include/RFSharedAudio.h` | Shared memory layout and ring buffer read/write functions. Shared with the Host (identical copy at `packages/host/Sources/CRadioformAudio/include/RFSharedAudio.h`) |
| `CMakeLists.txt` | Build configuration. Produces `RadioformDriver.driver` bundle |
| `Info.plist` | Bundle metadata, plugin factory UUID, bundle identifier (`com.radioform.driver`) |
| `install.sh` | Copies built driver to `/Library/Audio/Plug-Ins/HAL/` with `root:wheel` ownership |
| `uninstall.sh` | Removes the installed driver |
| `VERSION` | Current version string |
| `vendor/libASPL/` | Third-party library that wraps the CoreAudio HAL plugin C API in C++ classes |

## Entry point

```cpp
extern "C" void* RadioformDriverPluginFactory(CFAllocatorRef allocator, CFUUIDRef typeUUID)
```

This is the standard `CFPlugIn` factory function. CoreAudio calls it once when the plugin is loaded. It creates the global state, starts the device monitor thread, and returns a reference to the `aspl::Driver` singleton. The factory UUID is `B3F04000-8F04-4F84-A72E-B2D4F8E6F1DA` (registered in `Info.plist`).

## Device lifecycle

The driver does not hardcode any devices. It dynamically creates and destroys proxy devices by polling a control file written by the Host.

### Control file: `/tmp/radioform-devices.txt`

Written by the Host. Each line has the format:

```
DeviceName|DeviceUID
```

The driver's monitor thread (`MonitorControlFile`) reads this file every 1 second and calls `SyncDevices()` to reconcile the desired state with the current state:

- **Add**: If a UID appears in the control file but has no proxy device, and the Host heartbeat for that UID is fresh, and the device is not in cooldown, create a proxy device.
- **Remove**: If a proxy device exists but its UID is absent from the control file (or the Host heartbeat is stale), remove it.
- **Cooldown**: After removing a device, the same UID cannot be re-added for 10 seconds. This prevents rapid add/remove cycling.

### Proxy device creation

Each proxy device is created via `CreateProxyDevice()`:

- Name: `"<OriginalName> (Radioform)"`
- UID: `"<OriginalUID>-radioform"`
- Manufacturer: `"Radioform"`
- Default format: 48 kHz, 2 channels, mixing enabled
- One output stream with volume/mute controls
- IO and control handled by a `UniversalAudioHandler` instance

## Audio path

### OnStartIO

Called by CoreAudio when the first application begins sending audio to a proxy device. The handler:

1. Opens the shared memory file at `/tmp/radioform-<sanitized-uid>`
2. Memory-maps it with `PROT_READ | PROT_WRITE` and `MAP_SHARED`
3. Validates the connection: checks protocol version (`0x00020000`), sample rate, channel count
4. Pre-allocates conversion buffers (4096 frames * 8 channels) to avoid heap allocation during audio callbacks
5. Sets `driver_connected = 1` in shared memory
6. Retries up to 15 times with exponential backoff (30ms base, max ~1.9s) if the shared memory file doesn't exist yet

Multiple IO clients are reference-counted. `OnStopIO` disconnects shared memory when the last client stops.

### OnWriteMixedOutput

Called by CoreAudio on the IO thread for every audio buffer. This is the hot path (~1000 calls/second at 48 kHz with 48-frame buffers). The handler:

1. Runs a health check every 3 seconds (file existence, host connection flag, host heartbeat, ring buffer integrity)
2. Updates the driver heartbeat every 1 second
3. Reads the stream's current `AudioStreamBasicDescription`
4. Detects format changes (sample rate or channel count) and creates a resampler if needed
5. Converts incoming audio to interleaved float32 (supports float32, int16, int24, int32, non-interleaved layouts)
6. If the stream sample rate differs from the shared memory sample rate, resamples using linear interpolation
7. Writes the converted frames into the ring buffer via `rf_ring_write()`
8. Logs stats every 30 seconds

All conversion uses pre-allocated member buffers (`interleaved_buf_`, `resampled_buf_`) that grow as needed but never shrink, so the steady-state audio path performs zero heap allocations.

## Shared memory layout (`RFSharedAudio`)

Defined in `include/RFSharedAudio.h`. The struct is 256 bytes (padded with `_reserved` for future expansion) followed by a flexible array member for audio data.

### Header fields

| Offset | Field | Type | Description |
|---|---|---|---|
| 0 | `protocol_version` | `uint32_t` | `0x00020000` |
| 4 | `header_size` | `uint32_t` | `sizeof(RFSharedAudio)` (256) |
| 8 | `sample_rate` | `uint32_t` | 44100, 48000, 88200, 96000, 176400, or 192000 |
| 12 | `channels` | `uint32_t` | 1-8 |
| 16 | `format` | `uint32_t` | `RFAudioFormat` enum (0=float32, 1=float64, 2=int16, 3=int24, 4=int32) |
| 20 | `bytes_per_sample` | `uint32_t` | Derived from format (2, 3, 4, or 8) |
| 24 | `bytes_per_frame` | `uint32_t` | `bytes_per_sample * channels` |
| 28 | `ring_capacity_frames` | `uint32_t` | `sample_rate * duration_ms / 1000` |
| 32 | `ring_duration_ms` | `uint32_t` | Typically 40 (range: 20-100) |
| 36 | `driver_capabilities` | `uint32_t` | Bitmask of `RF_CAP_*` flags |
| 40 | `host_capabilities` | `uint32_t` | Bitmask of `RF_CAP_*` flags |
| 44 | `creation_timestamp` | `uint64_t` | Unix epoch seconds |
| 52 | `format_change_counter` | `atomic uint64_t` | Incremented on format change |
| 60 | `write_index` | `atomic uint64_t` | Monotonically increasing frame count (producer) |
| 68 | `read_index` | `atomic uint64_t` | Monotonically increasing frame count (consumer) |
| 76 | `total_frames_written` | `atomic uint64_t` | Cumulative write counter |
| 84 | `total_frames_read` | `atomic uint64_t` | Cumulative read counter |
| 92 | `overrun_count` | `atomic uint64_t` | Times write overtook read |
| 100 | `underrun_count` | `atomic uint64_t` | Times read had no data |
| 108 | `format_mismatch_count` | `atomic uint64_t` | Format negotiation failures |
| 116 | `driver_connected` | `atomic uint32_t` | 1 if driver is active |
| 120 | `host_connected` | `atomic uint32_t` | 1 if host is active |
| 124 | `driver_heartbeat` | `atomic uint64_t` | Incremented every ~1s by driver |
| 132 | `host_heartbeat` | `atomic uint64_t` | Incremented every ~1s by host |
| 136-255 | `_reserved` | `uint8_t[120]` | Padding for future expansion |
| 256+ | `audio_data[]` | `uint8_t[]` | Ring buffer: `ring_capacity_frames * bytes_per_frame` bytes |

### Total file size

```
256 + (ring_capacity_frames * channels * bytes_per_sample)
```

At 48 kHz, 2 channels, float32, 40ms: `256 + (1920 * 2 * 4)` = 15,616 bytes.

### Ring buffer

Single-producer (driver), single-consumer (host). Uses monotonically increasing 64-bit indices with modulo for position. On overflow (write catches up to read), the driver advances `read_index` to make room and increments `overrun_count`. On underrun (read has no data), the host fills silence and increments `underrun_count`.

The ring buffer always stores audio in the format specified by the `format` field. `rf_ring_write()` accepts float32 and converts on write. `rf_ring_read()` converts back to float32 on read.

## Health monitoring

The driver monitors connection health every 3 seconds during active IO:

| Check | Failure condition |
|---|---|
| File existence | Shared memory file at `/tmp/radioform-<uid>` was deleted |
| Host connection | `host_connected` flag is 0 |
| Host heartbeat | `host_heartbeat` value hasn't changed for 5+ seconds |
| Ring integrity | `write_index < read_index` (corruption) |
| Ring overflow | `write_index - read_index > ring_capacity_frames` |

On failure, the driver attempts recovery: disconnects, re-opens the shared memory file, and re-validates.

## Heartbeat protocol

Both driver and host increment their respective heartbeat counters every ~1 second:

- **Driver**: Increments `driver_heartbeat` and sets `driver_connected = 1` during `OnWriteMixedOutput`
- **Host**: Increments `host_heartbeat` and sets `host_connected = 1` via a `DispatchSourceTimer`

The driver considers the host stale if `host_heartbeat` hasn't changed for 5 seconds. The device monitor thread also checks host heartbeat freshness before adding new proxy devices, preventing ghost devices from stale control file entries.

## Format conversion

The driver accepts any format CoreAudio sends and converts to interleaved float32 for the ring buffer:

| Input format | Conversion |
|---|---|
| Float32 interleaved | `memcpy` (zero-cost) |
| Float32 non-interleaved | Channel interleaving |
| Int16 | `sample / 32768.0f` |
| Int24 (packed 3-byte) | Sign-extend to int32, then `sample / 8388608.0f` |
| Int32 | `sample / 2147483648.0f` |

### Sample rate conversion

If the stream sample rate differs from the shared memory sample rate, a `SimpleResampler` performs linear interpolation. This is a basic resampler — adequate for the common case where rates match, but introduces some aliasing when active.

## Building

```sh
cd packages/driver
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

Produces `build/RadioformDriver.driver` (a macOS bundle).

Debug build enables AddressSanitizer:

```sh
cmake -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build
```

## Installing

```sh
cd packages/driver
./install.sh
sudo killall coreaudiod
```

The driver is installed to `/Library/Audio/Plug-Ins/HAL/RadioformDriver.driver` with `root:wheel` ownership. Restarting `coreaudiod` is required for the system to load the new plugin. This interrupts all audio for ~2 seconds.

## Uninstalling

```sh
cd packages/driver
./uninstall.sh
sudo killall coreaudiod
```

## Logging

Two logging systems:

- **os_log**: Subsystem `com.radioform.driver`. View with:
  ```sh
  log show --predicate 'subsystem == "com.radioform.driver"' --last 5m
  ```
- **File log**: `/tmp/radioform-driver-debug.log`. Fallback for when unified logs are unavailable (e.g., early in plugin loading). Append-only, mutex-protected.

### Stats output

Every 30 seconds during active IO, the driver logs a stats summary:

```
╔══════════════ STATS (30s) ══════════════╗
║ Writes: 31250 (failed: 0)
║ Clients: starts=1 stops=0
║ Health: failures=0 reconnects=0
║ Format: changes=0 SRC=0
╚══════════════════════════════════════════╝
```

## Troubleshooting

| Symptom | Check |
|---|---|
| No proxy devices appear | Is the Host running? Check `ls /tmp/radioform-devices.txt` |
| `OnStartIO` fails after 15 retries | Shared memory file missing. Check `ls /tmp/radioform-*` |
| Audio dropouts | Check overrun/underrun counts in stats log. May indicate Host is not reading fast enough |
| Driver not loading | Verify install path: `ls /Library/Audio/Plug-Ins/HAL/RadioformDriver.driver`. Restart coreaudiod |
| Stale proxy devices | Host may have crashed without cleanup. Delete `/tmp/radioform-devices.txt` and restart coreaudiod |

## Constants

| Constant | Value | Description |
|---|---|---|
| `DEFAULT_SAMPLE_RATE` | 48000 | Default device sample rate |
| `DEFAULT_CHANNELS` | 2 | Default channel count |
| `HEALTH_CHECK_INTERVAL_SEC` | 3 | Seconds between health checks |
| `HEARTBEAT_INTERVAL_SEC` | 1 | Seconds between heartbeat updates |
| `HEARTBEAT_TIMEOUT_SEC` | 5 | Seconds before declaring host stale |
| `STATS_LOG_INTERVAL_SEC` | 30 | Seconds between stats log output |
| `DEVICE_COOLDOWN_SEC` | 10 | Minimum seconds between device remove and re-add |
| `RF_MAX_CHANNELS` | 8 | Maximum supported channel count |
| `RF_RING_DURATION_MS_DEFAULT` | 40 | Default ring buffer duration |
| `RF_AUDIO_PROTOCOL_VERSION` | `0x00020000` | Shared memory protocol version |
