# apps/mac/

macOS application targets for Radioform.

## Structure

- **RadioformApp/**: SwiftUI menu bar application (UX + preferences)

## Architecture

The menu bar app and audio host are **separate processes**. The app communicates with the host via a JSON control file at `~/Library/Application Support/Radioform/preset.json`, ensuring that UI crashes never kill audio.

The audio host (`packages/host/`) is a separate headless process launched by the app; it runs independently of the UI while the app is open.
