// A section containing textual content and media laid out horizontally or vertically.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Tutorials Overview/Sections/ContentAndMediaSection.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Tolerant: string enums keep unrecognised raw values in an `unknown` case instead of failing to decode.
// Trimmed: the RenderJSONDiffable conformance is removed. The `mediaPosition` property was typed
// `ContentAndMedia.MediaPosition`, referencing the semantic `ContentAndMedia` type, which is
// outside this package's copy set; its `MediaPosition` enum is nested here instead, matching this
// file's existing `Layout` nesting.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// A section containing textual content and media laid out horizontally or vertically.
public struct ContentAndMediaSection: RenderSection, Equatable {
    public var kind: RenderSectionKind = .contentAndMedia

    /// The layout direction.
    public var layout: Layout?

    /// The title of the section.
    public var title: String?

    /// Text to display above the title.
    public var eyebrow: String?

    /// The body content of the section.
    public var content: [RenderBlockContent] = []

    /// An image or video to display opposite the text.
    public var media: RenderReferenceIdentifier?

    /// Whether the media comes before or after the text when read from top to bottom or leading to trailing.
    public var mediaPosition: MediaPosition

    /// The kind of layout to use when rendering a section.
    /// Content is always leading, and media is always trailing.
    public enum Layout: TolerantStringEnum {
        /// Content should be laid out horizontally, with the media on the trailing side.
        case horizontal
        /// Content should be laid out vertically, with the media trailing the content.
        case vertical

        /// A value this version of the schema does not know. The raw string is preserved and re-encoded unchanged.
        case unknown(String)

        public init(rawValue: String) {
            switch rawValue {
            case "horizontal": self = .horizontal
            case "vertical": self = .vertical
            default: self = .unknown(rawValue)
            }
        }

        public var rawValue: String {
            switch self {
            case .horizontal: "horizontal"
            case .vertical: "vertical"
            case .unknown(let rawValue): rawValue
            }
        }
    }

    /// The visual position of a piece of media in relation to its prose content.
    public enum MediaPosition: TolerantStringEnum {
        /// The media's position is at the leading, or front, edge of the prose content.
        case leading

        /// The media's position is at the trailing, or rear, edge of the prose content.
        case trailing

        /// A value this version of the schema does not know. The raw string is preserved and re-encoded unchanged.
        case unknown(String)

        public init(rawValue: String) {
            switch rawValue {
            case "leading": self = .leading
            case "trailing": self = .trailing
            default: self = .unknown(rawValue)
            }
        }

        public var rawValue: String {
            switch self {
            case .leading: "leading"
            case .trailing: "trailing"
            case .unknown(let rawValue): rawValue
            }
        }
    }

    /// Creates a new content and media section from the given parameters.
    ///
    /// - Parameters:
    ///   - layout: The layout direction for the section.
    ///   - title: The title of the section.
    ///   - media: A reference to a media item for the section.
    ///   - mediaPosition: The position of the media in relation to the prose content.
    public init(layout: Layout?, title: String?, media: RenderReferenceIdentifier?, mediaPosition: MediaPosition) {
        self.layout = layout
        self.title = title
        self.media = media
        self.mediaPosition = mediaPosition
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        kind = try container.decodeIfPresent(RenderSectionKind.self, forKey: .kind) ?? .contentAndMedia
        layout = try container.decodeIfPresent(Layout.self, forKey: .layout)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        eyebrow = try container.decodeIfPresent(String.self, forKey: .eyebrow)
        content = try container.decodeIfPresent([RenderBlockContent].self, forKey: .content) ?? []
        media = try container.decodeIfPresent(RenderReferenceIdentifier.self, forKey: .media)
        mediaPosition = try container.decodeIfPresent(MediaPosition.self, forKey: .mediaPosition)
        // Provide backwards-compatibility for ContentAndMediaSections that don't have a `mediaPosition` key.
        ?? .leading
    }
}
