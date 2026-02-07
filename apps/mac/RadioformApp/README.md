# RadioformApp

SwiftUI menu bar application for Radioform.

## Purpose

User interface for system EQ control. Contains no realtime audio code.

## Features

- 10-band parametric EQ
- Preset management (bundled presets + custom presets saved to JSON on disk)
- Driver installation onboarding flow
- Menu bar popover interface
- Advanced per-band controls: frequency, Q, filter type

## Architecture

Communicates with RadioformHost via file-based IPC (`~/Library/Application Support/Radioform/preset.json`). The app can quit and relaunch without interrupting audio processing.
