import SwiftUI
import AppKit
import Sparkle

/// Settings window for Radioform preferences
class SettingsWindow: NSWindow {
	init(updaterController: SPUStandardUpdaterController?) {
		super.init(
			contentRect: NSRect(x: 0, y: 0, width: 500, height: 450),
			styleMask: [.titled, .closable],
			backing: .buffered,
			defer: false
		)

		self.title = "Radioform Settings"
		self.isReleasedWhenClosed = false
		self.contentView = NSHostingView(
			rootView: SettingsView(updaterController: updaterController)
		)
	}
}

struct SettingsView: View {
	let updaterController: SPUStandardUpdaterController?

	@State private var automaticCheckEnabled: Bool = true
	@State private var lastCheckDate: Date?
	@State private var isCheckingForUpdates = false

	var body: some View {
		VStack(spacing: 0) {
			// Header
			VStack(spacing: 12) {
				Image(systemName: "waveform.circle.fill")
					.font(.system(size: 52))
					.foregroundColor(.accentColor)

				Text("Radioform")
					.font(.title)
					.fontWeight(.semibold)

				if let version = VersionManager.appVersion() {
					Text("Version \(version)")
						.font(.subheadline)
						.foregroundColor(.secondary)
				}
			}
			.padding(.top, 30)
			.padding(.bottom, 20)

			Divider()

			// Content
			ScrollView {
				VStack(spacing: 24) {
					// Update Settings Section
					VStack(alignment: .leading, spacing: 16) {
						Text("Updates")
							.font(.headline)
							.foregroundColor(.primary)

						VStack(alignment: .leading, spacing: 12) {
							Toggle("Automatically check for updates", isOn: $automaticCheckEnabled)
								.onChange(of: automaticCheckEnabled) { newValue in
									updaterController?.updater.automaticallyChecksForUpdates = newValue
								}

							if let lastCheck = lastCheckDate {
								HStack {
									Text("Last checked:")
										.foregroundColor(.secondary)
									Spacer()
									Text(lastCheck, style: .relative)
										.foregroundColor(.secondary)
								}
								.font(.caption)
							}

							Button(action: checkForUpdates) {
								HStack {
									if isCheckingForUpdates {
										ProgressView()
											.scaleEffect(0.8)
											.frame(width: 16, height: 16)
									} else {
										Image(systemName: "arrow.triangle.2.circlepath")
									}
									Text(isCheckingForUpdates ? "Checking..." : "Check for Updates")
								}
								.frame(maxWidth: .infinity)
							}
							.disabled(isCheckingForUpdates)
							.controlSize(.large)
						}
					}
					.padding(16)
					.background(Color.secondary.opacity(0.05))
					.cornerRadius(12)

					// System Info Section
					VStack(alignment: .leading, spacing: 16) {
						Text("System Info")
							.font(.headline)
							.foregroundColor(.primary)

						VStack(alignment: .leading, spacing: 10) {
							if let appVersion = VersionManager.appVersion() {
								InfoRow(label: "App Version", value: appVersion)
							}

							if VersionManager.isDriverInstalled() {
								if let driverVersion = VersionManager.installedDriverVersion() {
									InfoRow(label: "Driver Version", value: driverVersion)
								}
							} else {
								InfoRow(label: "Driver Status", value: "Not Installed")
									.foregroundColor(.orange)
							}

							if let installDate = OnboardingState.driverInstallDate() {
								InfoRow(label: "Driver Installed", value: formatDate(installDate))
							}
						}
					}
					.padding(16)
					.background(Color.secondary.opacity(0.05))
					.cornerRadius(12)

					// About Section
					VStack(alignment: .leading, spacing: 16) {
						Text("About")
							.font(.headline)
							.foregroundColor(.primary)

						VStack(alignment: .leading, spacing: 8) {
							Text("Radioform is a free, open-source system equalizer for macOS.")
								.font(.caption)
								.foregroundColor(.secondary)

							Link("View on GitHub", destination: URL(string: "https://github.com/Torteous44/radioform")!)
								.font(.caption)
						}
					}
					.padding(16)
					.background(Color.secondary.opacity(0.05))
					.cornerRadius(12)
				}
				.padding(20)
			}
		}
		.frame(width: 500, height: 450)
		.onAppear {
			automaticCheckEnabled = updaterController?.updater.automaticallyChecksForUpdates ?? true
		}
	}

	private func checkForUpdates() {
		isCheckingForUpdates = true
		updaterController?.checkForUpdates(nil)

		// Update last check date
		lastCheckDate = Date()

		// Reset checking state after delay
		DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
			isCheckingForUpdates = false
		}
	}

	private func formatDate(_ date: Date) -> String {
		let formatter = DateFormatter()
		formatter.dateStyle = .medium
		formatter.timeStyle = .none
		return formatter.string(from: date)
	}
}

struct InfoRow: View {
	let label: String
	let value: String

	var body: some View {
		HStack {
			Text(label)
				.font(.caption)
				.foregroundColor(.secondary)
			Spacer()
			Text(value)
				.font(.caption)
				.fontWeight(.medium)
		}
	}
}
