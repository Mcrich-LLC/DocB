// Availability information for a symbol on a specific platform, as rendered in
// render JSON's availability sections.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Symbol/AvailabilityRenderMetadataItem.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: the SymbolGraph.Symbol.Availability.AvailabilityItem and Metadata.Availability
// inits (and the PlatformVersion-based isBeta(introduced:current:) helper they used) are
// removed, along with the SemanticVersion extension (stringRepresentation/Precision) that
// existed only to support them.
//
// Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

import Foundation

/// Availability information of a symbol on a specific platform.
public struct AvailabilityRenderItem: Codable, Hashable, Equatable {
    /// The name of the platform on which the symbol is available.
    public var name: String?

    /// The version of the platform SDK introducing the symbol.
    public var introduced: String?

    /// The version of the platform SDK deprecating the symbol.
    public var deprecated: String?

    /// The version of the platform SDK marking the symbol as obsolete.
    public var obsoleted: String?

    /// A message associated with the availability of the symbol.
    ///
    /// Use this property to provide a deprecation reason or instructions how to
    /// update code that uses this symbol.
    public var message: String?

    /// The new name of the symbol, if it was renamed.
    public var renamed: String?

    /// If `true`, the symbol is deprecated on this or all platforms.
    public var unconditionallyDeprecated: Bool?

    /// If `true`, the symbol is unavailable on this or all platforms.
    public var unconditionallyUnavailable: Bool?

    /// If `true`, the symbol is introduced in a beta version of this platform.
    public var isBeta: Bool?

    private enum CodingKeys: String, CodingKey {
        case name, introducedAt, deprecatedAt, obsoletedAt, message, renamed, deprecated, unavailable
        case beta
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        introduced = try container.decodeIfPresent(String.self, forKey: .introducedAt)
        deprecated = try container.decodeIfPresent(String.self, forKey: .deprecatedAt)
        obsoleted = try container.decodeIfPresent(String.self, forKey: .obsoletedAt)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        renamed = try container.decodeIfPresent(String.self, forKey: .renamed)
        unconditionallyDeprecated = try container.decodeIfPresent(Bool.self, forKey: .deprecated)
        unconditionallyUnavailable = try container.decodeIfPresent(Bool.self, forKey: .unavailable)
        isBeta = try container.decodeIfPresent(Bool.self, forKey: .beta)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(introduced, forKey: .introducedAt)
        try container.encodeIfPresent(deprecated, forKey: .deprecatedAt)
        try container.encodeIfPresent(obsoleted, forKey: .obsoletedAt)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encodeIfPresent(renamed, forKey: .renamed)
        try container.encodeIfPresent(unconditionallyDeprecated, forKey: .deprecated)
        try container.encodeIfPresent(unconditionallyUnavailable, forKey: .unavailable)
        try container.encodeIfPresent(isBeta, forKey: .beta)
    }

    internal init(
        name: String,
        introduced: String?,
        deprecated: String? = nil,
        obsoleted: String? = nil,
        message: String? = nil,
        renamed: String? = nil,
        unconditionallyDeprecated: Bool? = nil,
        unconditionallyUnavailable: Bool? = nil,
        isBeta: Bool
    ) {
        self.name = name
        self.introduced = introduced
        self.deprecated = deprecated
        self.obsoleted = obsoleted
        self.message = message
        self.renamed = renamed
        self.unconditionallyDeprecated = unconditionallyDeprecated
        self.unconditionallyUnavailable = unconditionallyUnavailable
        self.isBeta = isBeta
    }

    /// Sort two availability render items based on their platform name.
    internal static func isInPlatformOrder(lhs: AvailabilityRenderItem, rhs: AvailabilityRenderItem) -> Bool {
        guard let lhsName = lhs.name, let rhsName = rhs.name else {
            return lhs.name != nil
        }
        return PlatformName.areInIncreasingOrder(lhsName, rhsName)
    }
}
