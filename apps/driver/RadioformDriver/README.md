# RadioformDriver

AudioDriverKit virtual output device.

## Purpose

Minimal, stable virtual audio device that shows up in macOS Sound settings.

## Design Philosophy

**Keep this target tiny.** Every extra feature here multiplies "it works on my Mac but not on theirs."

## Components to Implement

### Driver Core
- Driver entry points (AudioDriverKit lifecycle)
- Device and stream objects
- Buffer management (zero-copy where possible)

### Format Support
- Supported sample rates (44.1k, 48k, 88.2k, 96k, etc.)
- Channel layouts (stereo, 5.1, 7.1 if needed)
- Format negotiation logic

### Transport
- Frame delivery to audio host
- Control/status communication
- Shared memory or IOUserClient-style patterns

### Installation
- Packaging scripts
- Versioning and upgrade logic
- Entitlements and code signing configuration

### Tests
- Format negotiation correctness
- Basic buffer flow validation
- Device lifecycle tests

## Critical Rules

- No DSP in this layer
- No policy decisions
- No UI interaction
- Fail safely and loudly (never silently break audio)
