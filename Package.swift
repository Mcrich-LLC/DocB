// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DocBCore",
    platforms: [.macOS(.v15), .iOS(.v18), .visionOS(.v2)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "DocBCore",
            targets: ["DocBCore"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Mcrich23/EnhancedCodable", branch: "main"),
        .package(url: "https://github.com/appstefan/HighlightSwift", from: "1.0.9"),
        .package(url: "https://github.com/kean/Nuke.git", from: "12.9.0"),
        .package(url: "https://github.com/SFSafeSymbols/SFSafeSymbols", from: "7.0.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.3.0"),
        .package(url: "https://github.com/simonbs/SFSymbols", from: "1.5.0"),
        .package(path: "DocCKit")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "DocBCore",
            dependencies: ["EnhancedCodable", "HighlightSwift", "Nuke", .product(name: "NukeUI", package: "Nuke"), "SFSafeSymbols", "SFSymbols", "DocCKit"],
            resources: [
                .process("Resources") // Processes all files in this folder
            ]
        )
    ]
)
