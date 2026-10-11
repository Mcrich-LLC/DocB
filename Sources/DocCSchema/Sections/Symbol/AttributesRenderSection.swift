// A render section that contains a list of renderable symbol attributes, such as
// default values, minimums/maximums, and possible values or types.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Symbol/AttributesRenderSection.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: the RenderJSONDiffable conformance is removed.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

import Foundation

/// A section that contains a list of attributes.
public struct AttributesRenderSection: RenderSection, Equatable {
    public var kind: RenderSectionKind = .attributes
    /// The section title.
    public var title: String
    /// The list of attributes in this section.
    public var attributes: [RenderAttribute]?

    /// Creates a new attributes section.
    /// - Parameter title: The section title.
    /// - Parameter attributes: The list of attributes.
    public init(title: String, attributes: [RenderAttribute]) {
        self.title = title
        self.attributes = attributes
    }

    // MARK: - Codable

    /// The list of keys you use to encode or decode the section data.
    public enum CodingKeys: String, CodingKey {
        case kind, title, attributes
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        attributes = try container.decodeIfPresent([RenderAttribute].self, forKey: .attributes)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(attributes, forKey: .attributes)
    }
}
