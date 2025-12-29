import Foundation
import SwiftUI
import AppKit

/// Coordinates the onboarding window lifecycle and flow
class OnboardingCoordinator: ObservableObject {
    @Published var currentWindow: OnboardingWindow?

    /// Show the onboarding window
    func show() {
        // Close existing window if any
        close()

        // Create and configure new window (pass self as coordinator)
        let window = OnboardingWindow(coordinator: self)
        window.center()
        window.makeKeyAndOrderFront(nil)

        self.currentWindow = window

        print("✓ Onboarding window shown")
    }

    /// Close the onboarding window
    func close() {
        currentWindow?.close()
        currentWindow = nil
        print("✓ Onboarding window closed")
    }

    /// Handle onboarding completion
    func complete() {
        OnboardingState.markCompleted()
        close()

        // Notify app delegate to set up menu bar
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.launchHostIfNeeded()
            appDelegate.setupMenuBar()
        }

        print("✓ Onboarding completed")
    }
}
