# tools/scripts/

Developer ergonomics scripts for local development.

## Scripts to Implement

### bootstrap.sh
First-time setup:
- Install Homebrew dependencies (CMake, SwiftFormat, etc.)
- Initialize and update Git submodules (`lsp-dsp-lib`)
- Generate Xcode projects or build directories
- Verify toolchain versions

### build_driver.sh
Build the AudioDriverKit driver:
- Clean previous builds
- Build `RadioformDriver` target
- Code sign with dev certificate
- Report build status

### build_mac.sh
Build macOS app targets:
- Build `RadioformApp` (menu bar app)
- Build `RadioformAudioHost` (audio engine)
- Code sign both
- Optional: create `.app` bundle

### run_host.sh
Run the audio host engine:
- Launch `RadioformAudioHost` in foreground
- Attach to logs
- Useful for debugging without full app

### format.sh
Code formatting:
- Run SwiftFormat on Swift code
- Run clang-format on C++/ObjC++ code
- Check for formatting violations (CI mode)

### codesign.sh
Code signing helpers:
- Sign with development certificate
- Verify entitlements
- Check signature validity

### package_release.sh
Release packaging:
- Build release configuration
- Code sign for distribution
- Notarize with Apple
- Create DMG or PKG installer
- Generate checksums (SHA-256)
- Upload to GitHub releases or CDN

## Usage

All scripts should be runnable from the repository root:
```bash
./tools/scripts/bootstrap.sh
./tools/scripts/build_mac.sh
./tools/scripts/run_host.sh
```

Scripts should be **idempotent** where possible (safe to run multiple times).
