// A section of documentation content, holding arbitrary block content under a
// specific render section kind.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Symbol/ContentRenderSection.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: the `heading` parameter of `init(kind:content:heading:)` is removed, since its
// insertion of a heading block used `urlReadableFragment(_:)`, a free function outside the
// copy set; the RenderJSONDiffable conformance is also removed.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// A section of documentation content.
public struct ContentRenderSection: RenderSection, Equatable {
    public let kind: RenderSectionKind

    /// Arbitrary content for this section.
    public var content: [RenderBlockContent]

    /// Creates a new content section
    /// - Parameters:
    ///   - kind: The kind of the new section.
    ///   - content: Arbitrary rendering content.
    public init(kind: RenderSectionKind, content: [RenderBlockContent]) {
        self.kind = kind
        self.content = content
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(RenderSectionKind.self, forKey: .kind)
        content = try container.decode([RenderBlockContent].self, forKey: .content)
    }
}
