import SwiftUI

struct MenuBarView: View {
    @ObservedObject private var presetManager = PresetManager.shared

    var body: some View {
        ZStack(alignment: .top) {
            // Background with native popover material
            VisualEffectView(material: .popover, blendingMode: .behindWindow)

            VStack(spacing: 0) {
                // Header with Radioform title and toggle
                HStack {
                    Text("Radioform")
                        .font(.system(size: 13, weight: .semibold))

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { presetManager.isEnabled },
                        set: { _ in presetManager.toggleEnabled() }
                    ))
                    .toggleStyle(.switch)
                    .scaleEffect(0.7)
                    .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)

                Divider()

                // 10-Band EQ
                TenBandEQ()
                    .padding(.vertical, 8)

                Divider()

                // Control Center-style Preset Dropdown
                PresetDropdown()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)

                Divider()

                // Footer
                HStack(spacing: 12) {
                    Button("Quit Radioform") {
                        NSApp.terminate(nil)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct PresetDropdown: View {
    @ObservedObject private var presetManager = PresetManager.shared
    @State private var show = false

    var body: some View {
        Button {
            show.toggle()
        } label: {
            HStack(spacing: 10) {
                // Left circular icon with native vibrancy
                ZStack {
                    Circle()
                        .fill(Color(NSColor.separatorColor).opacity(0.5))
                        .frame(width: 28, height: 28)

                    Image(systemName: "music.note")
                        .font(.system(size: 13, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }

                Text(presetManager.currentPreset?.name ?? "No Preset")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $show, arrowEdge: .top) {
            ZStack {
                VisualEffectView(material: .menu, blendingMode: .behindWindow)

                PresetPopoverList(
                    presets: presetManager.bundledPresets + presetManager.userPresets,
                    activeID: presetManager.currentPreset?.id,
                    onSelect: { preset in
                        presetManager.applyPreset(preset)
                        show = false
                    }
                )
            }
            .frame(width: 240)
        }
    }
}

struct PresetPopoverList: View {
    let presets: [EQPreset]
    let activeID: EQPreset.ID?
    let onSelect: (EQPreset) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Presets")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 4)

            ForEach(presets) { preset in
                MenuItemButton(
                    preset: preset,
                    isActive: preset.id == activeID,
                    onSelect: { onSelect(preset) }
                )
            }

            Spacer(minLength: 4)
        }
        .padding(.vertical, 2)
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
                        .fill(isActive ? Color.accentColor : Color(NSColor.separatorColor).opacity(0.4))
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
                    .fill(isHovered ? Color(NSColor.controlAccentColor).opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
