import SwiftUI
import AppKit

/// Memo card matching the web Card.tsx design
struct MemoCardView: View {
    let onContinue: () -> Void

    private let textColor = Color.black.opacity(0.9)
    private let labelColor = Color.black.opacity(0.7)

    private var todayFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: Date())
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main card
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 0) {
                    Text("FOR MUSIC LOVERS")
                        .font(.custom("IBM Plex Mono", size: 14))
                        .fontWeight(.bold)
                        .tracking(0)
                        .foregroundColor(textColor)
                        .padding(.bottom, 12)

                    // TO, FROM, DATE, RE fields
                    VStack(alignment: .leading, spacing: 2) {
                        MemoField(label: "TO:", value: "MacOS users")
                        MemoField(label: "FROM:", value: "The Pavlos Company RSA")
                        MemoField(label: "DATE:", value: todayFormatted)
                        MemoField(label: "RE:", value: "Quarterly Update")
                    }
                }
                .padding(.bottom, 16)

                // Divider
                Rectangle()
                    .fill(Color.black.opacity(0.85))
                    .frame(height: 1)
                    .padding(.bottom, 16)

                // Body text
                VStack(alignment: .leading, spacing: 12) {
                    Text("We know you've bought that new stereo system or headphones. We know you're excited. But it's time to take it to the next level. The level where your music starts to warm your ears like a hot shower. So let's make that happen.")
                        .font(.custom("IBM Plex Mono", size: 11))
                        .foregroundColor(textColor)
                        .lineSpacing(4)

                    Text("Introducing Radioform, the first EQ app that just works. It lives on your menubar, hidden away without interfering with your workflow. But it does interfere with how bad your music sounds, by making it sound so sweet like the Sirens from Odyssey.")
                        .font(.custom("IBM Plex Mono", size: 11))
                        .foregroundColor(textColor)
                        .lineSpacing(4)

                    Text("We built this project to be fully open sourced, so you know what you're getting into. Natively built in Swift, this app is a performant, lightweight way to enjoy your music the way it was meant to be. Seriously, give it a go.")
                        .font(.custom("IBM Plex Mono", size: 11))
                        .foregroundColor(textColor)
                        .lineSpacing(4)

                    Text("Take back control and learn what music can sound like once you really have got your hands dirty. Make your own custom EQ presets or use some of the pre-built ones. Optimize for your home stereo, your headphones, or even your MacBook. Radioform is for everyone.")
                        .font(.custom("IBM Plex Mono", size: 11))
                        .foregroundColor(textColor)
                        .lineSpacing(4)

                    // Continue button
                    Button(action: onContinue) {
                        Text("CONTINUE")
                            .font(.custom("IBM Plex Mono", size: 11))
                            .tracking(2)
                            .foregroundColor(Color.gray.opacity(0.7))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }

                Spacer()

                // Logo at bottom right
                HStack {
                    Spacer()
                    if let logoImage = loadImage(name: "pavlos", ext: "png") {
                        Image(nsImage: logoImage)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(1, contentMode: .fit)
                            .frame(width: 124, height: 124)
                            .rotationEffect(.degrees(-16))
                    }
                }
                .padding(.top, -96)
            }
            .padding(24)

            // Polaroid with paperclip at top right
            PolaroidAttachment()
                .offset(x: 48, y: -32)
        }
        .frame(width: 480, height: 679) // 1:1.414 aspect ratio
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
    }

    private func loadImage(name: String, ext: String) -> NSImage? {
        // Try bundle resources
        if let resourceBundleURL = Bundle.main.url(forResource: "RadioformApp_RadioformApp", withExtension: "bundle"),
           let resourceBundle = Bundle(url: resourceBundleURL),
           let imagePath = resourceBundle.url(forResource: name, withExtension: ext) {
            if let image = NSImage(contentsOf: imagePath) {
                return image
            }
        }

        // Try direct path
        if let executableURL = Bundle.main.executableURL {
            let bundlePath = executableURL
                .deletingLastPathComponent()
                .appendingPathComponent("RadioformApp_RadioformApp.bundle")
                .appendingPathComponent("Resources/\(name).\(ext)")
            if let image = NSImage(contentsOf: bundlePath) {
                return image
            }
        }

        // Development fallback
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? ""
        let devPath = "\(homeDir)/radioform/apps/mac/RadioformApp/Sources/Resources/\(name).\(ext)"
        if let image = NSImage(contentsOfFile: devPath) {
            return image
        }

        return nil
    }
}

/// Individual memo field row
struct MemoField: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(label)
                .font(.custom("IBM Plex Mono", size: 11))
                .foregroundColor(Color.black.opacity(0.9))
                .frame(width: 56, alignment: .leading)
            Text(value)
                .font(.custom("IBM Plex Mono", size: 11))
                .foregroundColor(Color.black.opacity(0.9))
        }
    }
}

/// Polaroid with paperclip attachment
struct PolaroidAttachment: View {
    var body: some View {
        ZStack {
            // Paperclip on top
            if let clipImage = loadImage(name: "paperclip", ext: "png") {
                Image(nsImage: clipImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64)
                    .rotationEffect(.degrees(-50))
                    .offset(x: -20, y: 12)
                    .zIndex(2)
            }

            // Polaroid frame
            ZStack {
                // White border
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)

                // Image inside
                if let photoImage = loadImage(name: "radioform", ext: "png") {
                    Image(nsImage: photoImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipped()
                        .padding(6)
                        .padding(.bottom, 20) // Extra bottom for polaroid look
                }
            }
            .frame(width: 92, height: 106)
            .rotationEffect(.degrees(5))
            .offset(y: 36)
        }
        .frame(width: 120, height: 140)
    }

    private func loadImage(name: String, ext: String) -> NSImage? {
        // Try bundle resources
        if let resourceBundleURL = Bundle.main.url(forResource: "RadioformApp_RadioformApp", withExtension: "bundle"),
           let resourceBundle = Bundle(url: resourceBundleURL),
           let imagePath = resourceBundle.url(forResource: name, withExtension: ext) {
            if let image = NSImage(contentsOf: imagePath) {
                return image
            }
        }

        // Try direct path
        if let executableURL = Bundle.main.executableURL {
            let bundlePath = executableURL
                .deletingLastPathComponent()
                .appendingPathComponent("RadioformApp_RadioformApp.bundle")
                .appendingPathComponent("Resources/\(name).\(ext)")
            if let image = NSImage(contentsOf: bundlePath) {
                return image
            }
        }

        // Development fallback
        let homeDir = ProcessInfo.processInfo.environment["HOME"] ?? ""
        let devPath = "\(homeDir)/radioform/apps/mac/RadioformApp/Sources/Resources/\(name).\(ext)"
        if let image = NSImage(contentsOfFile: devPath) {
            return image
        }

        return nil
    }
}

#Preview {
    MemoCardView(onContinue: {})
        .padding(50)
        .background(Color.gray.opacity(0.2))
}
