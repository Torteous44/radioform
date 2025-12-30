import SwiftUI

/// Completion step in onboarding
struct CompletionStepView: View {
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Success icon (smaller)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.green)
            
            // Header text (compact)
            VStack(alignment: .leading, spacing: 4) {
                Text("Setup Complete!")
                    .font(.system(size: 16, weight: .semibold))
                
                Text("Radioform is now running in your menu bar")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Action button (smaller)
            Button("Get Started") {
                onComplete()
            }
            .keyboardShortcut(.return)
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
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
