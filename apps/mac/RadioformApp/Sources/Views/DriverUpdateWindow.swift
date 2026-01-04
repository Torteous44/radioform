import SwiftUI
import AppKit

/// Window for prompting driver updates
class DriverUpdateWindow: NSWindow {
	init(currentVersion: String, newVersion: String, onUpdate: @escaping () -> Void, onDismiss: @escaping () -> Void) {
		super.init(
			contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
			styleMask: [.titled, .closable],
			backing: .buffered,
			defer: false
		)

		self.title = "Driver Update Available"
		self.isReleasedWhenClosed = false
		self.contentView = NSHostingView(
			rootView: DriverUpdateView(
				currentVersion: currentVersion,
				newVersion: newVersion,
				onUpdate: onUpdate,
				onDismiss: onDismiss
			)
		)
	}
}

struct DriverUpdateView: View {
	let currentVersion: String
	let newVersion: String
	let onUpdate: () -> Void
	let onDismiss: () -> Void

	var body: some View {
		VStack(spacing: 20) {
			// Icon
			Image(systemName: "arrow.triangle.2.circlepath")
				.font(.system(size: 48))
				.foregroundColor(.accentColor)

			// Title
			Text("Driver Update Available")
				.font(.title2)
				.fontWeight(.semibold)

			// Message
			VStack(spacing: 12) {
				Text("A new version of the Radioform audio driver is available.")
					.multilineTextAlignment(.center)
					.foregroundColor(.primary)

				// Version comparison
				HStack(spacing: 16) {
					VStack(alignment: .leading, spacing: 4) {
						Text("Current")
							.font(.caption)
							.foregroundColor(.secondary)
						Text(currentVersion)
							.font(.system(.body, design: .monospaced))
							.fontWeight(.semibold)
					}

					Image(systemName: "arrow.right")
						.font(.caption)
						.foregroundColor(.secondary)

					VStack(alignment: .leading, spacing: 4) {
						Text("New")
							.font(.caption)
							.foregroundColor(.secondary)
						Text(newVersion)
							.font(.system(.body, design: .monospaced))
							.fontWeight(.semibold)
							.foregroundColor(.accentColor)
					}
				}
				.padding(12)
				.background(Color.secondary.opacity(0.1))
				.cornerRadius(8)

				// Info message
				Text("Updating requires administrator privileges and will restart the audio system.")
					.font(.caption)
					.foregroundColor(.secondary)
					.multilineTextAlignment(.center)
					.padding(.horizontal)
			}

			Spacer()

			// Buttons
			HStack(spacing: 12) {
				Button("Later") {
					onDismiss()
				}
				.keyboardShortcut(.cancelAction)
				.controlSize(.large)

				Button("Update Now") {
					onUpdate()
				}
				.keyboardShortcut(.defaultAction)
				.buttonStyle(.borderedProminent)
				.controlSize(.large)
			}
		}
		.padding(30)
		.frame(width: 480, height: 300)
	}
}
