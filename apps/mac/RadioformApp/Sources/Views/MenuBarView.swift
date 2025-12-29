import SwiftUI

struct MenuBarView: View {
    @ObservedObject private var presetManager = PresetManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .foregroundColor(.blue)
                Text("Radioform EQ")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Current preset indicator
            if let current = presetManager.currentPreset {
                HStack {
                    Text("Now Playing:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(current.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }

            // Preset list
            ScrollView {
                VStack(spacing: 4) {
                    // Bundled presets
                    if !presetManager.bundledPresets.isEmpty {
                        PresetSection(
                            title: "Presets",
                            presets: presetManager.bundledPresets,
                            currentPreset: presetManager.currentPreset
                        )
                    }

                    // User presets
                    if !presetManager.userPresets.isEmpty {
                        Divider()
                            .padding(.vertical, 8)

                        PresetSection(
                            title: "My Presets",
                            presets: presetManager.userPresets,
                            currentPreset: presetManager.currentPreset
                        )
                    }
                }
                .padding(.vertical, 8)
            }

            Divider()

            // Footer actions
            HStack(spacing: 16) {
                Button(action: {
                    NSApp.terminate(nil)
                }) {
                    Text("Quit")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 300, height: 400)
    }
}

struct PresetSection: View {
    let title: String
    let presets: [EQPreset]
    let currentPreset: EQPreset?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.bottom, 4)

            ForEach(presets) { preset in
                PresetRow(preset: preset, isActive: preset.id == currentPreset?.id)
            }
        }
    }
}

struct PresetRow: View {
    let preset: EQPreset
    let isActive: Bool

    var body: some View {
        Button(action: {
            PresetManager.shared.applyPreset(preset)
        }) {
            HStack {
                Text(preset.name)
                    .foregroundColor(isActive ? .blue : .primary)
                Spacer()
                if isActive {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(isActive ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }
}
