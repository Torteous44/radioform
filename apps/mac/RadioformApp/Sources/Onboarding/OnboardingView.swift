import SwiftUI
import AppKit

/// Main onboarding view with multi-step wizard
struct OnboardingView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @State private var currentStep: OnboardingStep = .driverInstall
    @State private var logoSize: CGFloat = 80
    @State private var topSpacerHeight: CGFloat = 200
    @State private var showOnboardingContent = false

    enum OnboardingStep {
        case driverInstall
        case permissions
        case completion
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top spacer - animates to shrink, moving logo up
            Spacer()
                .frame(height: topSpacerHeight)
            
            // Logo - stays in same view, just moves position
            HStack {
                Spacer()
                Text("Radioform")
                    .font(radioformFont(size: logoSize))
                Spacer()
            }
            .padding(.horizontal, 40)
            
            // Onboarding content appears below logo
            if showOnboardingContent {
                onboardingContent
            } else {
                // Bottom spacer to keep logo centered initially
                Spacer()
            }
        }
        .frame(width: 600, height: 500)
        .onAppear {
            // After 1 second, animate logo to top
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeInOut(duration: 0.6)) {
                    logoSize = 32
                    topSpacerHeight = 20
                }
                // Show onboarding content after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    showOnboardingContent = true
                }
            }
        }
    }
    
    private var onboardingContent: some View {
        VStack(spacing: 0) {
            // Step content
            if currentStep == .completion {
                // For completion step, show content in middle and completion view at bottom
                VStack(spacing: 0) {
                    // Main content area (empty for completion, but could show other steps)
                    Spacer()
                    
                    // Completion step at bottom
                    CompletionStepView(
                        onComplete: {
                            coordinator.complete()
                        }
                    )
                    .frame(height: 60)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                }
            } else {
                // Regular step content
                stepView(for: currentStep)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
            }
        }
    }
    
    private func radioformFont(size: CGFloat) -> Font {
        // Try the expected name first
        if NSFont(name: "SignPainterHouseScript", size: size) != nil {
            return .custom("SignPainterHouseScript", size: size)
        }
        
        // Try variations
        let possibleNames = [
            "SignPainterHouseScript",
            "SignPainter-HouseScript",
            "SignPainter House Script",
            "SignPainter"
        ]
        
        for name in possibleNames {
            if NSFont(name: name, size: size) != nil {
                return .custom(name, size: size)
            }
        }
        
        // Fallback to system font
        return .system(size: size, weight: .bold)
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
