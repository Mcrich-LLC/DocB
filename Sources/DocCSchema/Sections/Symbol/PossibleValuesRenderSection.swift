// A render section listing a pre-defined set of possible values for a symbol, such as
// a property list key's allowed values.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Symbol/PossibleValuesRenderSection.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: the RenderJSONDiffable conformances (on this type and on `NamedValue`) are removed.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

import Foundation

/// A section that lists a pre-defined list of possible values for a given symbol.
///
/// For example, a property list key setting a target platform has allowed values of: "ppc", "i386", and "arm".
public struct PossibleValuesRenderSection: RenderSection, Equatable {
    /// A named value and optional details content.
    ///
    /// Some values are self-explanatory in their context like "2" or "Info.plist". For values
    /// that are not, provide additional details like so:
    /// - name: "Default"
    /// - content: Use "Default" to load the first-available instance.
    public struct NamedValue: Codable, Equatable {
        /// The value name.
        public let name: String
        /// Details content, if any.
        public let content: [RenderBlockContent]?
    }

    public var kind: RenderSectionKind = .possibleValues
    /// The title for the section, `nil` by default.
    public var title: String?
    /// The list of named values.
    public var values: [NamedValue]

    /// Creates a new possible values section.
    /// - Parameter title: The section title.
    /// - Parameter values: The list of values for this section.
    public init(title: String, values: [NamedValue]) {
        self.title = title
        self.values = values
    }

    // MARK: - Codable

    /// The list of keys you use to encode or decode this section.
    public enum CodingKeys: String, CodingKey {
        case kind, title, values
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        values = try container.decode([NamedValue].self, forKey: .values)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(title, forKey: .title)
        try container.encode(values, forKey: .values)
    }
}
