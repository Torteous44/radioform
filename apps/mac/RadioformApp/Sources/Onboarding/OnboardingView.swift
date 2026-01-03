import SwiftUI
import AppKit

/// Main onboarding view with multi-step wizard
struct OnboardingView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @State private var currentStep: OnboardingStep = .welcome

    enum OnboardingStep {
        case welcome
        case driverInstall
        case instructions
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color.white
                    .ignoresSafeArea()

                // Envelope background that animates between steps
                EnvelopeView(formattedDate: formattedDate)
                    .frame(width: envelopeSize(for: geo).width, height: envelopeSize(for: geo).height)
                    .offset(envelopeOffset(for: currentStep, geo: geo))
                    .animation(.spring(response: 0.7, dampingFraction: 0.8, blendDuration: 0.2), value: currentStep)

                // Step content - fixed position on right side of white background
                stepView(for: currentStep)
                    .frame(width: 500)
                    .position(
                        x: geo.size.width - 180,
                        y: geo.size.height * 0.77
                    )

                // Continue button for welcome step - bottom-right of modal
                if currentStep == .welcome {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button("Continue") {
                                currentStep = .driverInstall
                            }
                            .keyboardShortcut(.return)
                            .buttonStyle(.borderedProminent)
                            .padding(.trailing, 32)
                            .padding(.bottom, 32)
                        }
                    }
                }
            }
            .preferredColorScheme(.light) // keep white even in dark mode
        }
        .frame(minWidth: 800, minHeight: 600)
    }

    @ViewBuilder
    private func stepView(for step: OnboardingStep) -> some View {
        switch step {
        case .welcome:
            WelcomeStepView(
                onContinue: {
                    currentStep = .driverInstall
                }
            )

        case .driverInstall:
            DriverInstallStepView(
                onContinue: {
                    currentStep = .instructions
                }
            )

        case .instructions:
            PermissionsStepView(
                onContinue: {
                    coordinator.complete()
                }
            )
        }
    }

    // MARK: Envelope layout helpers

    private func envelopeSize(for geo: GeometryProxy) -> CGSize {
        let width = min(geo.size.width * 0.72, 900)
        let height = min(geo.size.height * 0.9, 950)
        return CGSize(width: width, height: height)
    }

    private func envelopeOffset(for step: OnboardingStep, geo: GeometryProxy) -> CGSize {
        let size = envelopeSize(for: geo)
        switch step {
        case .welcome:
            // Phase 1: envelope far right, right corners completely off-screen
            return CGSize(
                width: geo.size.width * 0.52,
                height: -geo.size.height * 0.05
            )
        case .driverInstall, .instructions:
            // Phase 2/3: envelope far left, left corners off-screen, reveals right side
            return CGSize(
                width: -geo.size.width * 0.42,
                height: -geo.size.height * 0.05
            )
        }
    }

    private var formattedDate: String {
        let now = Date()
        let calendar = Calendar.current
        let day = calendar.component(.day, from: now)
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM"
        let month = monthFormatter.string(from: now).uppercased()
        let year = calendar.component(.year, from: now)
        return "\(month) \(ordinal(for: day)) \(year)"
    }

    private func ordinal(for day: Int) -> String {
        let suffix: String
        let ones = day % 10
        let tens = (day / 10) % 10

        if tens == 1 {
            suffix = "TH"
        } else {
            switch ones {
            case 1: suffix = "ST"
            case 2: suffix = "ND"
            case 3: suffix = "RD"
            default: suffix = "TH"
            }
        }

        return "\(day)\(suffix)"
    }
}

/// Progress indicator showing current step
struct ProgressIndicator: View {
    let currentStep: OnboardingView.OnboardingStep

    var body: some View {
        HStack(spacing: 12) {
            StepDot(number: 1, isActive: isActive(.welcome), isCompleted: isCompleted(.welcome))
            StepLine(isActive: isActive(.driverInstall) || isCompleted(.driverInstall))
            StepDot(number: 2, isActive: isActive(.driverInstall), isCompleted: isCompleted(.driverInstall))
            StepLine(isActive: isActive(.instructions) || isCompleted(.instructions))
            StepDot(number: 3, isActive: isActive(.instructions), isCompleted: isCompleted(.instructions))
        }
    }

    private func isActive(_ step: OnboardingView.OnboardingStep) -> Bool {
        return currentStep == step
    }

    private func isCompleted(_ step: OnboardingView.OnboardingStep) -> Bool {
        switch (step, currentStep) {
        case (.welcome, .driverInstall), (.welcome, .instructions), (.welcome, .welcome):
            return currentStep != .welcome
        case (.driverInstall, .instructions):
            return currentStep == .instructions
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

// MARK: Envelope visuals

private struct EnvelopeView: View {
    let formattedDate: String

    private let brandColor = Color(red: 0.68, green: 0.36, blue: 0.28)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.12), radius: 16, y: 10)
                    .shadow(color: .black.opacity(0.06), radius: 6, y: 2)

                // Corner decorations - fixed to envelope corners
                ZStack(alignment: .topLeading) {
                    // Top-left stamp
                    topLeftStamp
                        .offset(x: 50, y: 50)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                    // Bottom-left asset
                    if let bottomLeftImage = loadImage(named: "RadioformBottomLeft") {
                        Image(nsImage: bottomLeftImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 200)
                            .offset(x: -10, y: 40)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    }

                    // Top-right asset
                    if let topRightImage = loadImage(named: "RadioformTopRight") {
                        Image(nsImage: topRightImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 240)
                            .offset(x: 40, y: -40)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }

                    // Bottom-right asset
                    if let bottomRightImage = loadImage(named: "RadioformBottomRight") {
                        Image(nsImage: bottomRightImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 220)
                            .offset(x: 20, y: 40)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    }
                }
                .padding(24)
            }
            .allowsHitTesting(false)
        }
    }

    private func loadImage(named: String) -> NSImage? {
        // Try to load from bundle resources
        if let url = Bundle.module.url(forResource: named, withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return nil
    }

    private var topLeftStamp: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FROM: THE PAVLOS COMPANY RSA")
            Text("DATE: \(formattedDate)")
        }
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(.black)
        .overlay(alignment: .bottomLeading) {
            Rectangle()
                .fill(Color.black.opacity(0.1))
                .frame(height: 1)
                .offset(y: 6)
        }
    }
}
