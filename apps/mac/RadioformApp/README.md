# RadioformApp

SwiftUI menu bar application for Radioform.

## Purpose

User experience and policy layer. **Contains no realtime audio code.**

## Features to Implement

### Onboarding
- Driver installation UI
- "Set output once" flow
- Health check screen (audio flowing confirmation)

### Presets
- Preset list and editor UI
- Import/export (JSON format)
- Quick-switch menu

### Auto-Preset Engine
- Metadata-based preset selection (app, genre, device)
- Integration toggles (MusicKit, Shazam, etc.)

### Settings
- Output-follow behavior toggles
- Diagnostics mode (safe mode, bypass EQ)
- Advanced options

### Diagnostics
- System audio status display
- "Generate diagnostics bundle" feature
- Logs and troubleshooting info

## Architecture Note

This app talks to RadioformAudioHost via XPC or a clean API boundary. It does not embed the audio engine or touch realtime code paths.
