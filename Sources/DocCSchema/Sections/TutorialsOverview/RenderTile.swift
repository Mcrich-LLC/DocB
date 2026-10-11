// A render-friendly tile that links to a specific kind of resource, such as sample code or videos.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Tutorials Overview/Resources/RenderTile.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Tolerant: string enums keep unrecognised raw values in an `unknown` case instead of failing to decode.
// Trimmed: the TextIndexing conformance, the `Identifier.init(tileIdentifier:)` initializer, and
// the `defaultCallToActionTitle(for:)` extension method are removed; all referenced the semantic
// `Tile` type, which is outside this package's copy set.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// A render-friendly representation of a view that links
/// to a specified type of content.
///
/// Depending on its type, a render tile contains links to a
/// specific kind of resource such as sample code, videos,
/// or forum topics.
public struct RenderTile: Codable, Equatable {
    /// Predefined semantic tile identifiers.
    public enum Identifier: TolerantStringEnum {
        /// Identifies a tile that links to featured content.
        case featured

        /// Identifies a tile that links to documentation.
        case documentation

        /// Identifies a tile that links to sample code.
        case sampleCode

        /// Identifies a tile that links to downloads.
        case downloads

        /// Identifies a tile that links to videos.
        case videos

        /// Identifies a tile that links to forum topics.
        case forums

        /// A value this version of the schema does not know. The raw string is preserved and re-encoded unchanged.
        case unknown(String)

        public init(rawValue: String) {
            switch rawValue {
            case "featured": self = .featured
            case "documentation": self = .documentation
            case "sampleCode": self = .sampleCode
            case "downloads": self = .downloads
            case "videos": self = .videos
            case "forums": self = .forums
            default: self = .unknown(rawValue)
            }
        }

        public var rawValue: String {
            switch self {
            case .featured: "featured"
            case .documentation: "documentation"
            case .sampleCode: "sampleCode"
            case .downloads: "downloads"
            case .videos: "videos"
            case .forums: "forums"
            case .unknown(let rawValue): rawValue
            }
        }
    }

    /// The type of tile.
    ///
    /// Use this identifier to determine the tile's type during layout.
    public var identifier: RenderTile.Identifier

    /// The tile's title.
    public var title: String

    /// The main content of the tile.
    public var content: [RenderBlockContent] = []

    /// The tile's call-to-action content, if any.
    public var action: RenderInlineContent?

    /// A reference to the tile's media content, if any.
    public var media: RenderReferenceIdentifier?

    /// Creates a new tile from the given parameters.
    ///
    /// - Parameters:
    ///   - identifier: The type of tile.
    ///   - title: The tile's title.
    ///   - content: The main content for the tile.
    ///   - action: The tile's call-to-action content.
    ///   - media: A reference to the tile's media content.
    public init(identifier: RenderTile.Identifier, title: String, content: [RenderBlockContent] = [], action: RenderInlineContent?, media: RenderReferenceIdentifier?) {
        self.identifier = identifier
        self.title = title
        self.content = content
        self.action = action
        self.media = media
    }
}
