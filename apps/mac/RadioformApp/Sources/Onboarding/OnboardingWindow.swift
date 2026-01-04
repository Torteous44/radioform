import AppKit
import SwiftUI

/// Custom borderless NSWindow for onboarding flow with vintage paper background
class OnboardingWindow: NSWindow {
    init(coordinator: OnboardingCoordinator) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.isReleasedWhenClosed = false

        // Make window background transparent so our custom background shows
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true

        // Center on screen
        self.center()

        // Set up SwiftUI content with vintage paper background
        let contentView = OnboardingView(coordinator: coordinator)
            .vintagePaperBackground()
            .clipShape(RoundedRectangle(cornerRadius: 12))
        self.contentView = NSHostingView(rootView: contentView)

        // Make the window draggable by clicking anywhere on the background
        self.isMovableByWindowBackground = true

        // Set level to ensure visibility
        self.level = .floating
    }

    // Allow the borderless window to become key window (receive keyboard input)
    override var canBecomeKey: Bool {
        return true
    }

    // Allow the borderless window to become main window
    override var canBecomeMain: Bool {
        return true
    }
}
