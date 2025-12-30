import SwiftUI

struct MenuBarView: View {
    @ObservedObject private var presetManager = PresetManager.shared
    @State private var showPresets = false
    @State private var radioformFontSize: CGFloat = 22
    
    // Try to find the SignPainter font with fallback
    func fontForRadioform(size: CGFloat) -> Font {
        // Try the expected name first
        if NSFont(name: "SignPainterHouseScript", size: size) != nil {
            return .custom("SignPainterHouseScript", size: size)
        }
        
        // Try variations
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
        
        // Fallback to system font
        return .system(size: size, weight: .bold)
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Background with native popover material
            VisualEffectView(material: .popover, blendingMode: .behindWindow)

            VStack(spacing: 0) {
                // Header with toggle only (no title)
                HStack {
                    Text("Radioform")
                        .font(fontForRadioform(size: radioformFontSize))
                        
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
                                        // Turning OFF: just toggle
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

                // Only show EQ controls when enabled
                if presetManager.isEnabled {
                    // 10-Band EQ
                    TenBandEQ()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)

                    // Control Center-style Preset Dropdown
                    PresetDropdown(isExpanded: $showPresets)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)

                    // Preset list (shown when expanded)
                    if showPresets {
                        PresetList(
                            presets: (presetManager.bundledPresets + presetManager.userPresets).filter { preset in
                                preset.id != presetManager.currentPreset?.id
                            },
                            activeID: presetManager.currentPreset?.id,
                            onSelect: { preset in
                                presetManager.applyPreset(preset)
                                showPresets = false
                            }
                        )
                        .padding(.horizontal, 8)
                        .padding(.bottom, 6)
                    }

                    // Footer
                    QuitButton()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                }
            }
        }
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct PresetDropdown: View {
    @ObservedObject private var presetManager = PresetManager.shared
    @Binding var isExpanded: Bool
    @State private var isHovered = false

    var body: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: 10) {
                // Left circular icon with blue fill when active and enabled
                ZStack {
                    Circle()
                        .fill(
                            presetManager.currentPreset != nil && presetManager.isEnabled
                                ? Color.accentColor : Color(NSColor.separatorColor).opacity(0.5)
                        )
                        .frame(width: 28, height: 28)

                    Image(systemName: "music.note")
                        .font(.system(size: 13, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(
                            presetManager.currentPreset != nil && presetManager.isEnabled
                                ? .white : .secondary)
                }

                Text(presetManager.currentPreset?.name ?? "Custom")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovered ? Color(NSColor.separatorColor).opacity(0.5) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct PresetList: View {
    let presets: [EQPreset]
    let activeID: EQPreset.ID?
    let onSelect: (EQPreset) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(presets) { preset in
                MenuItemButton(
                    preset: preset,
                    isActive: preset.id == activeID,
                    onSelect: { onSelect(preset) }
                )
            }
        }
    }
}

struct MenuItemButton: View {
    let preset: EQPreset
    let isActive: Bool
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            isActive
                                ? Color.accentColor : Color(NSColor.separatorColor).opacity(0.4)
                        )
                        .frame(width: 28, height: 28)

                    Image(systemName: "music.note")
                        .font(.system(size: 13, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isActive ? .white : .secondary)
                }

                Text(preset.name)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isHovered ? Color(NSColor.separatorColor).opacity(0.5) : Color.clear)
            )
        }
        .buttonStyle(.plain)
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
