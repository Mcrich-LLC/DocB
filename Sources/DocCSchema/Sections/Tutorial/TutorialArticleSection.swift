// The body content of a free-standing Tutorial Article page.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Tutorial Article/TutorialArticleSection.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: the `ContentLayout` type is split into its own file. The RenderJSONDiffable
// conformance is removed.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// A Tutorial Article section.
public struct TutorialArticleSection: RenderSection, Equatable {

    public let kind: RenderSectionKind = .articleBody

    /// The contents of the Tutorial Article.
    public var content: [ContentLayout] = []

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = try container.decodeIfPresent([ContentLayout].self, forKey: .content) ?? []
    }

    /// Creates a tutorial article section from a given list
    /// of content layout items.
    ///
    /// - Parameter content: The content for this section.
    public init(content: [ContentLayout]) {
        self.content = content
    }
}
