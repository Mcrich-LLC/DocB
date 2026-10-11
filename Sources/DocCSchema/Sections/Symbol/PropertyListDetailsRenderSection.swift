// A render section that contains details about a property list key or entitlement key.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Symbol/PropertyListDetailsRenderSection.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: the RenderJSONDiffable conformance is removed.
//
// Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

import Foundation

/// A section that contains details about a property list key.
public struct PropertyListDetailsRenderSection: RenderSection, Equatable {
    public var kind: RenderSectionKind = .plistDetails
    /// A title for the section.
    public var title = "Details"

    /// Details for a property list key.
    public struct Details: Codable, Equatable {
        /// The name of the key.
        public let rawKey: String
        /// A list of types acceptable for this key's value.
        public let value: [TypeDetails]
        /// A list of platforms to which this key applies.
        public let platforms: [String]
        /// An optional, human-friendly name of the key.
        public let displayName: String?
        /// A title rendering style.
        public let titleStyle: PropertyListTitleStyle

        internal enum CodingKeys: String, CodingKey {
            case rawKey = "name"
            case value
            case platforms
            case displayName = "ideTitle"
            case titleStyle
        }

        public init(rawKey: String, value: [TypeDetails], platforms: [String], displayName: String?, titleStyle: PropertyListTitleStyle) {
            self.rawKey = rawKey
            self.value = value
            self.platforms = platforms
            self.displayName = displayName
            self.titleStyle = titleStyle
        }
    }

    /// The details of the property key.
    public let details: Details

    public init(title: String = "Details", details: Details) {
        self.title = title
        self.details = details
    }
}
