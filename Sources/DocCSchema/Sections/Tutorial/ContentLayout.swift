// The layout choices available for a block of content inside a Tutorial Article section.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Tutorial Article/TutorialArticleSection.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Tolerant: string enums keep unrecognised raw values in an `unknown` case instead of failing to decode.
// Trimmed: split out of `TutorialArticleSection.swift`, which declared this type alongside it.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// The layout in which the content should be presented.
public enum ContentLayout: Equatable {
    /// A full-width layout.
    case fullWidth(content: [RenderBlockContent])

    /// A layout for a piece of media that has an attached description.
    case contentAndMedia(content: ContentAndMediaSection)

    /// A multi-column layout.
    case columns(content: [ContentAndMediaSection])

    /// A layout whose `kind` this version of the schema does not know, preserved verbatim.
    case unknown(JSON)
}

extension ContentLayout: Codable {
    private enum CodingKeys: CodingKey {
        case kind
        case content
    }

    private enum LayoutKind: TolerantStringEnum {
        case fullWidth, contentAndMedia, columns

        /// A value this version of the schema does not know. The raw string is preserved and re-encoded unchanged.
        case unknown(String)

        internal init(rawValue: String) {
            switch rawValue {
            case "fullWidth": self = .fullWidth
            case "contentAndMedia": self = .contentAndMedia
            case "columns": self = .columns
            default: self = .unknown(rawValue)
            }
        }

        internal var rawValue: String {
            switch self {
            case .fullWidth: "fullWidth"
            case .contentAndMedia: "contentAndMedia"
            case .columns: "columns"
            case .unknown(let rawValue): rawValue
            }
        }
    }

    private var kind: LayoutKind {
        switch self {
        case .fullWidth: return .fullWidth
        case .contentAndMedia: return .contentAndMedia
        case .columns: return .columns
        case .unknown(let json):
            if case .dictionary(let object) = json, case .string(let kind)? = object["kind"] {
                return .unknown(kind)
            }
            return .unknown("")
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(LayoutKind.self, forKey: .kind)

        switch kind {
        case .fullWidth:
            self = try .fullWidth(content: container.decode([RenderBlockContent].self, forKey: .content))
        case .contentAndMedia:
            self = .contentAndMedia(content: try ContentAndMediaSection(from: decoder))
        case .columns:
            self = try .columns(content: container.decode([ContentAndMediaSection].self, forKey: .content))
        case .unknown:
            self = .unknown(try JSON(from: decoder))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        if case .unknown(let json) = self {
            try json.encode(to: encoder)
            return
        }

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)

        switch self {
        case .fullWidth(let content):
            try container.encode(content, forKey: .content)
        case .contentAndMedia(let content):
            try content.encode(to: encoder)
        case .columns(let content):
            try container.encode(content, forKey: .content)
        case .unknown:
            break // Handled above.
        }
    }
}
