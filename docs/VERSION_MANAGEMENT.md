# Version Management

## Overview

Radioform uses **decoupled versioning** for the app and driver components to avoid unnecessary driver updates.

## Version Strategy

- **App Version**: Bumps with every release (UI, features, bug fixes)
- **Driver Version**: Only bumps when driver code changes
- **Host Version**: Follows app version (can be changed if needed)

## How It Works

### Automatic Detection (CI/CD)

When you create a release tag (e.g., `v1.0.35`), the GitHub Actions workflow:

1. Checks if driver code changed since the last tag
2. **If driver changed**: Updates all components to the new version
3. **If driver unchanged**: Updates only the app version, driver stays at current version

Monitored driver files:
- `packages/driver/src/**`
- `packages/driver/include/**`
- `packages/driver/CMakeLists.txt`

### Manual Version Updates

Update specific components using the `update_versions.sh` script:

```bash
# Update all components to same version
./tools/update_versions.sh 1.0.35

# Update only app
./tools/update_versions.sh 1.0.35 --app-only

# Update only driver
./tools/update_versions.sh 1.0.35 --driver-only

# Update only host
./tools/update_versions.sh 1.0.35 --host-only
```

### Version Files

**App Version:**
- `apps/mac/RadioformApp/Info.plist` (CFBundleShortVersionString)

**Driver Version:**
- `packages/driver/Info.plist` (CFBundleShortVersionString)
- `packages/driver/CMakeLists.txt` (project VERSION)
- `packages/driver/VERSION` (single source of truth)

**Host Version:**
- `packages/host/Info.plist` (CFBundleShortVersionString)

## Update Behavior

### User Experience

**Scenario 1: App-only update**
- User updates app from v1.0.30 → v1.0.35
- Driver version unchanged (still v1.0.15)
- ✅ No driver update prompt

**Scenario 2: App + Driver update**
- User updates app from v1.0.30 → v1.0.35
- Driver version changed v1.0.15 → v1.0.20
- ⚠️ Driver update prompt shows: 1.0.15 → 1.0.20

### Version Comparison Logic

The app uses **semantic versioning comparison** (VersionManager.swift:77):
```swift
// Only prompts if bundled > installed
return isVersionOlder(installedVersion, than: bundledVersion)
```

This prevents prompts when:
- Installed driver is same version as bundled
- Installed driver is newer than bundled (dev scenario)

## Best Practices

1. **Normal app changes**: Just create a release tag, let CI handle it
2. **Driver changes**: Make driver changes, create tag, CI will detect and bump driver version
3. **Force driver bump**: Manually run `./tools/update_versions.sh X.Y.Z --driver-only` before tagging
4. **Check versions**: `cat packages/driver/VERSION` and check app Info.plist

## Example Workflow

```bash
# Make app changes (UI, Swift code)
git add apps/mac/RadioformApp
git commit -m "Add new settings panel"
git tag v1.0.36
git push origin v1.0.36

# CI runs → detects no driver changes → only bumps app to 1.0.36
# Driver stays at 1.0.31 → no user prompt on update ✅
```

```bash
# Make driver changes (C++ audio code)
git add packages/driver/src
git commit -m "Improve audio buffer handling"
git tag v1.0.37
git push origin v1.0.37

# CI runs → detects driver changes → bumps both app and driver to 1.0.37
# Users get prompted: "Driver update 1.0.31 → 1.0.37" ⚠️
```

## Troubleshooting

**Problem**: Driver version not updating despite code changes

**Solution**: CI checks for changes since last tag. Ensure:
- Changes are in monitored paths (src/, include/, CMakeLists.txt)
- Last tag exists in repo (`git describe --tags --abbrev=0`)
- Or manually update: `./tools/update_versions.sh X.Y.Z --driver-only`

**Problem**: False driver update prompts

**Solution**: This was fixed by semantic version comparison. If still occurring:
- Check installed version: `/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" /Library/Audio/Plug-Ins/HAL/RadioformDriver.driver/Contents/Info.plist`
- Check bundled version: `cat packages/driver/VERSION`
- Ensure versions are in sync
