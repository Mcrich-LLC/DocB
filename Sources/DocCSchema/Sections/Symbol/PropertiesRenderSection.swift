// A render section that contains a list of properties, such as the members of a
// property list key or a REST body object.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Symbol/PropertiesRenderSection.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

import Foundation

/// A section that contains a list of properties.
///
/// Group ``RenderProperty`` properties in this section.
public struct PropertiesRenderSection: RenderSection {
    public var kind: RenderSectionKind = .properties
    /// The title for this section.
    public var title: String
    /// The list of properties.
    public var items: [RenderProperty]

    /// Creates a new property-list section.
    /// - Parameters:
    ///   - title: The title for this section.
    ///   - items: The list of properties.
    public init(title: String, items: [RenderProperty]) {
        self.title = title
        self.items = items
    }

    // MARK: - Codable

    /// The list of keys to use to encode/decode this section.
    public enum CodingKeys: String, CodingKey {
        case kind, title, items
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        items = try container.decode([RenderProperty].self, forKey: .items)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(title, forKey: .title)
        try container.encode(items, forKey: .items)
    }
}
