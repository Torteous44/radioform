# Radioform

**Radioform** is a free, open-source, macOS-native system equalizer designed around one simple promise: **audio that just works**.

## Quick Start for Developers

### First Time Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/radioform.git
cd radioform

# Initialize submodules
git submodule update --init --recursive

# Install dependencies (requires Homebrew)
make install-deps

# Start with full onboarding flow
make dev
```

### Development Commands

```bash
# Start from scratch (reset onboarding + build + run)
make dev

# Run app normally (keeps existing state)
make run

# Build all components
make build

# Create .app bundle
make bundle

# Clean build artifacts
make clean

# Reset onboarding and uninstall driver
make reset

# Run DSP tests
make test

# See all available commands
make help
```

## Project Structure

```
radioform/
├── apps/
│   └── mac/RadioformApp/     # macOS menu bar app (Swift/SwiftUI)
├── packages/
│   ├── dsp/                  # DSP library (C++17)
│   ├── driver/               # HAL audio driver (C++17)
│   └── host/                 # Audio processing host (Swift)
└── tools/                    # Build scripts and utilities
```

## Requirements

- macOS 13.0 or later
- Xcode 15+
- Swift 5.9+
- CMake 3.20+

## Architecture

Radioform consists of four main components:

1. **DSP Library** (`packages/dsp`) - Core audio processing with parametric EQ
2. **HAL Driver** (`packages/driver`) - CoreAudio HAL plugin using libASPL
3. **Audio Host** (`packages/host`) - Swift process managing audio routing and DSP
4. **Menu Bar App** (`apps/mac/RadioformApp`) - SwiftUI interface with onboarding

## Building from Source

### Full Release Build

```bash
./tools/build_release.sh
```

This builds all components and creates a distribution-ready `.app` bundle at `dist/Radioform.app`.

### Component-by-Component

```bash
# DSP Library
cd packages/dsp
mkdir -p build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
cmake --build .

# HAL Driver
cd packages/driver
mkdir -p build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
cmake --build .

# Audio Host
cd packages/host
swift build -c release

# Menu Bar App
cd apps/mac/RadioformApp
swift build -c release
```

## Testing Onboarding Flow

```bash
# Reset everything and test onboarding from scratch
make dev

# Or manually:
make reset      # Uninstall driver + reset onboarding state
make build      # Build all components
make bundle     # Create .app bundle
open dist/Radioform.app
```

## Troubleshooting

### Driver not loading
- Run `make reset` to uninstall and try again
- Check driver is installed: `ls -la /Library/Audio/Plug-Ins/HAL/RadioformDriver.driver`
- Restart audio: `sudo killall coreaudiod`

### Build errors
- Clean and rebuild: `make rebuild`
- Update submodules: `git submodule update --init --recursive`
- Check dependencies: `make install-deps`

## License

[Add your license here]
