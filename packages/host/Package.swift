// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RadioformHost",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "CRadioformAudio",
            path: "Sources/CRadioformAudio",
            publicHeadersPath: "include"
        ),
        .target(
            name: "CRadioformDSP",
            path: "Sources/CRadioformDSP",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "RadioformHost",
            dependencies: ["CRadioformAudio", "CRadioformDSP"],
            linkerSettings: [
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("CoreFoundation"),
                .linkedLibrary("c++"),
                .unsafeFlags([
                    "-L../dsp/build",
                    "-lradioform_dsp"
                ])
            ]
        ),
    ]
)
