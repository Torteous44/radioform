# Radioform HAL Driver

A CoreAudio HAL (Hardware Abstraction Layer) plugin for macOS that creates virtual proxy output devices. When an app sends audio to a proxy device, the driver writes it into shared memory. The host process reads from shared memory, runs DSP, and renders to the real hardware device.

The driver runs inside `coreaudiod` (not as a standalone process). When installed at `/Library/Audio/Plug-Ins/HAL/RadioformDriver.driver`, macOS loads it as a system audio plugin.

## How it works

```
Application audio
    |
    v
+--------------------------+
| macOS CoreAudio (HAL)    |
| routes output to proxy   |
+-----------+--------------+
            |
            v
+--------------------------+
| RadioformDriver          |
| (this plugin)            |
|                          |
| OnWriteMixedOutput()     |
| - format conversion      |
| - sample rate conversion |
| - ring buffer write      |
+-----------+--------------+
            | shared memory (mmap)
            | /tmp/radioform-<uid>
            v
+--------------------------+
| RadioformHost            |
| - ring buffer read       |
| - DSP processing         |
| - hardware output        |
+--------------------------+
```

## Files

| File | Purpose |
|---|---|
| `src/Plugin.cpp` | Driver runtime logic: plugin factory, device creation/removal, IO handling, health checks |
| `include/RFSharedAudio.h` | Shared memory protocol and ring buffer helpers |
| `CMakeLists.txt` | Build config for `RadioformDriver.driver` |
| `Info.plist` | Bundle metadata, factory UUID, bundle identifier (`com.radioform.driver`) |
| `install.sh` | Installs `build/RadioformDriver.driver` to `/Library/Audio/Plug-Ins/HAL/` |
| `uninstall.sh` | Removes the installed driver bundle |
| `VERSION` | Driver version (`2.0.8`) |
| `vendor/libASPL/` | Third-party C++ wrapper around CoreAudio HAL plugin APIs |

`include/RFSharedAudio.h` is intentionally kept in sync with:
`packages/host/Sources/CRadioformAudio/include/RFSharedAudio.h`

## Entry point

```cpp
extern "C" void* RadioformDriverPluginFactory(CFAllocatorRef allocator, CFUUIDRef typeUUID)
```

If `typeUUID` matches `kAudioServerPlugInTypeUUID`, this function lazily creates global driver state and returns the plugin reference. The factory UUID is `B3F04000-8F04-4F84-A72E-B2D4F8E6F1DA` (declared in `Info.plist`).

## Device lifecycle

The driver does not hardcode proxy devices. It reconciles desired devices from a host-written control file.

### Control file: `/tmp/radioform-devices.txt`

Format per line:

```
DeviceName|DeviceUID
```

`MonitorControlFile()` calls `SyncDevices()` every ~1 second (10x 100ms sleeps).

`SyncDevices()` behavior:

- Add proxy device when UID exists in control file, heartbeat for that UID is fresh, and UID is not in cooldown.
- Remove proxy device when UID is no longer desired (missing from file or heartbeat stale).
- Enforce a 10-second cooldown (`DEVICE_COOLDOWN_SEC`) after removal to prevent rapid add/remove cycling.

### Proxy device creation

`CreateProxyDevice()` creates one output-only proxy device with:

- Name: `"<OriginalName> (Radioform)"`
- UID: `"<OriginalUID>-radioform"`
- Manufacturer: `"Radioform"`
- Default format: 48 kHz, 2 channels
- Mixing enabled
- Stream controls via `AddStreamWithControlsAsync(aspl::Direction::Output)`
- IO/control callbacks handled by `UniversalAudioHandler`

## Audio path

### OnStartIO

When the first client starts IO, the handler:

1. Opens `/tmp/radioform-<sanitized-uid>`
2. Maps shared memory with `PROT_READ | PROT_WRITE` and `MAP_SHARED`
3. Validates protocol version, sample rate, and channel count
4. Sets `driver_connected = 1`
5. Pre-allocates conversion buffers (`4096 * RF_MAX_CHANNELS` frames)
6. Prefills half the ring with silence to reduce cold-start underruns
7. Retries up to 15 times with exponential backoff (30ms base, capped growth) if connection is not ready

IO clients are reference-counted; `OnStopIO` disconnects shared memory when the last client stops.

### OnWriteMixedOutput

This callback runs on the audio IO thread for each buffer. It:

1. Runs a health check every 3 seconds
2. Updates `driver_heartbeat` roughly every 1 second
3. Reads current stream `AudioStreamBasicDescription`
4. Rebuilds conversion/resampler state on format changes (sample rate/channel count)
5. Converts input to interleaved float32
6. Applies linear-interpolation sample-rate conversion when needed
7. Writes frames with `rf_ring_write()`
8. Logs periodic stats every 30 seconds

Implemented input conversion paths in `ConvertToFloat32Interleaved()`:

- Float32 (interleaved and non-interleaved)
- Signed Int16
- Signed Int24 (packed 3-byte)
- Signed Int32

## Shared memory layout (`RFSharedAudio`)

Defined in `include/RFSharedAudio.h`.
In this build, `sizeof(RFSharedAudio)` is 264 bytes, and `audio_data[]` begins at offset 264.

### Header fields

| Offset | Field | Type | Description |
|---|---|---|---|
| 0 | `protocol_version` | `uint32_t` | `0x00020000` |
| 4 | `header_size` | `uint32_t` | `sizeof(RFSharedAudio)` |
| 8 | `sample_rate` | `uint32_t` | 44100, 48000, 88200, 96000, 176400, 192000 |
| 12 | `channels` | `uint32_t` | 1-8 |
| 16 | `format` | `uint32_t` | `RFAudioFormat` enum |
| 20 | `bytes_per_sample` | `uint32_t` | Derived from format |
| 24 | `bytes_per_frame` | `uint32_t` | `bytes_per_sample * channels` |
| 28 | `ring_capacity_frames` | `uint32_t` | `sample_rate * duration_ms / 1000` |
| 32 | `ring_duration_ms` | `uint32_t` | Default 100 (allowed 20-100) |
| 36 | `driver_capabilities` | `uint32_t` | `RF_CAP_*` bitmask |
| 40 | `host_capabilities` | `uint32_t` | `RF_CAP_*` bitmask |
| 48 | `creation_timestamp` | `uint64_t` | Unix epoch seconds |
| 56 | `format_change_counter` | `atomic uint64_t` | Format-change counter |
| 64 | `write_index` | `atomic uint64_t` | Producer frame index |
| 72 | `read_index` | `atomic uint64_t` | Consumer frame index |
| 80 | `total_frames_written` | `atomic uint64_t` | Cumulative writes |
| 88 | `total_frames_read` | `atomic uint64_t` | Cumulative reads |
| 96 | `overrun_count` | `atomic uint64_t` | Overflow events |
| 104 | `underrun_count` | `atomic uint64_t` | Underrun events |
| 112 | `format_mismatch_count` | `atomic uint64_t` | Negotiation failures |
| 120 | `driver_connected` | `atomic uint32_t` | Driver connection flag |
| 124 | `host_connected` | `atomic uint32_t` | Host connection flag |
| 128 | `driver_heartbeat` | `atomic uint64_t` | Driver heartbeat |
| 136 | `host_heartbeat` | `atomic uint64_t` | Host heartbeat |
| 144-263 | `_reserved` | `uint8_t[120]` | Future expansion |
| 264+ | `audio_data[]` | `uint8_t[]` | `ring_capacity_frames * bytes_per_frame` bytes |

### Total mapped size

```
sizeof(RFSharedAudio) + (ring_capacity_frames * channels * bytes_per_sample)
```

Example at 48 kHz, 2 channels, float32, 100 ms (in this build):
`264 + (4800 * 2 * 4) = 38664` bytes.

### Ring buffer behavior

Single producer (driver) and single consumer (host), with monotonically increasing 64-bit indices.

- Overflow (`used + write > capacity`): advance `read_index` and increment `overrun_count`
- Underrun on host read: host emits silence and increments `underrun_count`

`rf_ring_write()` accepts float32 input and stores samples in negotiated shared format. `rf_ring_read()` outputs float32 for host-side processing.

## Health monitoring

During active IO, health checks run every 3 seconds:

| Check | Failure condition |
|---|---|
| File existence | Shared memory file missing |
| Host connection | `host_connected == 0` |
| Host heartbeat | No `host_heartbeat` change for >= 5 seconds |
| Ring integrity | `write_index < read_index` |
| Ring capacity | `write_index - read_index > ring_capacity_frames` |

On failure, the driver attempts recovery by disconnecting, reopening shared memory, and re-validating.

## Heartbeat protocol

- Driver calls `rf_update_driver_heartbeat()` during `OnWriteMixedOutput` (~1s cadence).
- Host calls `rf_update_host_heartbeat()` on a timer (`DispatchSourceTimer` in host code).

A host heartbeat older than 5 seconds is treated as stale.

## Building

Requirements:

- macOS (HAL driver target)
- CMake >= 3.20
- C++17 toolchain

```sh
cd packages/driver
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

Output bundle: `build/RadioformDriver.driver`

Debug build (AddressSanitizer enabled by project flags):

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

Notes:

- `install.sh` expects `./build/RadioformDriver.driver` to exist.
- Script prompts for admin rights (`sudo`) internally for copy/ownership changes.
- Install target: `/Library/Audio/Plug-Ins/HAL/RadioformDriver.driver`
- Restarting `coreaudiod` is required for load/unload and interrupts audio briefly.

## Uninstalling

```sh
cd packages/driver
./uninstall.sh
sudo killall coreaudiod
```

## Logging

- `os_log` subsystem: `com.radioform.driver`
- Fallback file log: `/tmp/radioform-driver-debug.log`

Example unified log query:

```sh
log show --predicate 'subsystem == "com.radioform.driver"' --last 5m
```

## Troubleshooting

| Symptom | Check |
|---|---|
| No proxy devices appear | Confirm host is running and `/tmp/radioform-devices.txt` exists |
| `OnStartIO` fails after retries | Confirm shared memory files exist: `ls /tmp/radioform-*` |
| Audio dropouts | Inspect overrun/underrun stats in logs |
| Driver not loading | Verify install path and restart `coreaudiod` |
| Stale proxy devices | Remove stale `/tmp/radioform-devices.txt` entry source and restart host/`coreaudiod` |

## Constants

| Constant | Value |
|---|---|
| `DEFAULT_SAMPLE_RATE` | 48000 |
| `DEFAULT_CHANNELS` | 2 |
| `HEALTH_CHECK_INTERVAL_SEC` | 3 |
| `HEARTBEAT_INTERVAL_SEC` | 1 |
| `HEARTBEAT_TIMEOUT_SEC` | 5 |
| `STATS_LOG_INTERVAL_SEC` | 30 |
| `DEVICE_COOLDOWN_SEC` | 10 |
| `RF_MAX_CHANNELS` | 8 |
| `RF_RING_DURATION_MS_DEFAULT` | 100 |
| `RF_AUDIO_PROTOCOL_VERSION` | `0x00020000` |
