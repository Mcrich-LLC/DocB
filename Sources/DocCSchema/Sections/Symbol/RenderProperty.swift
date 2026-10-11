// A named property with a declaration-style type, content, and an optional list of
// attributes, as listed inside a `PropertiesRenderSection`.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Symbol/PropertiesRenderSection.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: the TextIndexing conformance is removed.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

import Foundation

/// A named property with a declaration-style type, content, and
/// an optional list of attributes.
public struct RenderProperty: Codable, Equatable {
    /// The name of the property.
    public let name: String
    /// The list of possible type declarations for the property's value.
    public let type: [DeclarationRenderSection.Token]
    /// The list of possible type declarations for the property's value including additional details, if available.
    public let typeDetails: [TypeDetails]?
    /// Additional details about the property, if available.
    public var content: [RenderBlockContent]?
    /// Additional list of attributes, if any.
    public var attributes: [RenderAttribute]?
    /// A mime-type associated with the property, if applicable.
    public let mimeType: String?
    /// If true, the property is required in its containing context.
    public var required: Bool? = false
    /// If true, the property is deprecated.
    public var deprecated: Bool? = false
    /// If true, the property can only be accessed and not modified.
    public var readOnly: Bool? = false
    /// A version of the platform that first introduced the property, if known.
    public var introducedVersion: String?
}
