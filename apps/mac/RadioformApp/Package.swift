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
    targets: [
        .executableTarget(
            name: "RadioformApp",
            dependencies: [],
            path: "Sources",
            resources: [
                .copy("Resources")
            ]
        )
    ]
)
