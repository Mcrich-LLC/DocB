// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DocBCore",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "DocBCore",
            targets: ["DocBCore"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Mcrich23/EnhancedCodable", branch: "main"),
        .package(url: "https://github.com/Mcrich23/PrivateObfuscationMacro", branch: "main"),
        .package(url: "https://github.com/appstefan/HighlightSwift", from: "1.0.9"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "8.0.3"),
        .package(url: "https://github.com/kean/Nuke.git", from: "12.9.0"),
        .package(url: "https://github.com/SFSafeSymbols/SFSafeSymbols", from: "5.3.0"),
        .package(url: "https://github.com/krzyzanowskim/STTextView.git", from: "2.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "DocBCore",
            dependencies: ["EnhancedCodable", "PrivateObfuscationMacro", "HighlightSwift", "Kingfisher", "Nuke", .product(name: "NukeUI", package: "Nuke"), "SFSafeSymbols", "STTextView"],
            resources: [
                .process("Resources") // Processes all files in this folder
            ]
        )
    ]
)
