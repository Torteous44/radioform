# DSP Engine Technical Reference

Quick reference for future work on the audio pipeline.

## Engine Constructor Defaults (`engine.cpp:63-98`)

```
limiter_enabled = true (default ON)
preamp = 1.0 (0 dB)
limiter threshold = -0.1 dB
DC blocker = 5 Hz HPF
coeff transition = ~10ms
```

## Processing Order (per sample, `engine.cpp:205-238`)

1. Deinterleave stereo
2. Apply preamp gain (smoothed)
3. Process through enabled EQ bands (biquad cascade)
4. DC blocker (stereo 5Hz HPF)
5. Soft limiter (if enabled)
6. Peak detection
7. Interleave output

## Preset Validation Ranges (`preset.cpp:43-94`)

| Parameter | Min | Max |
|---|---|---|
| Frequency | 20 Hz | 20,000 Hz |
| Band gain | -12 dB | +12 dB |
| Q factor | 0.1 | 10.0 |
| Preamp | -12 dB | +12 dB |
| Limiter threshold | -6 dB | 0 dB |

## Biquad Filter Types (`biquad.h`)

- 0: RADIOFORM_FILTER_PEAK (parametric peaking EQ)
- 1: RADIOFORM_FILTER_LOW_SHELF
- 2: RADIOFORM_FILTER_HIGH_SHELF
- 3: RADIOFORM_FILTER_LOW_PASS
- 4: RADIOFORM_FILTER_HIGH_PASS
- 5: RADIOFORM_FILTER_NOTCH
- 6: RADIOFORM_FILTER_BAND_PASS

Uses RBJ cookbook formulas with enhanced bandwidth prewarping for peak filters.

## Soft Limiter Math (`limiter.h`)

```
threshold_linear = 10^(threshold_db / 20)
knee_start = threshold_linear * 0.8

Below knee_start: passthrough
Above knee_start: rational function soft clip
  scaled = (|input| - knee_start) / (threshold - knee_start)
  limited = knee_start + (threshold - knee_start) * (scaled / (1 + scaled))
```

## Key C API Functions

| Function | Realtime-safe | Purpose |
|---|---|---|
| `radioform_dsp_create()` | No | Create engine |
| `radioform_dsp_destroy()` | No | Destroy engine |
| `radioform_dsp_apply_preset()` | No | Load full preset |
| `radioform_dsp_process_interleaved()` | Yes | Process audio (interleaved) |
| `radioform_dsp_process_planar()` | Yes | Process audio (planar) |
| `radioform_dsp_update_band_gain()` | Yes | Update single band gain |
| `radioform_dsp_update_preamp()` | Yes | Update preamp gain |
| `radioform_dsp_set_bypass()` | Yes | Toggle bypass |
| `radioform_dsp_preset_init_flat()` | No | Init flat preset |

## Driver Architecture (`Plugin.cpp`)

- ASPL-based HAL plugin with `EnableMixing = true`
- `OnWriteMixedOutput` receives mixed, volume-applied audio from CoreAudio
- Converts any format to float32 interleaved
- Writes to shared memory ring buffer (`RFSharedAudio`)
- Simple linear resampler for sample rate mismatches
- No volume/gain processing in driver — pure passthrough

## Host Architecture

- `AudioEngine.swift` — binds to physical device, locks volume to 100%
- `AudioRenderer.swift` — render callback, reads ring buffer, calls DSP
- `DSPProcessor.swift` — Swift wrapper for C DSP engine
- `SharedMemoryManager` — manages shared memory regions
- `ProxyDeviceManager` — tracks active virtual device
