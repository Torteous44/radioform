import SwiftUI

/// Permissions explanation step in onboarding
struct PermissionsStepView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                Text("Audio Setup")
                    .font(.system(size: 24, weight: .bold))

                Text("Configure Radioform as your audio output")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 20)

            // Scrollable content
            ScrollView {
                VStack(spacing: 16) {
                    // Instructions
                    VStack(alignment: .leading, spacing: 16) {
                        InstructionRow(
                            number: 1,
                            title: "Open System Settings",
                            description: "Navigate to System Settings > Sound"
                        )

                        InstructionRow(
                            number: 2,
                            title: "Select Radioform Output",
                            description: "Choose a Radioform device as your output device"
                        )

                        InstructionRow(
                            number: 3,
                            title: "Audio Will Restart",
                            description: "Your audio system will restart briefly when you change devices"
                        )
                    }
                    .padding(20)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(12)

                    // Info box
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 18))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Radioform runs in your menu bar")
                                .font(.system(size: 12, weight: .medium))

                            Text("Adjust your audio settings anytime by clicking the menu bar icon")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(14)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }

            // Action button
            Button("Continue") {
                onContinue()
            }
            .keyboardShortcut(.return)
            .buttonStyle(.borderedProminent)
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Individual instruction row
struct InstructionRow: View {
    let number: Int
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Number badge
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 32, height: 32)

                Text("\(number)")
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .semibold))
            }

            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))

                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}
