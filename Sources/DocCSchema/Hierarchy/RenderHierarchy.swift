// Hierarchical information for a render node: either an API reference hierarchy or a tutorials hierarchy.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Navigation Tree/RenderHierarchy.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Extended: `homepage` case for developer.apple.com payloads (see AppleDeveloper/).
// Trimmed: the `decoder.registerReferences(...)` calls in `init(from:)` are removed (they fed the
// variant-patch reference tracker, which is outside this package's copy set), and the
// RenderJSONDiffable conformance is removed.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// Hierarchical information for a render node.
///
/// A render node's hierarchy information, such as its parent topics,
/// describes an API reference hierarchy that starts with a framework
/// landing page, or a Tutorials hierarchy that starts with a Tutorials landing page.
/// ## Topics
/// ### Hierarchy Types
/// - ``RenderReferenceHierarchy``
/// - ``RenderTutorialsHierarchy``
public enum RenderHierarchy: Codable, Equatable {
    /// The hierarchy for an API reference render node.
    case reference(RenderReferenceHierarchy)
    /// The hierarchy for tutorials-related render node.
    case tutorials(RenderTutorialsHierarchy)
    // AppleDeveloper:
    /// The hierarchy for the developer.apple.com homepage and technologies catalog. Not part of upstream DocC.
    case homepage(RenderHomepageHierarchy)
    // Tolerant:
    /// A hierarchy of a shape this version of the schema does not know, preserved verbatim.
    case unknown(JSON)

    public init(from decoder: any Decoder) throws {
        // AppleDeveloper: `homepageNavigation` is a key neither upstream hierarchy has, so try it first.
        if let homepageHierarchy = try? RenderHomepageHierarchy(from: decoder) {
            self = .homepage(homepageHierarchy)
            return
        }
        if let tutorialsHierarchy = try? RenderTutorialsHierarchy(from: decoder) {
            self = .tutorials(tutorialsHierarchy)
            return
        }

        if let referenceHierarchy = try? RenderReferenceHierarchy(from: decoder) {
            self = .reference(referenceHierarchy)
            return
        }
        // Tolerant:
        self = .unknown(try JSON(from: decoder))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .reference(let hierarchy):
            try container.encode(hierarchy)
        case .tutorials(let hierarchy):
            try container.encode(hierarchy)
        // AppleDeveloper:
        case .homepage(let hierarchy):
            try container.encode(hierarchy)
        // Tolerant:
        case .unknown(let json):
            try container.encode(json)
        }
    }
}
