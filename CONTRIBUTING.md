# Contributing to Radioform

Thanks for helping improve Radioform. This guide covers how to set up a development environment, run the project, and open a pull request.

## Requirements

- macOS 13.0 or later
- Xcode 15+
- Swift 5.9+
- CMake 3.20+
- Homebrew for dependency installation

## Repository Structure

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

## First-Time Setup

```bash
git clone https://github.com/torteous44/radioform.git
cd radioform

# Initialize submodules
git submodule update --init --recursive

# Install dependencies (requires Homebrew)
make install-deps
```

## Development Commands

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

## Commit Message Format

Use [Conventional Commits](https://www.conventionalcommits.org/) for automatic changelog generation:

```
<type>: <description>

[optional body]
```

Types:
- `feat:` New feature
- `fix:` Bug fix
- `perf:` Performance improvement
- `refactor:` Code refactoring
- `docs:` Documentation changes
- `test:` Test additions/changes
- `build:` Build system changes
- `ci:` CI/CD changes
- `chore:` Maintenance tasks

Examples:
```
feat: add preset export functionality
fix: resolve device switching crash on USB disconnect
perf: optimize ring buffer read operations
docs: update installation instructions
```

## Opening a Pull Request

1. Fork the repository and create a branch for your change
2. Make focused commits with conventional commit messages
3. Run relevant `make` commands to verify builds and tests
4. Ensure new code includes appropriate documentation where non-obvious
5. Open a pull request with:
   - Concise summary of the change and motivation
   - Notes on testing performed
   - Any known limitations or follow-up work
6. Respond to feedback; keep the PR scope tight to speed up review

## Reporting Issues

If you find a bug or have a feature request, open an issue describing:

- Expected behavior
- Actual behavior
- Steps to reproduce
- Environment details (macOS version, Xcode version)
