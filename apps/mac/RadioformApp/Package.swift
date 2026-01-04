// swift-tools-version: 5.9
import PackageDescription

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
            ]
        )
    ]
)
