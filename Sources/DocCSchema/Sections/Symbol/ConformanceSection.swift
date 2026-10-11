// A section that describes the generic constraints under which a symbol is
// available or conforms to a protocol.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Symbol/ConformanceSection.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: the failable `init(constraints:options:)` and `groupRequirements(_:)`, which built
// the rendered sentence from raw SymbolGraph constraints via `NativeLanguage` (outside the
// copy set), are removed, along with the now-unused `String.spaceDelimited` helper they used;
// the RenderJSONDiffable conformance is also removed.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

import Foundation

/// A section that contains a list of generic constraints for a symbol.
///
/// The section contains a list of generic constraints that describe the conditions
/// when a symbol is available or conforms to a protocol. For example:
/// "Available when `Element` conforms to `Equatable` and `S` conforms to `StringLiteral`."
public struct ConformanceSection: Codable, Equatable {
    /// A prefix with which to prepend availability constraints.
    internal var availabilityPrefix: [RenderInlineContent] = [.text("Available when")]
    /// A prefix with which to prepend conformance constraints.
    internal var conformancePrefix: [RenderInlineContent] = [.text("Conforms when")]

    /// The section constraints rendered as inline content.
    internal let constraints: [RenderInlineContent]

    /// Additional parameters to consider when rendering conformance constraints.
    internal struct ConstraintRenderOptions {
        /// Whether the symbol is a leaf symbol, such as a function or a property.
        internal let isLeaf: Bool

        /// The name of the parent symbol.
        internal let parentName: String?

        /// The symbol name of `Self`.
        internal let selfName: String
    }

    private static let selfPrefix = "Self."

    /// Returns, modified if necessary, a conforming type's name for rendering.
    internal static func displayNameForConformingType(_ typeName: String) -> String {
        if typeName.hasPrefix(selfPrefix) {
            return String(typeName.dropFirst(selfPrefix.count))
        }
        return typeName
    }

    /// Filters the list of constraints to the significant constraints only.
    ///
    /// This method removes symbol graph constraints on `Self` that are always fulfilled.
    internal static func filterConstraints(_ constraints: [Constraint], options: ConstraintRenderOptions) -> [Constraint] {
        return constraints
            .filter { constraint -> Bool in
                if options.isLeaf {
                    // Leaf symbol.
                    if constraint.leftTypeName == "Self" && constraint.rightTypeName == options.parentName {
                        // The Swift compiler will sometimes include a constraint's to `Self`'s type,
                        // filter those generic constraints out.
                        return false
                    }
                    return true
                } else {
                    // Non-leaf symbol.
                    if constraint.leftTypeName == "Self" && constraint.rightTypeName == options.selfName {
                        // The Swift compiler will sometimes include a constraint's to `Self`'s type,
                        // filter those generic constraints out.
                        return false
                    }
                    return true
                }
            }
    }
}
