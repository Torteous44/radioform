import SwiftUI

/// Driver installation step in onboarding
struct DriverInstallStepView: View {
    @StateObject private var installer = DriverInstaller()
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var iconScale: CGFloat = 1.0

    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon with breathe animation
            Image(systemName: "headphones")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
                .scaleEffect(iconScale)
                .onAppear {
                    // Breathe animation loop
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        iconScale = 1.2
                    }
                }
            
            // Explanation text
            Text("Radioform needs to install a system audio driver to process your audio")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            // Status and progress
            VStack(spacing: 16) {
                Text(installer.state.description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                if !installer.state.isComplete && !installer.state.isFailed {
                    ProgressView(value: installer.progress)
                        .frame(maxWidth: 300)
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
