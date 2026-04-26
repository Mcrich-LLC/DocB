// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "DocCKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "DocCKit",
            targets: ["DocCKit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Mcrich23/EnhancedCodable", branch: "main"),
        .package(url: "https://github.com/appstefan/HighlightSwift", from: "1.0.9"),
        .package(url: "https://github.com/kean/Nuke.git", from: "12.9.0"),
        .package(url: "https://github.com/SFSafeSymbols/SFSafeSymbols", from: "7.0.0")
    ],
    targets: [
        .target(
            name: "DocCKit",
            dependencies: [
                "EnhancedCodable",
                "HighlightSwift",
                "Nuke",
                .product(name: "NukeUI", package: "Nuke"),
                "SFSafeSymbols"
            ]
        ),
        .testTarget(
            name: "DocCKitTests",
            dependencies: ["DocCKit"]
        )
    ]
)
