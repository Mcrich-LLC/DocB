// A single generic constraint on a symbol, as used to render "Available when..." /
// "Conforms when..." sentences in a conformance section.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Symbol/ConformanceSection.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Tolerant: string enums keep unrecognised raw values in an `unknown` case instead of failing to decode.
// Trimmed: upstream defines `Constraint` as `typealias Constraint = SymbolGraph.Symbol.Swift.GenericConstraint`
// (a SymbolKit type, outside the copy set); this file instead declares `Constraint` as its
// own type, carrying only the fields (`kind`, `leftTypeName`, `rightTypeName`) that
// ConformanceSection.swift actually uses.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

import Foundation

/// A single generic constraint on a symbol.
internal struct Constraint: Codable, Equatable {
    /// The kind of relationship a constraint describes.
    internal enum Kind: TolerantStringEnum {
        case conformance
        case sameType
        case superclass
        case sameShape

        /// A value this version of the schema does not know. The raw string is preserved and re-encoded unchanged.
        case unknown(String)

        internal init(rawValue: String) {
            switch rawValue {
            case "conformance": self = .conformance
            case "sameType": self = .sameType
            case "superclass": self = .superclass
            case "sameShape": self = .sameShape
            default: self = .unknown(rawValue)
            }
        }

        internal var rawValue: String {
            switch self {
            case .conformance: "conformance"
            case .sameType: "sameType"
            case .superclass: "superclass"
            case .sameShape: "sameShape"
            case .unknown(let rawValue): rawValue
            }
        }
    }

    /// The kind of relationship this constraint describes.
    internal var kind: Kind
    /// The name of the type the constraint is on.
    internal var leftTypeName: String
    /// The name of the type, protocol, or shape the left type is constrained to.
    internal var rightTypeName: String
}

extension Constraint.Kind {
    /// The spelling to use when rendering this kind of constraint.
    internal var spelling: String {
        switch self {
        case .conformance: return "conforms to"
        case .sameType: return "is"
        case .superclass: return "inherits"
        case .sameShape: return "is the same shape as"
        case .unknown(let rawValue): return rawValue
        }
    }
}
