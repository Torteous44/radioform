import SwiftUI

/// Main onboarding view with multi-step wizard
struct OnboardingView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @State private var currentStep: OnboardingStep = .driverInstall

    enum OnboardingStep {
        case driverInstall
        case permissions
        case completion
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            ProgressIndicator(currentStep: currentStep)
                .padding(.top, 30)
                .padding(.horizontal, 40)

            Divider()
                .padding(.vertical, 20)

            // Step content
            stepView(for: currentStep)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
        }
        .frame(width: 600, height: 500)
    }

    @ViewBuilder
    private func stepView(for step: OnboardingStep) -> some View {
        switch step {
        case .driverInstall:
            DriverInstallStepView(
                onContinue: {
                    currentStep = .permissions
                }
            )

        case .permissions:
            PermissionsStepView(
                onContinue: {
                    currentStep = .completion
                }
            )

        case .completion:
            CompletionStepView(
                onComplete: {
                    coordinator.complete()
                }
            )
        }
    }
}

/// Progress indicator showing current step
struct ProgressIndicator: View {
    let currentStep: OnboardingView.OnboardingStep

    var body: some View {
        HStack(spacing: 12) {
            StepDot(number: 1, isActive: isActive(.driverInstall), isCompleted: isCompleted(.driverInstall))
            StepLine(isActive: isActive(.permissions) || isCompleted(.permissions))
            StepDot(number: 2, isActive: isActive(.permissions), isCompleted: isCompleted(.permissions))
            StepLine(isActive: isActive(.completion) || isCompleted(.completion))
            StepDot(number: 3, isActive: isActive(.completion), isCompleted: isCompleted(.completion))
        }
    }

    private func isActive(_ step: OnboardingView.OnboardingStep) -> Bool {
        return currentStep == step
    }

    private func isCompleted(_ step: OnboardingView.OnboardingStep) -> Bool {
        switch (step, currentStep) {
        case (.driverInstall, .permissions), (.driverInstall, .completion):
            return true
        case (.permissions, .completion):
            return true
        default:
            return false
        }
    }
}

/// Individual step dot
struct StepDot: View {
    let number: Int
    let isActive: Bool
    let isCompleted: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(fillColor)
                .frame(width: 32, height: 32)

            if isCompleted {
                Image(systemName: "checkmark")
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .semibold))
            } else {
                Text("\(number)")
                    .foregroundColor(textColor)
                    .font(.system(size: 14, weight: .semibold))
            }
        }
    }

    private var fillColor: Color {
        if isCompleted {
            return .green
        } else if isActive {
            return .accentColor
        } else {
            return Color(.systemGray).opacity(0.3)
        }
    }

    private var textColor: Color {
        if isActive {
            return .white
        } else {
            return Color(.systemGray)
        }
    }
}

/// Connection line between steps
struct StepLine: View {
    let isActive: Bool

    var body: some View {
        Rectangle()
            .fill(isActive ? Color.green : Color(.systemGray).opacity(0.3))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
    }
}
