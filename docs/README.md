# docs/

User and developer documentation for Radioform.

## Purpose

Detailed guides that don't belong in the main README but are essential for users and contributors.

## Documents to Create

### architecture.md
End-to-end system design:
- Diagram: driver → host → dsp → output
- State machine documentation (stopped/starting/running/recovering)
- Threading model (what runs realtime vs non-realtime)
- Recovery and error handling strategies
- Device switching logic

### driver-install.md
Driver installation guide:
- What the installer does
- Why admin password is required
- System extension approval (macOS Security & Privacy)
- Uninstall instructions (clean removal)
- Troubleshooting installation failures

### contributing.md
Developer contribution guide:
- Local build setup
- Coding standards:
  - No allocations in audio callback
  - Lock-free realtime code
  - Error handling patterns
- How to add a new DSP band
- Preset schema changes
- Pull request guidelines
- Testing requirements

### troubleshooting.md
Common issues and solutions:
- No audio output
- AirPods not switching properly
- Permission errors
- High CPU usage
- Conflicts with other audio software

### preset-format.md
Preset file format specification:
- JSON schema
- Parameter ranges and units
- Import/export behavior
- Versioning strategy
