# Custom Preset Creation Feature

## Overview

Allow users to create and save custom EQ presets directly from the menu bar UI by adjusting the 10-band equalizer and saving their configuration with a custom name.

---

## User Flow

### Step 1: User Adjusts EQ Bands
1. User moves any slider in the `TenBandEQ` component
2. `PresetManager.updateBand()` is called, which calls `applyCurrentState()`
3. The active preset changes to "Custom Preset" mode
4. UI updates:
   - Preset name displays "Custom Preset"
   - Left icon changes from `music.note` to `plus`
   - Icon circle becomes gray (not blue)

### Step 2: User Initiates Save (Click Icon or Double-Click Text)
1. User clicks the `plus` icon OR double-clicks the "Custom Preset" text
2. UI enters editing mode:
   - `Text` component swaps to `TextField` (inline, same styling)
   - TextField is auto-focused with "Custom Preset" selected
   - Left circle icon changes to a rounded "Save" button (disabled/gray initially)
   - Right icon changes from `chevron.down`/`chevron.up` to `xmark` (cancel button)
   - Dropdown list collapses (if expanded)

### Step 3: User Types Preset Name
1. User can type a custom name (max 64 characters)
2. TextField validates input in real-time
3. Reserved name "Custom Preset" is not allowed
4. As user types:
   - If name is valid: "Save" button turns blue with white text (enabled)
   - If name is invalid: "Save" button stays gray (disabled)

### Step 4a: User Saves (Click Save Button or Press Enter)
1. Validation runs:
   - Name is not empty
   - Name is not "Custom Preset"
   - Name ≤ 64 characters
2. Duplicate handling:
   - If name exists in user presets, auto-append number ("My Preset 2")
3. Save process:
   - "Save" button text changes to "Saving..."
   - `EQPreset` is created from `currentBands`
   - `PresetManager.savePreset()` writes JSON to `~/Library/Application Support/Radioform/Presets/`
   - `PresetManager.loadAllPresets()` refreshes the list
4. Success feedback:
   - "Save" button text changes to "Saved"
   - After 0.8 second delay, exit editing mode
5. UI updates:
   - Exit editing mode
   - `currentPreset` is set to the newly saved preset
   - Preset dropdown shows the new preset as active
   - Left element returns to `music.note` icon with blue circle
   - Right element returns to chevron

### Step 4b: User Cancels (Click X Button, Click Away, Press Escape, or Close Popover)
1. Exit editing mode
2. Revert text to "Custom Preset"
3. Left element returns to plus icon with gray circle
4. Right element returns to chevron (up or down based on dropdown state)
5. No preset is saved
6. EQ settings remain applied (not lost)

---

## Files to Modify

### 1. `PresetManager.swift`
**Path:** `apps/mac/RadioformApp/Sources/Services/PresetManager.swift`

#### New Properties
```swift
@Published var isCustomPreset: Bool = false
@Published var customPresetName: String = "Custom Preset"
@Published var isEditingPresetName: Bool = false
@Published var isSavingPreset: Bool = false
@Published var saveSucceeded: Bool = false
```

#### Modified Methods

**`applyCurrentState()`**
- Set `isCustomPreset = true` when bands are modified
- Set `currentPreset = nil`

**`applyPreset(_ preset:)`**
- Set `isCustomPreset = false`
- Reset `customPresetName = "Custom Preset"`

#### New Methods

**`saveCustomPreset(name: String) async throws`**
```swift
func saveCustomPreset(name: String) async throws {
    // 1. Validate name
    // 2. Check for duplicates, auto-append number if needed
    // 3. Build EQPreset from currentBands
    // 4. Call savePreset()
    // 5. Set currentPreset to the new preset
    // 6. Set isCustomPreset = false
}
```

**`generateUniqueName(_ baseName: String) -> String`**
```swift
func generateUniqueName(_ baseName: String) -> String {
    // Check if name exists in userPresets
    // If yes, append " 2", " 3", etc. until unique
    // Return unique name
}
```

**`validatePresetName(_ name: String) -> Bool`**
```swift
func validatePresetName(_ name: String) -> Bool {
    // Return false if empty
    // Return false if > 64 chars
    // Return false if == "Custom Preset"
    // Return true otherwise
}
```

---

### 2. `MenuBarView.swift`
**Path:** `apps/mac/RadioformApp/Sources/Views/MenuBarView.swift`

#### Modify `PresetDropdown` struct

##### New State Properties
```swift
@State private var editingName: String = ""
@FocusState private var isNameFieldFocused: Bool
```

##### Computed Properties
```swift
private var isCustomPreset: Bool {
    presetManager.isCustomPreset && presetManager.isEnabled
}

private var leftIconName: String {
    isCustomPreset ? "plus" : "music.note"
}

private var rightIconName: String {
    if presetManager.saveSucceeded {
        return "checkmark"
    } else if presetManager.isSavingPreset {
        return "arrow.trianglehead.2.clockwise" // or use ProgressView
    } else if presetManager.isEditingPresetName {
        return "square.and.arrow.down"
    } else {
        return isExpanded ? "chevron.up" : "chevron.down"
    }
}

private var displayName: String {
    if presetManager.isEditingPresetName {
        return editingName
    } else if isCustomPreset {
        return "Custom Preset"
    } else {
        return presetManager.currentPreset?.name ?? "Custom Preset"
    }
}
```

##### UI Structure Changes

**Left Icon Button (clickable separately)**
```swift
Button {
    if isCustomPreset {
        startEditing()
    } else {
        isExpanded.toggle()
    }
} label: {
    ZStack {
        Circle()
            .fill(/* color logic */)
            .frame(width: 28, height: 28)
        
        Image(systemName: leftIconName)
            .font(.system(size: 13, weight: .medium))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(/* color logic */)
    }
}
.buttonStyle(.plain)
```

**Text/TextField (conditional)**
```swift
if presetManager.isEditingPresetName {
    TextField("Preset Name", text: $editingName)
        .textFieldStyle(.plain)
        .font(.system(size: 13, weight: .regular))
        .focused($isNameFieldFocused)
        .onSubmit {
            savePreset()
        }
        .onExitCommand {
            cancelEditing()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
} else {
    Button {
        if isCustomPreset {
            startEditing()
        } else {
            isExpanded.toggle()
        }
    } label: {
        Text(displayName)
            .font(.system(size: 13, weight: .regular))
            .foregroundColor(.primary)
    }
    .buttonStyle(.plain)
}
```

**Right Icon Button (clickable separately)**
```swift
Button {
    if presetManager.isEditingPresetName {
        savePreset()
    } else {
        isExpanded.toggle()
    }
} label: {
    Image(systemName: rightIconName)
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(presetManager.saveSucceeded ? .green : .tertiary)
}
.buttonStyle(.plain)
.disabled(presetManager.isSavingPreset)
```

##### Helper Methods

```swift
private func startEditing() {
    editingName = "Custom Preset"
    presetManager.isEditingPresetName = true
    isExpanded = false
    
    // Delay focus to allow UI to update
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        isNameFieldFocused = true
    }
}

private func cancelEditing() {
    presetManager.isEditingPresetName = false
    editingName = ""
    isNameFieldFocused = false
}

private func savePreset() {
    guard presetManager.validatePresetName(editingName) else {
        // Optionally show validation error
        return
    }
    
    Task {
        presetManager.isSavingPreset = true
        
        do {
            try await presetManager.saveCustomPreset(name: editingName)
            presetManager.isSavingPreset = false
            presetManager.saveSucceeded = true
            presetManager.isEditingPresetName = false
            
            // Reset success indicator after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                presetManager.saveSucceeded = false
            }
        } catch {
            presetManager.isSavingPreset = false
            // Handle error (optional: show alert)
        }
    }
}
```

##### Focus Change Handler
```swift
.onChange(of: isNameFieldFocused) { _, focused in
    if !focused && presetManager.isEditingPresetName {
        // User clicked away - cancel editing
        cancelEditing()
    }
}
```

---

### 3. `EQPreset.swift` (Minor Addition)
**Path:** `apps/mac/RadioformApp/Sources/Models/EQPreset.swift`

#### Add Reserved Name Constant
```swift
static let customPresetName = "Custom Preset"
```

---

## JSON Output Format

When a user saves a preset named "My Bass Boost", the following file is created:

**Path:** `~/Library/Application Support/Radioform/Presets/My Bass Boost.json`

```json
{
  "name": "My Bass Boost",
  "bands": [
    {
      "frequency_hz": 32.0,
      "gain_db": 6.0,
      "q_factor": 1.0,
      "filter_type": 0,
      "enabled": true
    },
    {
      "frequency_hz": 64.0,
      "gain_db": 4.0,
      "q_factor": 1.0,
      "filter_type": 0,
      "enabled": true
    },
    // ... 8 more bands
  ],
  "preamp_db": 0.0,
  "limiter_enabled": true,
  "limiter_threshold_db": -1.0
}
```

---

## State Machine

```
┌─────────────────────────────────────────────────────────────────────┐
│                           NORMAL STATE                               │
│  currentPreset != nil, isCustomPreset = false                       │
│  Left: 🔵 music.note, Text: preset name, Right: chevron             │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                │ User adjusts EQ slider
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         CUSTOM PRESET STATE                          │
│  currentPreset = nil, isCustomPreset = true                         │
│  Left: ⚪ plus, Text: "Custom Preset", Right: chevron               │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                │ User clicks plus icon OR double-clicks text
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     EDITING STATE (invalid name)                     │
│  isEditingPresetName = true, name invalid                           │
│  Left: [Save] gray/disabled, TextField, Right: xmark                │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                │ User types valid name
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     EDITING STATE (valid name)                       │
│  isEditingPresetName = true, name valid                             │
│  Left: [Save] blue/enabled, TextField, Right: xmark                 │
└─────────────────────────────────────────────────────────────────────┘
              │                                         │
              │ User clicks xmark / Escape / away       │ User presses Enter / clicks Save
              ▼                                         ▼
┌─────────────────────────┐               ┌─────────────────────────┐
│   CUSTOM PRESET STATE   │               │      SAVING STATE       │
│   (returns to above)    │               │  isSavingPreset = true  │
│   EQ values preserved   │               │  Left: [Saving...]      │
└─────────────────────────┘               └─────────────────────────┘
                                                        │
                                                        │ Save completes
                                                        ▼
                                          ┌─────────────────────────┐
                                          │     SUCCESS STATE       │
                                          │  Left: [Saved]          │
                                          └─────────────────────────┘
                                                        │
                                                        │ After 0.8s delay
                                                        ▼
                                          ┌─────────────────────────┐
                                          │     NORMAL STATE        │
                                          │  (with new preset)      │
                                          └─────────────────────────┘
```

---

## Implementation Order

### Phase 1: State Management
1. Add new `@Published` properties to `PresetManager`
2. Modify `applyCurrentState()` to set `isCustomPreset = true`
3. Modify `applyPreset()` to reset custom preset state
4. Add `validatePresetName()` method
5. Add `generateUniqueName()` method
6. Add `saveCustomPreset()` method

### Phase 2: UI - Basic Custom Preset Display
1. Update `PresetDropdown` to show "Custom Preset" when `isCustomPreset`
2. Change left icon to `plus` for custom preset
3. Update icon circle color (gray for custom, blue for saved)

### Phase 3: UI - Editing Mode
1. Add `@FocusState` and editing state variables
2. Implement conditional `Text` / `TextField` rendering
3. Style `TextField` to match `Text`
4. Implement `startEditing()` method
5. Handle Enter key with `.onSubmit`
6. Handle Escape key with `.onExitCommand`

### Phase 4: UI - Save Flow
1. Implement `savePreset()` method with async/await
2. Update right icon based on state (chevron → save → spinner → checkmark → chevron)
3. Handle focus loss to cancel editing
4. Add success delay timer

### Phase 5: Testing
1. Test slider adjustment → custom preset mode
2. Test click to edit → inline TextField appears
3. Test Enter to save → preset saved, appears in list
4. Test Escape to cancel → reverts to "Custom Preset"
5. Test click away to cancel → reverts to "Custom Preset"
6. Test duplicate name → auto-appends number
7. Test reserved name "Custom Preset" → validation fails
8. Test success indicator → checkmark appears, fades to chevron

---

## Edge Cases

| Scenario | Expected Behavior |
|----------|-------------------|
| User types only spaces | Validation fails, no save |
| User types > 64 chars | Input is truncated or blocked |
| User types "Custom Preset" | Validation fails, no save |
| Duplicate name "Rock" | Saves as "Rock 2" |
| "Rock 2" also exists | Saves as "Rock 3" |
| Save fails (disk error) | Show error, stay in editing mode |
| User closes popover while editing | Cancel editing, no save |
| User toggles EQ off while editing | Cancel editing, EQ turns off |
| User selects another preset while editing | Cancel editing, apply selected preset |

---

## Accessibility

- TextField has proper placeholder text "Preset Name"
- Save button has accessibility label "Save preset"
- Loading state has accessibility label "Saving..."
- Success state has accessibility label "Preset saved"
- Keyboard navigation: Tab moves focus, Enter saves, Escape cancels

---

## Future Enhancements (Out of Scope)

- Edit existing preset names
- Delete presets from UI
- Preset categories/folders
- Import/export presets
- Sync presets via iCloud

