# packages/bridge/include/

C headers defining the Swift ↔ DSP bridge API.

## Purpose

Provides a **pure C ABI** that Swift can safely import and use.

## Files to Implement

### radioform_bridge.h
Main bridge API:
```c
// Opaque handle to DSP engine
typedef struct radioform_engine* radioform_engine_t;

// Lifecycle
radioform_engine_t radioform_engine_create(uint32_t sample_rate);
void radioform_engine_destroy(radioform_engine_t engine);
void radioform_engine_reset(radioform_engine_t engine);

// Preset management
int radioform_engine_apply_preset(radioform_engine_t engine, const radioform_preset_t* preset);

// Realtime parameter updates
void radioform_engine_update_gain(radioform_engine_t engine, uint32_t band, float db);
void radioform_engine_set_bypass(radioform_engine_t engine, bool bypass);

// Audio processing
void radioform_engine_process(
    radioform_engine_t engine,
    const float* input_left,
    const float* input_right,
    float* output_left,
    float* output_right,
    uint32_t frames
);
```

### radioform_types_bridge.h
POD types for presets and parameters:
```c
typedef struct {
    float frequency_hz;
    float gain_db;
    float q_factor;
    uint32_t filter_type; // peak, shelf, etc.
} radioform_band_t;

typedef struct {
    radioform_band_t bands[10];
    uint32_t num_bands;
    float preamp_db;
    bool limiter_enabled;
} radioform_preset_t;
```

## Design Rules

- **extern "C"** for all functions
- **No C++ types** (no `std::`, no templates, no classes)
- **Explicit sizes**: use fixed arrays or explicit count parameters
- **Opaque pointers**: hide implementation details from Swift

This is the contract that Swift imports. The implementation (in `../src/`) can use modern C++ internally.
