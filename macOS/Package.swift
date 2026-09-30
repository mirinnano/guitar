// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "GuitarToolsMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "GuitarToolsCore",
            targets: ["GuitarToolsCore"]
        ),
        .executable(
            name: "GuitarToolsMacApp",
            targets: ["GuitarToolsMacApp"]
        )
    ],
    targets: [
        .target(
            name: "GuitarToolsCore"
        ),
        .executableTarget(
            name: "GuitarToolsMacApp",
            dependencies: [
                "GuitarToolsCore"
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("AppKit"),
                .linkedFramework("CoreAudio")
            ]
        ),
        .testTarget(
            name: "GuitarToolsCoreTests",
            dependencies: [
                "GuitarToolsCore"
            ]
        )
    ]
)
