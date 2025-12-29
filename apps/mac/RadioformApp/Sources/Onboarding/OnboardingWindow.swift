import AppKit
import SwiftUI

/// Custom NSWindow for onboarding flow
class OnboardingWindow: NSWindow {
    init(coordinator: OnboardingCoordinator) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        self.title = "Welcome to Radioform"
        self.isReleasedWhenClosed = false

        // Center on screen
        self.center()

        // Set up SwiftUI content
        let contentView = OnboardingView(coordinator: coordinator)
        self.contentView = NSHostingView(rootView: contentView)

        // Make the window appear properly
        self.isMovableByWindowBackground = true

        // Set level to ensure visibility
        self.level = .floating
    }
}
