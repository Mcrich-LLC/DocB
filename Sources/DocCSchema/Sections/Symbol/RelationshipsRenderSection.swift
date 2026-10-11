// A render section that contains a list of symbol relationships of the same kind,
// such as "Conforms To" or "Inherits From".
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Symbol/RelationshipsRenderSection.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: `init(from:)`'s call to `decoder.registerReferences(_:)` (reference-count tracking
// used by RenderNodeTransformer, outside the copy set) is removed, along with the
// RenderJSONDiffable conformance.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

import Foundation

/// A section that contains a list of symbol relationships of the same kind.
public struct RelationshipsRenderSection: RenderSection, Equatable {
    public let kind: RenderSectionKind = .relationships

    /// A title for the section.
    public let title: String

    /// A list of references to the symbols that are related to the symbol.
    public let identifiers: [String]

    /// The type of relationship, e.g., "Conforms To".
    public let type: String

    /// Creates a new relationships section.
    /// - Parameters:
    ///   - type: The type of relationships in that section, for example, "Conforms To".
    ///   - title: The title for this section.
    ///   - identifiers: The list of related symbol references.
    public init(type: String, title: String, identifiers: [String]) {
        self.type = type
        self.title = title
        self.identifiers = identifiers
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        title = try container.decode(String.self, forKey: .title)
        identifiers = try container.decode([String].self, forKey: .identifiers)
    }
}
