import Foundation

/// Keys for storing onboarding-related state in UserDefaults
enum OnboardingKey {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let driverInstallDate = "driverInstallDate"
    static let onboardingVersion = "onboardingVersion"
}

/// Manages onboarding state persistence using UserDefaults
struct OnboardingState {
    /// Check if user has completed onboarding
    static func hasCompleted() -> Bool {
        return UserDefaults.standard.bool(forKey: OnboardingKey.hasCompletedOnboarding)
    }

    /// Mark onboarding as completed
    static func markCompleted() {
        UserDefaults.standard.set(true, forKey: OnboardingKey.hasCompletedOnboarding)
        UserDefaults.standard.set(Date(), forKey: OnboardingKey.driverInstallDate)
        UserDefaults.standard.set(1, forKey: OnboardingKey.onboardingVersion)
        print("Onboarding marked as completed")
    }

    /// Reset onboarding state (for testing)
    static func reset() {
        UserDefaults.standard.removeObject(forKey: OnboardingKey.hasCompletedOnboarding)
        UserDefaults.standard.removeObject(forKey: OnboardingKey.driverInstallDate)
        UserDefaults.standard.removeObject(forKey: OnboardingKey.onboardingVersion)
        print("Onboarding state cleared")
    }

    /// Get the date when driver was installed (if available)
    static func driverInstallDate() -> Date? {
        return UserDefaults.standard.object(forKey: OnboardingKey.driverInstallDate) as? Date
    }

    /// Get current onboarding version
    static func version() -> Int {
        return UserDefaults.standard.integer(forKey: OnboardingKey.onboardingVersion)
    }
}
