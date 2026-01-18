// swift-tools-version: 5.9
import PackageDescription
import Foundation

// Auto-detect macOS 26 SDK availability by checking the SDK version
// Set ENABLE_LIQUID_GLASS=1 environment variable to force enable
let liquidGlassAvailable: Bool = {
    // Check for explicit environment variable override
    if let envValue = ProcessInfo.processInfo.environment["ENABLE_LIQUID_GLASS"],
       envValue == "1" || envValue.lowercased() == "true" {
        return true
    }

    // Auto-detect by checking SDK version from xcrun
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
    task.arguments = ["--show-sdk-version"]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = FileHandle.nullDevice

    do {
        try task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let version = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
            // macOS 26.x SDK versions start with "26"
            return version.hasPrefix("26")
        }
    } catch {
        // If detection fails, assume not available
    }
    return false
}()

var swiftSettings: [SwiftSetting] = []
if liquidGlassAvailable {
    swiftSettings.append(.define("LIQUID_GLASS_AVAILABLE"))
}

let package = Package(
    name: "RadioformApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "RadioformApp",
            targets: ["RadioformApp"]
        )
    ],
    dependencies: [
        // Sparkle 2.x for auto-updates
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.5.0")
    ],
    targets: [
        .executableTarget(
            name: "RadioformApp",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources",
            resources: [
                .copy("Resources")
            ],
            swiftSettings: swiftSettings
        )
    ]
)
