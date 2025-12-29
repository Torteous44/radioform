import SwiftUI

/// Completion step in onboarding
struct CompletionStepView: View {
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 40)

            // Success icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)
            }
            .padding(.bottom, 20)

            // Header
            VStack(spacing: 8) {
                Text("Setup Complete!")
                    .font(.system(size: 24, weight: .bold))

                Text("Radioform is now running in your menu bar")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 24)

            // Quick tips
            VStack(alignment: .leading, spacing: 14) {
                TipRow(
                    icon: "slider.horizontal.3",
                    text: "Click the menu bar icon to adjust your EQ"
                )

                TipRow(
                    icon: "music.note.list",
                    text: "Choose from 8 preset configurations or create your own"
                )

                TipRow(
                    icon: "speaker.wave.2.fill",
                    text: "Set Radioform as your output device in System Settings"
                )
            }
            .padding(20)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(12)

            Spacer(minLength: 24)

            // Action button
            Button("Get Started") {
                onComplete()
            }
            .keyboardShortcut(.return)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Individual tip row
struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .font(.system(size: 20))
                .frame(width: 32)

            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.primary)

            Spacer()
        }
    }
}
