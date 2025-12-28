# apps/mac/

macOS application targets for Radioform.

## Structure

- **RadioformApp/**: SwiftUI menu bar application (UX + preferences)
- **RadioformAudioHost/**: CoreAudio engine + device management layer

## Architecture Rule

The menu bar app and audio host are **separate processes**. The app communicates with the host via a clean API (XPC or local controller), ensuring that UI crashes never kill audio.

The audio host can run headless as a launch agent, independent of the menu bar UI.
