// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "DocB",
    platforms: [.macOS(.v15), .iOS(.v18), .visionOS(.v2)],
    products: [
        .library(name: "DocCSchema", targets: ["DocCSchema"]),
        .library(name: "DocBSources", targets: ["DocBSources"]),
        .library(name: "DocBStore", targets: ["DocBStore"]),
        .library(name: "DocBPage", targets: ["DocBPage"]),
        .library(name: "DocBMarkdown", targets: ["DocBMarkdown"]),
        .library(name: "DocBRender", targets: ["DocBRender"]),
        .executable(name: "docb", targets: ["docb"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        // Codable copies of DocC's render JSON and navigator index types. No dependencies.
        .target(name: "DocCSchema", exclude: ["AppleDeveloper/README.md"]),
        .testTarget(name: "DocCSchemaTests", dependencies: ["DocCSchema"]),

        // Source discovery (catalog vs. standalone archive) and URL mapping.
        .target(name: "DocBSources", dependencies: ["DocCSchema"]),
        .testTarget(name: "DocBSourcesTests", dependencies: ["DocBSources"]),

        // Offline store, sync engine, and FTS search over archives.
        .target(
            name: "DocBStore",
            dependencies: [
                "DocCSchema",
                "DocBSources",
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .testTarget(name: "DocBStoreTests", dependencies: ["DocBStore"]),

        // The page model: what a page says, built once from render JSON with references resolved.
        // Foundation only, so every renderer and the CLI share it.
        .target(name: "DocBPage", dependencies: ["DocCSchema"]),
        .testTarget(name: "DocBPageTests", dependencies: ["DocBPage"]),

        // Page to Markdown, for the CLI.
        .target(name: "DocBMarkdown", dependencies: ["DocBPage"]),
        .testTarget(name: "DocBMarkdownTests", dependencies: ["DocBMarkdown", "DocCSchema"]),

        // The web renderer's syntax highlighter, highlight.js, in JavaScriptCore. The bundle is
        // built by Tools/highlight/build.sh.
        .target(name: "DocBHighlight", resources: [.copy("highlight.min.js")], linkerSettings: [.linkedFramework("JavaScriptCore")]),
        .testTarget(name: "DocBHighlightTests", dependencies: ["DocBHighlight"]),

        // Page to a TextKit 2 document in a SwiftUI view that reflows like a browser.
        // AVKit named here: the app picks the package up as a static library, and the frameworks
        // its modules import do not reach the app's link line on their own.
        .target(name: "DocBRender", dependencies: ["DocBPage", "DocBHighlight"], linkerSettings: [.linkedFramework("AVKit"), .linkedFramework("QuickLook")]),
        .testTarget(name: "DocBRenderTests", dependencies: ["DocBRender"]),

        // CLI: the first client of the store, and its verification harness.
        .executableTarget(
            name: "docb",
            dependencies: [
                "DocCSchema",
                "DocBSources",
                "DocBStore",
                "DocBPage",
                "DocBMarkdown",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
    ]
)
