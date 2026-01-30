# Quick Reference: Where to Find Max Volume Range Relationship

This document provides a quick reference to locate information about the max volume range relationship between macOS pre-Radioform and when Radioform is running.

## Primary Documentation

📄 **[docs/VOLUME_CONTROL_ARCHITECTURE.md](VOLUME_CONTROL_ARCHITECTURE.md)**
- Complete technical documentation of volume control architecture
- Explains before/after Radioform behavior
- Includes implementation details, diagrams, and examples

## Code Implementation

📁 **File:** `/packages/host/Sources/RadioformHost/Audio/AudioEngine.swift`

### Key Locations:

1. **Setup Function (Line 111-119):**
   ```swift
   // VOLUME CONTROL ARCHITECTURE:
   // macOS pre-Radioform: User controls physical device volume (0-100%)
   // macOS with Radioform: Physical device locked at 100%, Radioform driver controls volume
   ```
   - Shows where volume control transition happens during initialization

2. **Volume Setting Function (Lines 325-403):**
   ```swift
   /// Sets the physical audio device volume to maximize Radioform's dynamic range control.
   ///
   /// Volume Control Architecture:
   /// - **Before Radioform**: User adjusts physical device volume (0-100%) via System Settings
   /// - **With Radioform**: Physical device locked at 100%, user controls Radioform virtual device
   ```
   - Complete implementation of volume locking
   - Warning system for incompatible devices
   - Verification logic

## Quick Summary

**Before Radioform:**
- User controls physical device volume (0-100%)
- Hardware-level volume control
- Dynamic range may be reduced at low volumes

**With Radioform Running:**
- Physical device locked at 100%
- User controls Radioform virtual device volume (0-100%)
- DSP-based volume control preserves full dynamic range
- Volume control happens in software, not hardware

## Related Files

- `README.md` - Links to technical documentation
- `/packages/driver` - CoreAudio driver implementation
- `/packages/dsp` - DSP processing with volume control
- `/apps/mac` - Menu bar UI for volume control
