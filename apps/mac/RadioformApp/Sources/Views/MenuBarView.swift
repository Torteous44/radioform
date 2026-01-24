import SwiftUI

// Cache font lookup once at launch
private let radioformFont: Font = {
    let size: CGFloat = 22
    let possibleNames = [
        "SignPainterHouseScript",
        "SignPainter-HouseScript",
        "SignPainter House Script",
        "SignPainter"
    ]
    for name in possibleNames {
        if NSFont(name: name, size: size) != nil {
            return .custom(name, size: size)
        }
    }
    return .system(size: size, weight: .bold)
}()

struct MenuBarView: View {
    @ObservedObject private var presetManager = PresetManager.shared
    @State private var showPresets = false

    var body: some View {
        VStack(spacing: 0) {
                // Header with toggle only (no title)
                HStack {
                    Text("Radioform")
                        .font(radioformFont)
                        
                    Spacer()

                    Toggle(
                        "",
                        isOn: Binding(
                            get: { presetManager.isEnabled },
                            set: { newValue in
                                if presetManager.isEnabled != newValue {
                                    if newValue {
                                        // Turning ON: if there's a preset selected, reapply it
                                        if let preset = presetManager.currentPreset {
                                            presetManager.isEnabled = true
                                            presetManager.applyPreset(preset)
                                        } else {
                                            presetManager.toggleEnabled()
                                        }
                                    } else {
                                        // Turning OFF: collapse dropdown and toggle
                                        showPresets = false
                                        presetManager.toggleEnabled()
                                    }
                                }
                            }
                        )
                    )
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                // Only show EQ controls and preset dropdown when enabled
                if presetManager.isEnabled {
                    // 10-Band EQ
                    TenBandEQ()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)

                    // Control Center-style Preset Dropdown
                    PresetDropdown(isExpanded: $showPresets)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)

                    // Preset list (animated expand/collapse)
                    if showPresets {
                        PresetList(
                            presets: presetManager.allPresets.filter { $0.id != presetManager.currentPreset?.id },
                            activeID: presetManager.currentPreset?.id,
                            userPresetIDs: presetManager.userPresetIDs,
                            onSelect: { preset in
                                presetManager.applyPreset(preset)
                                showPresets = false
                            },
                            onDelete: { preset in
                                do {
                                    try presetManager.deletePreset(preset)
                                    if preset.id == presetManager.currentPreset?.id {
                                        presetManager.currentPreset = nil
                                    }
                                } catch {
                                    print("Failed to delete preset: \(error)")
                                }
                            }
                        )
                        .padding(.horizontal, 8)
                        .padding(.bottom, 6)
                    }
                }

                // Footer
                QuitButton()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
        }
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
        .transaction { $0.animation = nil }
    }
}

struct PresetDropdown: View {
    @ObservedObject private var presetManager = PresetManager.shared
    @Binding var isExpanded: Bool
    @State private var isHovered = false
    
    // Editing state
    @State private var editingName: String = ""
    @State private var showSavedFeedback: Bool = false
    @FocusState private var isNameFieldFocused: Bool
    
    // MARK: - Computed Properties
    
    /// True when a saved preset is selected and enabled
    private var hasSelectedPreset: Bool {
        presetManager.currentPreset != nil && presetManager.isEnabled
    }
    
    /// True when user has modified EQ bands (custom unsaved state)
    private var isCustomPreset: Bool {
        presetManager.isCustomPreset && presetManager.isEnabled
    }
    
    /// True when current preset is a user-created custom preset
    private var isCurrentPresetCustom: Bool {
        guard let currentPreset = presetManager.currentPreset else { return false }
        return presetManager.userPresets.contains { $0.id == currentPreset.id }
    }
    
    /// True when in editing mode
    private var isEditing: Bool {
        presetManager.isEditingPresetName
    }
    
    /// Icon name: plus for unsaved custom, person.fill for saved custom preset, music.note for bundled preset
    private var leftIconName: String {
        if isCustomPreset {
            return "plus"
        } else if isCurrentPresetCustom {
            return "person.fill"
        } else {
            return "music.note"
        }
    }
    
    /// Display name: "Double click to add preset" when custom, preset name otherwise
    private var displayName: String {
        if isCustomPreset {
            return "Double click to add preset"
        } else {
            return presetManager.currentPreset?.name ?? PresetManager.customPresetName
        }
    }
    
    /// Check if current editing name is valid for saving
    private var isValidPresetName: Bool {
        presetManager.validatePresetName(editingName)
    }
    
    /// Save button text based on state
    private var saveButtonText: String {
        if showSavedFeedback {
            return "Saved"
        } else if presetManager.isSavingPreset {
            return "Saving..."
        } else {
            return "Save"
        }
    }
    
    /// Circle color: blue for saved preset, gray otherwise
    private var circleColor: Color {
        hasSelectedPreset ? Color.accentColor : Color(NSColor.separatorColor).opacity(0.5)
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // Left element: Circle icon OR X button (when editing)
            ZStack {
                if isEditing {
                    // X button to cancel editing
                    Button {
                        cancelEditing()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(NSColor.separatorColor).opacity(0.5))
                                .frame(width: 28, height: 28)

                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                } else {
                    // Circle icon (music.note or plus)
                    ZStack {
                        Circle()
                            .fill(circleColor)
                            .frame(width: 28, height: 28)

                        Image(systemName: leftIconName)
                            .font(.system(size: 13, weight: .medium))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(hasSelectedPreset ? .white : .secondary)
                    }
                    .gesture(
                        TapGesture()
                            .onEnded {
                                if isCustomPreset {
                                    startEditing()
                                }
                            }
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isEditing)

            // Text or TextField based on editing state
            if isEditing {
                TextField("Preset Name", text: $editingName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.primary)
                    .focused($isNameFieldFocused)
                    .onSubmit {
                        if isValidPresetName {
                            savePreset()
                        }
                    }
                    .onExitCommand {
                        cancelEditing()
                    }
                    .onChange(of: editingName) { newValue in
                        // Limit to 64 characters
                        if newValue.count > 64 {
                            editingName = String(newValue.prefix(64))
                        }
                    }
            } else {
                // Text area - double tap enters editing (when custom), single tap handled by row
                Text(displayName)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(isCustomPreset ? Color(NSColor.tertiaryLabelColor) : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture(count: 2) {
                        if isCustomPreset {
                            startEditing()
                        }
                    }
            }

            Spacer()

            // Right element: Save button (when editing) OR chevron (when not editing)
            if isEditing {
                // Save button (rounded rectangle)
                Button {
                    if isValidPresetName && !presetManager.isSavingPreset {
                        savePreset()
                    }
                } label: {
                    Text(saveButtonText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isValidPresetName ? .white : Color(NSColor.tertiaryLabelColor))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isValidPresetName ? Color.accentColor : Color(NSColor.separatorColor).opacity(0.5))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!isValidPresetName || presetManager.isSavingPreset)
            } else {
                // Chevron icon (not a button - tap handled by row)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovered ? Color(NSColor.separatorColor).opacity(0.5) : Color.clear)
        )
        .onTapGesture {
            // Tapping anywhere on the row toggles dropdown (when not editing)
            if !isEditing {
                isExpanded.toggle()
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .onChange(of: isNameFieldFocused) { focused in
            // Cancel editing if user clicks away
            if !focused && isEditing && !presetManager.isSavingPreset && !showSavedFeedback {
                cancelEditing()
            }
        }
    }
    
    // MARK: - Actions
    
    private func startEditing() {
        editingName = ""
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
        showSavedFeedback = false
    }
    
    private func savePreset() {
        guard isValidPresetName else { return }
        
        Task {
            presetManager.isSavingPreset = true
            
            do {
                try await presetManager.saveCustomPreset(name: editingName)
                presetManager.isSavingPreset = false
                
                // Show "Saved" feedback
                showSavedFeedback = true
                
                // After brief delay, exit editing and show the new preset
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    showSavedFeedback = false
                    presetManager.isEditingPresetName = false
                    editingName = ""
                    isNameFieldFocused = false
                }
            } catch {
                presetManager.isSavingPreset = false
                print("Failed to save preset: \(error)")
            }
        }
    }
}

struct PresetList: View {
    let presets: [EQPreset]
    let activeID: EQPreset.ID?
    let userPresetIDs: Set<EQPreset.ID>
    let onSelect: (EQPreset) -> Void
    let onDelete: (EQPreset) -> Void
    
    // Max items to show before scrolling (each item ~40px + 2px spacing)
    private let maxVisibleItems = 13
    private let estimatedItemHeight: CGFloat = 40
    private let itemSpacing: CGFloat = 2
    private var maxHeight: CGFloat {
        CGFloat(maxVisibleItems) * estimatedItemHeight + CGFloat(maxVisibleItems - 1) * itemSpacing
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: itemSpacing) {
                ForEach(presets) { preset in
                    MenuItemButton(
                        preset: preset,
                        isActive: preset.id == activeID,
                        isCustomPreset: userPresetIDs.contains(preset.id),
                        onSelect: { onSelect(preset) },
                        onDelete: onDelete
                    )
                }
            }
        }
        .frame(maxHeight: presets.count > maxVisibleItems ? maxHeight : nil)
    }
}

struct MenuItemButton: View {
    let preset: EQPreset
    let isActive: Bool
    let isCustomPreset: Bool
    let onSelect: () -> Void
    let onDelete: (EQPreset) -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        isActive
                            ? Color.accentColor : Color(NSColor.separatorColor).opacity(0.4)
                    )
                    .frame(width: 28, height: 28)

                Image(systemName: isCustomPreset ? "person.fill" : "music.note")
                    .font(.system(size: 13, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isActive ? .white : .secondary)
            }

            Text(preset.name)
                .font(.system(size: 13))
                .foregroundColor(.primary)

            Spacer()
            
            // Delete button (X) - only show for custom presets on hover
            if isCustomPreset && isHovered {
                Button {
                    onDelete(preset)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(NSColor.tertiaryLabelColor))
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isHovered ? Color(NSColor.separatorColor).opacity(0.5) : Color.clear)
        )
        .onTapGesture {
            onSelect()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct QuitButton: View {
    @State private var isHovered = false

    var body: some View {
        Button("Quit Radioform") {
            NSApp.terminate(nil)
        }
        .buttonStyle(.plain)
        .font(.system(size: 11, weight: .regular))
        .foregroundColor(isHovered ? .white : .primary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovered ? Color.accentColor : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
