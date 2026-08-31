// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "SpaceDownload",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "SpaceDownload", targets: ["SpaceDownload"]),
    ],
    targets: [
        .executableTarget(
            name: "SpaceDownload",
            path: "Sources/SpaceDownload",
            exclude: ["Resources"]
        ),
        .testTarget(
            name: "SpaceDownloadTests",
            dependencies: ["SpaceDownload"],
            path: "Tests/SpaceDownloadTests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
