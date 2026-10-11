// A navigation index of the content in a DocC archive, optimized for rendering, and its
// nested per-page `Node` type.
//
// Copied from swift-docc `Sources/SwiftDocC/Indexing/RenderIndexJSON/RenderIndex.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: fromNavigatorIndex/fromNavigatorTreeNode, the NavigatorIndex.PageType extension,
// merge(_:) and MergeError, insertRoot(named:), and the Node initializer that took a
// NavigatorIndex.PageType — all of which required NavigatorIndex or SymbolGraph.
//
// Copyright (c) 2022-2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// A navigation index of the content in a DocC archive, optimized for rendering.
///
/// The structure of this data is determined by the topic groups authored in
/// the processed documentation content.
///
/// This is an alternative representation of the data that is also handled by the
/// ``NavigatorIndex`` in a ``NavigatorTree``. This index is specifically designed to be emitted
/// to disk as JSON file and implements the RenderIndex JSON spec.
///
/// An OpenAPI specification for RenderIndex is available in the repo at
/// `Sources/SwiftDocC/SwiftDocC.docc/Resources/RenderIndex.spec.json`.
public struct RenderIndex: Codable, Equatable {
    /// The current schema version of the Index JSON spec.
    public static let currentSchemaVersion = SemanticVersion(major: 0, minor: 1, patch: 2)

    /// The version of the RenderIndex spec that was followed when creating this index.
    public let schemaVersion: SemanticVersion

    /// A mapping of interface languages to the index nodes they contain.
    public private(set) var interfaceLanguages: [String: [Node]]

    /// The values of the image references used in the documentation index.
    public private(set) var references: [String: ImageReference]

    /// The unique identifiers of the archives that are included in the documentation index.
    public private(set) var includedArchiveIdentifiers: [String]

    internal enum CodingKeys: CodingKey {
        case schemaVersion
        case interfaceLanguages
        case references
        case includedArchiveIdentifiers
    }

    /// Creates a new render index with the given interface language to node mapping.
    public init(
        interfaceLanguages: [String: [Node]],
        references: [String: ImageReference] = [:],
        includedArchiveIdentifiers: [String]
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.interfaceLanguages = interfaceLanguages
        self.references = references
        self.includedArchiveIdentifiers = includedArchiveIdentifiers
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.schemaVersion, forKey: .schemaVersion)
        try container.encode(self.interfaceLanguages, forKey: .interfaceLanguages)
        try container.encodeIfNotEmpty(self.references, forKey: .references)
        try container.encodeIfNotEmpty(self.includedArchiveIdentifiers, forKey: .includedArchiveIdentifiers)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try container.decode(SemanticVersion.self, forKey: .schemaVersion)
        self.interfaceLanguages = try container.decode([String : [RenderIndex.Node]].self, forKey: .interfaceLanguages)
        self.references = try container.decodeIfPresent([String : ImageReference].self, forKey: .references) ?? [:]
        self.includedArchiveIdentifiers = try container.decodeIfPresent([String].self.self, forKey: .includedArchiveIdentifiers) ?? []
    }
}

extension RenderIndex {
    /// A documentation node in a documentation render index.
    public struct Node: Codable, Hashable {
        /// The title of the node, suitable for presentation.
        public let title: String

        /// The relative path to the page represented by this node.
        public let path: String?

        /// The type of this node.
        ///
        /// This type can be used to determine what icon to display for this node.
        public let type: String?

        /// The children of this node.
        public let children: [Node]?

        /// A Boolean value that is true if the current node has been marked as deprecated on any platform.
        ///
        /// Allows renderers to use a specific design treatment for render index nodes that mark the node as deprecated.
        public let isDeprecated: Bool

        /// A Boolean value that is true if the current node belongs to an external
        /// documentation archive.
        ///
        /// Allows renderers to use a specific design treatment for render index nodes
        /// that lead to external documentation content.
        public let isExternal: Bool

        /// A Boolean value that is true if the current node has been marked as is beta
        ///
        /// Allows renderers to use a specific design treatment for render index nodes that mark the node as in beta.
        public let isBeta: Bool

        /// A reference to a custom image for this node.
        public let icon: RenderReferenceIdentifier?

        internal enum CodingKeys: String, CodingKey {
            case title
            case path
            case type
            case children
            case deprecated
            case external
            case beta
            case icon
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(title, forKey: .title)

            try container.encodeIfPresent(path, forKey: .path)
            try container.encodeIfPresent(type, forKey: .type)
            try container.encodeIfPresent(children, forKey: .children)

            // `isDeprecated` defaults to false so only encode it if it's true
            if isDeprecated {
                try container.encode(isDeprecated, forKey: .deprecated)
            }

            // `isExternal` defaults to false so only encode it if it's true
            if isExternal {
                try container.encode(isExternal, forKey: .external)
            }

            // `isBeta` defaults to false so only encode it if it's true
            if isBeta {
                try container.encode(isBeta, forKey: .beta)
            }

            try container.encodeIfPresent(icon, forKey: .icon)
        }

        public init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)

            title = try values.decode(String.self, forKey: .title)

            path = try values.decodeIfPresent(String.self, forKey: .path)
            type = try values.decodeIfPresent(String.self, forKey: .type)
            children = try values.decodeIfPresent([Node].self, forKey: .children)

            // `isDeprecated` defaults to false if it's not specified
            isDeprecated = try values.decodeIfPresent(Bool.self, forKey: .deprecated) ?? false

            // `isExternal` defaults to false if it's not specified
            isExternal = try values.decodeIfPresent(Bool.self, forKey: .external) ?? false

            // `isBeta` defaults to false if it's not specified
            isBeta = try values.decodeIfPresent(Bool.self, forKey: .beta) ?? false

            icon = try values.decodeIfPresent(RenderReferenceIdentifier.self, forKey: .icon)
        }

        /// Creates a new node with the given title, path, type, and children.
        ///
        /// - Parameters:
        ///   - title: The title of the node, suitable for presentation.
        ///   - path: The relative path to the page represented by this node.
        ///   - type: The type of this node.
        ///   - children: The children of this node.
        ///   - isDeprecated: If the current node has been marked as deprecated.
        ///   - isExternal: If the current node belongs to an external
        ///     documentation archive.
        ///   - isBeta: If the current node is in beta.
        ///   - icon: A reference to a custom image for this node.
        public init(
            title: String,
            path: String?,
            type: String?,
            children: [Node]?,
            isDeprecated: Bool,
            isExternal: Bool,
            isBeta: Bool,
            icon: RenderReferenceIdentifier? = nil
        ) {
            self.title = title
            self.path = path
            self.type = type
            self.children = children
            self.isDeprecated = isDeprecated
            self.isExternal = isExternal
            self.isBeta = isBeta
            self.icon = icon
        }
    }
}
