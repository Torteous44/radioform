import SwiftUI

/// Driver installation step in onboarding
struct DriverInstallStepView: View {
    @StateObject private var installer = DriverInstaller()
    @State private var showError = false
    @State private var errorMessage = ""

    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.accentColor)

                Text("Install Audio Driver")
                    .font(.system(size: 28, weight: .bold))

                Text("Radioform needs to install a system audio driver to process your audio")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            Spacer()

            // Status and progress
            VStack(spacing: 16) {
                Text(installer.state.description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                if !installer.state.isComplete && !installer.state.isFailed {
                    ProgressView(value: installer.progress)
                        .frame(maxWidth: 300)
                }

                if installer.state.isComplete {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Driver installed successfully!")
                            .foregroundColor(.green)
                    }
                    .font(.system(size: 14, weight: .medium))
                }

                if installer.state.isFailed {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("Installation failed")
                            .foregroundColor(.red)
                    }
                    .font(.system(size: 14, weight: .medium))
                }
            }

            Spacer()

            // Action buttons
            HStack(spacing: 12) {
                if installer.state.isFailed {
                    Button("Retry") {
                        installDriver()
                    }
                    .keyboardShortcut(.return)
                }

                if installer.state == .notStarted {
                    Button("Install Driver") {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
