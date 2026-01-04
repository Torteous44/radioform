import SwiftUI

/// Driver installation step in onboarding
struct DriverInstallStepView: View {
    @StateObject private var installer = DriverInstaller()
    @State private var showError = false
    @State private var errorMessage = ""

    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("We'll need to install an audio driver")
                    .font(.system(size: 18, weight: .semibold))
                Text("This enables system-wide EQ across all apps.")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(
                    installer.state.description == "Not started"
                        ? "Install →" : installer.state.description
                )
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                ProgressView(value: installer.progress)
                    .frame(maxWidth: 360)
                    .tint(Color.gray.opacity(0.65))
            }

            HStack(spacing: 12) {
                if installer.state.isFailed {
                    Button("Retry") {
                        installDriver()
                    }
                    .keyboardShortcut(.return)
                }

                if installer.state == .notStarted {
                    Button("Install") {
                        installDriver()
                    }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                }

                if installer.state.isComplete {
                    Button("Continue") {
                        onContinue()
                    }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .alert("Installation Error", isPresented: $showError) {
            Button("OK") {
                showError = false
            }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // Check if already installed
            if installer.isDriverLoaded() {
                installer.state = .complete
                installer.progress = 1.0
            }
        }
    }

    private func installDriver() {
        Task {
            do {
                try await installer.installDriver()
                // Auto-continue after 1 second on success
                try await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    onContinue()
                }
            } catch {
                await MainActor.run {
                    installer.state = .failed(error.localizedDescription)
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}
