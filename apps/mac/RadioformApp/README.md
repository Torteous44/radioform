# RadioformApp

SwiftUI menu bar application for Radioform.

## Purpose

User interface for system EQ control. Contains no realtime audio code.

## Features

- 10-band parametric EQ with frequency response visualization
- Preset management (8 bundled presets, JSON import/export)
- Device selection for Radioform proxy outputs
- Driver installation onboarding flow
- Menu bar popover interface

## Architecture

Communicates with RadioformHost via file-based IPC (`/tmp/radioform-preset.json`). The app can quit and relaunch without interrupting audio processing.
