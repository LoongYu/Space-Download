// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SpaceDownloadNative",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "SpaceDownloadNative", targets: ["SpaceDownloadNative"]),
    ],
    targets: [
        .executableTarget(
            name: "SpaceDownloadNative",
            path: "Sources/SpaceDownloadNative"
        ),
        .testTarget(
            name: "SpaceDownloadNativeTests",
            dependencies: ["SpaceDownloadNative"],
            path: "Tests/SpaceDownloadNativeTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
