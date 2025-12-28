# packages/bridge/

Swift/ObjC++ boundary layer for DSP integration.

## Purpose

The **only place ObjC++ exists**. This layer translates Swift-friendly calls into realtime-safe DSP operations.

## Architecture Rule

**Swift never sees a C++ type.**

Swift only interacts with:
- Opaque pointers (e.g., `OpaquePointer` to DSP engine)
- POD structs (plain data types, no methods)
- C ABI functions

## Components

### include/
C headers that define the bridge API:
- `radioform_bridge.h`: C ABI used by Swift
- Opaque handle types
- Parameter structures (POD)
- Function declarations (extern "C")

### src/
ObjC++ implementation:
- `RadioformBridge.mm`: main implementation
- Engine lifecycle (create, destroy, reset)
- Preset application (upload EQ curves)
- Realtime parameter updates (lock-free queues or atomics)

### src/swift/ (optional)
Thin Swift wrapper for ergonomics:
```swift
class EQEngine {
    private let handle: OpaquePointer

    init() { ... }
    func applyPreset(_ preset: Preset) { ... }
    func updateGain(band: Int, db: Float) { ... }
}
```

## Threading Model

- **Non-realtime**: preset upload, engine creation (Swift main thread)
- **Realtime**: parameter updates (audio callback thread, lock-free)

The bridge uses:
- Ring buffers for parameter changes
- Atomics for single-value updates
- **No locks** on realtime path

## Tests

- ABI smoke tests (can create/destroy engine)
- Threading safety (concurrent param updates)
- Memory leaks (create/destroy cycles)
