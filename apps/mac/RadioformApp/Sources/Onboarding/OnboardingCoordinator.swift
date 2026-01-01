import Foundation
import SwiftUI
import AppKit

/// Coordinates the onboarding window lifecycle and flow
class OnboardingCoordinator: ObservableObject {
    @Published var currentWindow: OnboardingWindow?
    var onComplete: (() -> Void)?

    /// Show the onboarding window
    func show(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete

        // Close existing window if any
        close()

        // Create and configure new window (pass self as coordinator)
        let window = OnboardingWindow(coordinator: self)
        window.center()
        window.makeKeyAndOrderFront(nil)

        self.currentWindow = window

        print("Onboarding window shown")
    }

    /// Close the onboarding window
    func close() {
        currentWindow?.close()
        currentWindow = nil
        print("Onboarding window closed")
    }

    /// Handle onboarding completion
    func complete() {
        print("OnboardingCoordinator.complete() called")
        OnboardingState.markCompleted()
        close()

        // Call completion handler to notify app
        print("Calling onComplete handler...")
        onComplete?()
        print("Onboarding completed")
    }
}
