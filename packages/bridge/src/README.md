# packages/bridge/src/

ObjC++ implementation of the Swift ↔ DSP bridge.

## Purpose

Implements the C ABI defined in `../include/radioform_bridge.h` by wrapping the C++ DSP engine from `packages/dsp`.

## Files to Implement

### RadioformBridge.mm
Main bridge implementation:
- Implements all C ABI functions
- Manages DSP engine lifetime
- Handles threading and synchronization

### ParameterQueue.hpp
Lock-free parameter update queue:
- Ring buffer for preset changes
- Atomic single-value updates (bypass, gain)
- Consumed by audio callback without blocking

### EngineWrapper.cpp (optional)
Thin C++ wrapper around `radioform_dsp.h` if needed for ergonomics.

## Threading Model

This code runs in **two contexts**:

1. **Non-realtime** (Swift main thread):
   - `radioform_engine_create/destroy`
   - `radioform_engine_apply_preset` (uploads preset to queue)

2. **Realtime** (audio callback):
   - `radioform_engine_process` (pulls params from queue, runs DSP)
   - `radioform_engine_update_gain` (atomic or queued update)

## Safety Rules

- **No allocations** on the realtime path
- **No locks** in `radioform_engine_process`
- **No Objective-C** message sends in audio callback
- **Memory order** guarantees for atomics (`std::memory_order_acquire/release`)

## Error Handling

- Return codes for non-realtime functions (0 = success)
- Graceful degradation on realtime path (bypass on error)
- Never crash or throw in audio callback
