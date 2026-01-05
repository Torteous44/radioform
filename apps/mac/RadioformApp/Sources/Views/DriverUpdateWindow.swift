import SwiftUI
import AppKit

/// Window for prompting driver updates
class DriverUpdateWindow: NSWindow {
	init(currentVersion: String, newVersion: String, onUpdate: @escaping () -> Void, onDismiss: @escaping () -> Void) {
		super.init(
			contentRect: NSRect(x: 0, y: 0, width: 400, height: 180),
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
		VStack(spacing: 16) {
			// Version comparison
			HStack(spacing: 12) {
				VStack(alignment: .leading, spacing: 2) {
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

				VStack(alignment: .leading, spacing: 2) {
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
			.frame(maxWidth: .infinity)
			.background(Color.secondary.opacity(0.1))
			.cornerRadius(8)

			// Info message
			Text("Requires administrator privileges")
				.font(.caption)
				.foregroundColor(.secondary)

			// Buttons
			HStack(spacing: 12) {
				Button("Later") {
					onDismiss()
				}
				.keyboardShortcut(.cancelAction)

				Button("Update Now") {
					onUpdate()
				}
				.keyboardShortcut(.defaultAction)
				.buttonStyle(.borderedProminent)
			}
		}
		.padding(20)
		.frame(width: 400, height: 180)
	}
}
