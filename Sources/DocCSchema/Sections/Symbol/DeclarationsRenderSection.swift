// A compound render section that groups the (possibly platform- or language-specific)
// declaration sections for a symbol.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Symbol/DeclarationsRenderSection.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: the TextIndexing and RenderJSONDiffable conformances are removed.
//
// Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

import Foundation

/// A compound section that contains a list of declaration sections.
public struct DeclarationsRenderSection: RenderSection, Codable, Equatable {
    /// The section title, by default `nil`.
    public static var title: String? {
        get { nil }
        @available(*, deprecated, message: "Setting this value has no effect; create a new value instead. This value will become read-only after 6.5 is released.")
        set { /* Do nothing */ }
    }

    public var kind: RenderSectionKind = .declarations
    /// The list of declaration sections.
    public var declarations: [DeclarationRenderSection]

    /// Creates a new declarations section.
    /// - Parameter declarations: The list of declaration sections to include.
    public init(declarations: [DeclarationRenderSection]) {
        self.declarations = declarations
    }
}
