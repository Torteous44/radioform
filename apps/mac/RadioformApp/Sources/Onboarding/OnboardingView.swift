import SwiftUI
import AppKit

/// Main onboarding view showing the envelope interface
struct OnboardingView: View {
    @ObservedObject var coordinator: OnboardingCoordinator

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color.white
                    .ignoresSafeArea()

                // Show the two-sided envelope with flip animation
                SkeuomorphicEnvelopeView(
                    formattedDate: formattedDate,
                    onComplete: {
                        // End onboarding - launches host and shows menu bar
                        coordinator.complete()
                    }
                )
            }
            .preferredColorScheme(.light) // keep white even in dark mode
        }
        .frame(minWidth: 800, minHeight: 600)
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



// MARK: - Skeuomorphic Envelope Components

/// Triangular envelope flap shape - points downward from top edge
struct EnvelopeFlapShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))                           // Top-left
        path.addLine(to: CGPoint(x: rect.width, y: 0))               // Top-right
        path.addLine(to: CGPoint(x: rect.width / 2, y: rect.height)) // Bottom-center apex
        path.closeSubpath()
        return path
    }
}

/// Skeuomorphic envelope view with two sides and flip animation
private struct SkeuomorphicEnvelopeView: View {
    let formattedDate: String
    let onComplete: () -> Void  // Called when installation completes

    // Animation state
    @State private var isFlipped = false
    @State private var envelopeOffsetX: CGFloat = 0
    @State private var showInstallUI = false
    @State private var showNextButton = false  // Fades in after entrance animation
    
    // Entrance animation state
    @State private var envelopeOffsetY: CGFloat = 300  // Start below screen
    @State private var envelopeScale: CGFloat = 0.95   // Start slightly smaller (1.05x increase)
    @State private var envelopeRotation: Double = -5   // Start with slight rotation
    
    // Hover state
    @State private var isHovered = false

    // Driver installation
    @StateObject private var installer = DriverInstaller()

    // Envelope colors
    private let envelopeCream = Color(red: 0.98, green: 0.96, blue: 0.91)
    private let envelopeDarkerCream = Color(red: 0.95, green: 0.92, blue: 0.85)
    private let borderColor = Color(red: 0.85, green: 0.80, blue: 0.70)
    private let textColor = Color(red: 0.15, green: 0.12, blue: 0.10)

    var body: some View {
        GeometryReader { geo in
            let envelopeWidth = min(geo.size.width * 0.7, 550)
            let envelopeHeight = envelopeWidth * 0.6
            let flapHeight = envelopeHeight * 0.5  // Larger flap

            ZStack {
                Color.white
                    .ignoresSafeArea()

                HStack(spacing: 0) {
                    // Envelope (slides left after flip)
                    ZStack {
                        // Front of envelope (no flap)
                        envelopeFront(width: envelopeWidth, height: envelopeHeight)
                            .opacity(isFlipped ? 0 : 1)
                            .rotation3DEffect(
                                .degrees(isFlipped ? 180 : 0),
                                axis: (x: 0, y: 1, z: 0),
                                perspective: 0.5
                            )

                        // Back of envelope (with flap)
                        envelopeBack(width: envelopeWidth, height: envelopeHeight, flapHeight: flapHeight)
                            .opacity(isFlipped ? 1 : 0)
                            .rotation3DEffect(
                                .degrees(isFlipped ? 0 : -180),
                                axis: (x: 0, y: 1, z: 0),
                                perspective: 0.5
                            )
                    }
                    .frame(width: envelopeWidth, height: envelopeHeight)
                    .scaleEffect(envelopeScale * (isHovered && !isFlipped ? 1.03 : 1.0))
                    .rotationEffect(.degrees(envelopeRotation + (isHovered && !isFlipped ? 2 : 0)))
                    .offset(x: envelopeOffsetX, y: envelopeOffsetY)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isHovered)
                    .onTapGesture {
                        if !isFlipped {
                            triggerFlipSequence(geo: geo)
                        }
                    }
                    .onHover { hovering in
                        if !isFlipped {
                            isHovered = hovering
                        }
                    }
                    .onAppear {
                        // Entrance animation: slide up, scale in, and rotate to level
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) {
                            envelopeOffsetY = 0
                            envelopeScale = 1.0
                            envelopeRotation = 0
                        }
                        
                        // Fade in Next button after entrance completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                            withAnimation(.easeIn(duration: 0.5)) {
                                showNextButton = true
                            }
                        }
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.leading, isFlipped ? 0 : (geo.size.width - envelopeWidth) / 2)

                // Install UI (fades in on the right)
                if showInstallUI {
                    installPromptView
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .padding(.leading, geo.size.width * 0.4)
                        .opacity(showInstallUI ? 1 : 0)
                }

                // Next button (only shown before flip, fades in after entrance)
                if showNextButton && !isFlipped {
                    VStack {
                        Spacer()
                        Button(action: {
                            triggerFlipSequence(geo: geo)
                        }) {
                            Text("Next →")
                                .underline()
                                .foregroundColor(.primary)
                        }
                        .keyboardShortcut(.return)
                        .buttonStyle(.plain)
                        .padding(.bottom, 40)
                        .opacity(showNextButton ? 1 : 0)
                    }
                }
                
            }
            .preferredColorScheme(.light)
        }
    }
    

    // MARK: - Flip Animation Sequence

    private func triggerFlipSequence(geo: GeometryProxy) {
        showNextButton = false

        // Step 1: Flip the envelope (show back)
        withAnimation(.easeInOut(duration: 0.6)) {
            isFlipped = true
        }
        
        // Step 2: Slide envelope left and show install UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.5)) {
                envelopeOffsetX = -geo.size.width * 0.25
            }

            withAnimation(.easeIn(duration: 0.4).delay(0.3)) {
                showInstallUI = true
            }
        }
    }

    // MARK: - Front of Envelope (no flap)

    @ViewBuilder
    private func envelopeFront(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            // Envelope body
            envelopeBody(width: width, height: height)

            // Content
            envelopeFrontContent(width: width, height: height)
        }
        .frame(width: width, height: height)
    }

    @ViewBuilder
    private func envelopeFrontContent(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            // Top-left: FROM, DATE, SUBJECT
            VStack(alignment: .leading, spacing: 8) {
                Text("FROM: THE PAVLOS COMPANY RSA")
                    .font(typewriterFont(size: 13))
                    .foregroundColor(textColor)
                Text("DATE: \(formattedDate)")
                    .font(typewriterFont(size: 13))
                    .foregroundColor(textColor)

                Text("SUBJECT: RADIOFORM")
                    .font(typewriterFont(size: 13))
                    .foregroundColor(textColor)
                    .padding(.top, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, 32)
            .padding(.leading, 32)

            // Top-right: Stamp
            if let stampImage = loadImage(named: "RadioformTopRight") {
                Image(nsImage: stampImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 90)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, 24)
                    .padding(.trailing, 24)
            }

            // Bottom-left: Logo
            if let logoImage = loadImage(named: "RadioformBottomRight") {
                Image(nsImage: logoImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.bottom, 20)
                    .padding(.leading, 20)
            }
        }
        .frame(width: width, height: height)
    }

    // MARK: - Back of Envelope (with flap overlapping body)

    @ViewBuilder
    private func envelopeBack(width: CGFloat, height: CGFloat, flapHeight: CGFloat) -> some View {
        ZStack {
            // Envelope body - no offset, flap overlaps it
            envelopeBody(width: width, height: height)

            // Triangular flap overlays the top portion - stays closed
            VStack(spacing: 0) {
                envelopeFlap(width: width, height: flapHeight)
                Spacer()
            }
            .frame(width: width, height: height)
            .zIndex(2)  // Flap on top

            // RADIOFORM text at bottom center
            Text("RADIOFORM")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(textColor.opacity(0.5))
                .tracking(3)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 16)
        }
        .frame(width: width, height: height)
    }

    // MARK: - Envelope Components

    @ViewBuilder
    private func envelopeBody(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            // Base envelope shape with gradient
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [envelopeCream, envelopeDarkerCream.opacity(0.9)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Outer border
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(borderColor.opacity(0.4), lineWidth: 1)

            // Decorative inner border
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .stroke(borderColor.opacity(0.3), lineWidth: 0.5)
                .padding(12)
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.12), radius: 16, y: 10)
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }

    @ViewBuilder
    private func envelopeFlap(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            EnvelopeFlapShape()
                .fill(
                    LinearGradient(
                        colors: [envelopeDarkerCream, envelopeCream],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            EnvelopeFlapShape()
                .stroke(borderColor.opacity(0.4), lineWidth: 0.5)
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
    }

    // MARK: - Install Prompt UI

    @ViewBuilder
    private var installPromptView: some View {
        VStack(alignment: .leading, spacing: 24) {
            if installer.state.isComplete {
                // Post-install instructions
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select Radioform from your\nsounds in settings")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                        .lineSpacing(4)
                    
                    // Instructions with SF Symbols
                    HStack(spacing: 6) {
                        Text("Go to")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        Image(systemName: "switch.2")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        
                        Text("Control Center")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        
                        Text("Sound")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }

                Button(action: {
                    onComplete()
                }) {
                    Text("Open Radioform →")
                        .underline()
                        .foregroundColor(.primary)
                }
                .keyboardShortcut(.return)
                .buttonStyle(.plain)
            } else {
                // Pre-install / installing
                VStack(alignment: .leading, spacing: 8) {
                    Text("To begin we need to\ninstall an audio driver")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                        .lineSpacing(4)
                    
                    Text("This enables Radioform to process your system audio")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    if installer.state != .notStarted {
                        Text(installer.state.description)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }

                    ProgressView(value: installer.progress)
                        .frame(width: 280)
                        .tint(Color.gray.opacity(0.65))
                }

                HStack(spacing: 12) {
                    if installer.state == .notStarted {
                        Button(action: {
                            installDriver()
                        }) {
                            Text("Install →")
                                .underline()
                                .foregroundColor(.primary)
                        }
                        .keyboardShortcut(.return)
                        .buttonStyle(.plain)
                    }

                    if installer.state.isFailed {
                        Button(action: {
                            installDriver()
                        }) {
                            Text("Retry →")
                                .underline()
                                .foregroundColor(.primary)
                        }
                        .keyboardShortcut(.return)
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(32)
        .onAppear {
            // Check if driver is already installed
            if installer.isDriverLoaded() {
                installer.state = .complete
                installer.progress = 1.0
            }
        }
    }

    private func installDriver() {
        Task {
            do {
                try await installer.installDriver()
                // Installation complete - UI will update to show instructions
                // User must click "Close" to finish onboarding
            } catch {
                await MainActor.run {
                    installer.state = .failed(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Helpers

    private func typewriterFont(size: CGFloat) -> Font {
        return .custom("American Typewriter", size: size)
    }

    private func loadImage(named: String) -> NSImage? {
        // Resources are packaged into the app bundle during bundling
        if let url = Bundle.main.url(forResource: named, withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return nil
    }
}
