// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DocB",
    platforms: [.macOS(.v15), .iOS(.v18), .visionOS(.v2)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "DocBCore",
            targets: ["DocBCore"]
        ),
        .library(
            name: "DocCKit",
            targets: ["DocCKit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Mcrich23/EnhancedCodable", branch: "main"),
        .package(url: "https://github.com/appstefan/HighlightSwift", from: "1.0.9"),
        .package(url: "https://github.com/mufasaYC/MYCloudKit.git", branch: "feat/codable-record-value"),
        .package(url: "https://github.com/kean/Nuke.git", from: "12.9.0"),
        .package(url: "https://github.com/SFSafeSymbols/SFSafeSymbols", from: "7.0.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.3.0"),
        .package(url: "https://github.com/simonbs/SFSymbols", from: "1.5.0"),
        .package(url: "https://github.com/hmlongco/Factory", from: "3.0.0"),
    ],
    targets: [
        // MARK: - DocBCore
        .target(
            name: "DocBCore",
            dependencies: [
                "EnhancedCodable",
                .product(name: "FactoryKit", package: "Factory"),
                "HighlightSwift",
                "MYCloudKit",
                "Nuke",
                .product(name: "NukeUI", package: "Nuke"),
                "SFSafeSymbols",
                "SFSymbols",
                "DocCKit"
            ],
            path: "Packages/DocBCore/Sources",
            resources: [
                .process("Resources") // Processes all files in this folder
            ]
        ),
        .testTarget(
            name: "DocBCoreTests",
            dependencies: ["DocBCore", "MYCloudKit", "DocCKit"],
            path: "Packages/DocBCore/Tests"
        ),
        
        // MARK: - DocCKit
        .target(
            name: "DocCKit",
            dependencies: [
                "EnhancedCodable",
                "SFSafeSymbols",
                "HighlightSwift",
                "Nuke",
                .product(name: "NukeUI", package: "Nuke"),
            ],
            path: "Packages/DocCKit/Sources"
        ),
        .testTarget(
            name: "DocCKitTests",
            dependencies: ["DocCKit"],
            path: "Packages/DocCKit/Tests"
        ),
    ]
)
