# Radioform Onboarding System

## Overview

Radioform includes a first-run onboarding flow that guides users through:
1. **Driver Installation** - Installing the HAL audio driver with admin privileges
2. **Permissions Explanation** - How to configure Radioform as an audio output device
3. **Completion** - Quick tips on using the app

## Architecture

### Key Components

1. **OnboardingState** (`Sources/Models/OnboardingState.swift`)
   - Manages UserDefaults state
   - Tracks onboarding completion
   - Stores driver installation date

2. **OnboardingCoordinator** (`Sources/Onboarding/OnboardingCoordinator.swift`)
   - Manages window lifecycle
   - Handles onboarding completion
   - Launches menu bar UI after completion

3. **OnboardingWindow** (`Sources/Onboarding/OnboardingWindow.swift`)
   - Custom NSWindow for onboarding
   - 600x500 fixed size
   - Floating window level

4. **OnboardingView** (`Sources/Onboarding/OnboardingView.swift`)
   - SwiftUI multi-step wizard
   - Progress indicator
   - Step navigation

5. **DriverInstaller** (`Sources/Services/DriverInstaller.swift`)
   - Driver installation state machine
   - AppleScript-based admin privilege escalation
   - Progress tracking and error handling

### Step Views

1. **DriverInstallStepView** - Driver installation with progress UI
2. **PermissionsStepView** - Audio setup instructions
3. **CompletionStepView** - Success message and quick tips

## User Flow

```
App Launch
    ↓
Check OnboardingState.hasCompleted()
    ↓
┌───[No]──────────────────────┐
│ Onboarding Flow             │
│ 1. Show OnboardingWindow    │
│ 2. Driver Installation      │
│ 3. Permissions Explanation  │
│ 4. Completion               │
│ 5. Mark completed           │
│ 6. Launch menu bar UI       │
└─────────────────────────────┘
    ↓
┌───[Yes]─────────────────────┐
│ Normal Launch               │
│ 1. Launch RadioformHost     │
│ 2. Show menu bar UI         │
└─────────────────────────────┘
```

## Activation Policy Switching

To show windows properly during onboarding:
- **During onboarding**: `.regular` (shows in Dock)
- **After onboarding**: `.accessory` (menu bar only)

This ensures the onboarding window appears correctly in Mission Control and window management.

## UserDefaults Keys

```swift
"hasCompletedOnboarding" -> Bool   // True if user completed onboarding
"driverInstallDate" -> Date        // When driver was installed
"onboardingVersion" -> Int         // Onboarding schema version (for future migrations)
```

## Development Testing

### Reset Onboarding

Three ways to reset onboarding for testing:

#### 1. Command-Line Flag (Recommended)
```bash
swift build
.build/arm64-apple-macosx/debug/RadioformApp --reset-onboarding
```

#### 2. Convenience Script
```bash
./reset_onboarding.sh
```

#### 3. Manual UserDefaults Deletion
```bash
defaults delete com.radioform.menubar hasCompletedOnboarding
defaults delete com.radioform.menubar driverInstallDate
defaults delete com.radioform.menubar onboardingVersion
```

### Run from Xcode

1. Open Package.swift in Xcode
2. Edit scheme → Run → Arguments
3. Add `--reset-onboarding` to "Arguments Passed On Launch"
4. Run normally

### Test Driver Installation

The driver installer will:
1. Look for `RadioformDriver.driver` in app resources
2. Copy to `/Library/Audio/Plug-Ins/HAL/` (requires sudo)
3. Set permissions (`chown root:wheel`, `chmod 755`)
4. Restart `coreaudiod`
5. Verify driver is loaded via `system_profiler`

**Note:** For development testing, you'll need to build the driver first:
```bash
cd packages/driver
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
cmake --build .
```

Then copy it to app resources or the script will fail.

## Implementation Details

### Driver Installation Process

```swift
1. notStarted
2. checkingExisting      // Check if already loaded
3. copying               // Copy driver bundle
4. settingPermissions    // chown + chmod
5. restartingAudio       // killall coreaudiod
6. verifying             // Check with system_profiler
7. complete              // Success!
```

### Error Handling

**User Cancels Admin Prompt:**
- State: `.failed("User canceled")`
- Action: Show retry button

**Copy Fails:**
- State: `.failed(errorMessage)`
- Action: Show error details, retry option

**Verification Fails:**
- State: `.failed("Driver not loaded")`
- Action: Show troubleshooting steps

### Auto-Advancement

The driver installation step automatically continues to the next step 1 second after successful installation.

## File Structure

```
apps/mac/RadioformApp/Sources/
├── App/
│   └── RadioformApp.swift          # Main app, command-line flag handling
├── Models/
│   └── OnboardingState.swift       # UserDefaults state management
├── Onboarding/
│   ├── OnboardingCoordinator.swift # Window lifecycle
│   ├── OnboardingWindow.swift      # NSWindow subclass
│   ├── OnboardingView.swift        # Main SwiftUI view
│   └── Steps/
│       ├── DriverInstallStepView.swift
│       ├── PermissionsStepView.swift
│       └── CompletionStepView.swift
└── Services/
    └── DriverInstaller.swift       # Driver installation logic
```

## Known Limitations

1. **Driver Bundle Not Embedded Yet:** The build system doesn't yet copy the driver to app resources. This will be addressed in Phase 5 (Build System).

2. **No DMG Packaging:** The onboarding works in development but hasn't been packaged for distribution yet.

3. **Swift 6 Warnings:** The `DriverInstaller` has Sendable warnings due to `NSAppleScript` not conforming to Sendable. These are just warnings and don't affect functionality.

## Next Steps

- [ ] Phase 5: Build system to embed driver and host in app bundle
- [ ] Phase 6: Code signing with entitlements
- [ ] Phase 7: DMG packaging
- [ ] Phase 8: Notarization

## Testing Checklist

- [x] Build compiles successfully
- [ ] Onboarding shows on first launch
- [ ] Driver installation works (requires built driver)
- [ ] Progress indicator updates correctly
- [ ] Error handling works (test with missing driver)
- [ ] Permissions step shows correctly
- [ ] Completion step shows correctly
- [ ] Menu bar UI launches after completion
- [ ] `--reset-onboarding` flag works
- [ ] Second launch skips onboarding
- [ ] Activation policy switches correctly
