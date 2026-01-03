import SwiftUI

/// Instructions / post-install step
struct PermissionsStepView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Great! Now select “Radioform” from the audio dropdown")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                Text("Sounds → (Radioform)")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }

            Text("Ready to hear the difference? →")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.top, 12)

            Button("Continue") {
                onContinue()
            }
            .keyboardShortcut(.return)
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
