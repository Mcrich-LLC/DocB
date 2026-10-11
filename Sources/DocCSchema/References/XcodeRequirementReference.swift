// A reference to a version of Xcode that users of a piece of documentation must use.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Tutorial/References/XcodeRequirementReference.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: the RenderJSONDiffable conformance.
//
// Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

import Foundation

/// A reference to a version of Xcode that users of your documentation must use.
public struct XcodeRequirementReference: RenderReference, Equatable {
    public var type: RenderReferenceType = .xcodeRequirement

    public let identifier: RenderReferenceIdentifier

    /// A presentation-friendly title for the version of Xcode required for users of your documentation.
    public let title: String

    /// A download URL for the version of Xcode required for users of your documentation.
    public let url: URL

    /// Creates a reference to a version of Xcode that users of your documentation must use.
    ///
    /// - Parameters:
    ///   - identifier: An identifier for the requirement's reference
    ///   - title: The Xcode version title.
    ///   - url: A download URL for the Xcode version.
    public init(identifier: RenderReferenceIdentifier, title: String, url: URL) {
        self.identifier = identifier
        self.title = title
        self.url = url
    }
}
