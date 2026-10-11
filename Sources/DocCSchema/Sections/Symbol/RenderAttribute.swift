// A single renderable symbol attribute, such as a default value, a minimum/maximum,
// or a list of allowed values or types.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Symbol/AttributesRenderSection.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Tolerant: string enums keep unrecognised raw values in an `unknown` case instead of failing to decode.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

import Foundation

/// A single renderable attribute.
public enum RenderAttribute: Codable, Equatable {
    /// The list of keys to use to encode/decode the attribute.
    public enum CodingKeys: CodingKey, Hashable {
        case title, value, values, kind
    }

    /// A list of the plain-text names of supported attributes.
    public enum Kind: TolerantStringEnum {
        case `default`, minimum, minimumExclusive, maximum, maximumExclusive, minimumLength, maximumLength, allowedValues, allowedTypes

        /// A value this version of the schema does not know. The raw string is preserved and re-encoded unchanged.
        case unknown(String)

        public init(rawValue: String) {
            switch rawValue {
            case "default": self = .`default`
            case "minimum": self = .minimum
            case "minimumExclusive": self = .minimumExclusive
            case "maximum": self = .maximum
            case "maximumExclusive": self = .maximumExclusive
            case "minimumLength": self = .minimumLength
            case "maximumLength": self = .maximumLength
            case "allowedValues": self = .allowedValues
            case "allowedTypes": self = .allowedTypes
            default: self = .unknown(rawValue)
            }
        }

        public var rawValue: String {
            switch self {
            case .`default`: "default"
            case .minimum: "minimum"
            case .minimumExclusive: "minimumExclusive"
            case .maximum: "maximum"
            case .maximumExclusive: "maximumExclusive"
            case .minimumLength: "minimumLength"
            case .maximumLength: "maximumLength"
            case .allowedValues: "allowedValues"
            case .allowedTypes: "allowedTypes"
            case .unknown(let rawValue): rawValue
            }
        }
    }
    /// A default value, for example `none`.
    case `default`(String)
    /// A minimum value, for example `1.0`.
    case minimum(String)
    /// A minimum value (excluding the given one) for example `1.0`.
    case minimumExclusive(String)
    /// A maximum value, for example `10.0`.
    case maximum(String)
    /// A maximum value (excluding the given one), for example `10.0`.
    case maximumExclusive(String)
    /// A minimum allowed length of a string.
    case minimumLength(String)
    /// A maximum allowed length of a string.
    case maximumLength(String)
    /// A list of allowed values, for example `none`, `some`, and `all`.
    case allowedValues([String])
    /// A list of allowed type declarations for the value being described,
    /// for example `String`, `Int`, and `Double`.
    case allowedTypes([[DeclarationRenderSection.Token]])

    /// An attribute whose `kind` this version of the schema does not know, preserved verbatim.
    case unknown(JSON)

    /// A title for this attribute.
    internal var title: String {
        switch self {
        case .default: return "Default value"
        case .minimum: return "Minimum"
        case .minimumExclusive: return "Minimum"
        case .maximum: return "Maximum"
        case .maximumExclusive: return "Maximum"
        case .minimumLength: return "Minimum length"
        case .maximumLength: return "Maximum length"
        case .allowedValues: return "Possible Values"
        case .allowedTypes: return "Possible Types"
        case .unknown(let json):
            if case .dictionary(let object) = json, case .string(let title)? = object["title"] {
                return title
            }
            return ""
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        switch try container.decode(Kind.self, forKey: .kind) {
        case .default:
            self = .default(try container.decode(String.self, forKey: .value))
        case .minimum:
            self = .minimum(try container.decode(String.self, forKey: .value))
        case .minimumExclusive:
            self = .minimumExclusive(try container.decode(String.self, forKey: .value))
        case .maximum:
            self = .maximum(try container.decode(String.self, forKey: .value))
        case .maximumExclusive:
            self = .maximumExclusive(try container.decode(String.self, forKey: .value))
        case .minimumLength:
            self = .minimumLength(try container.decode(String.self, forKey: .value))
        case .maximumLength:
            self = .maximumLength(try container.decode(String.self, forKey: .value))
        case .allowedValues:
            self = .allowedValues(try container.decode([String].self, forKey: .values))
        case .allowedTypes:
            self = .allowedTypes(try container.decode([[DeclarationRenderSection.Token]].self, forKey: .values))
        case .unknown:
            self = .unknown(try JSON(from: decoder))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        if case .unknown(let json) = self {
            try json.encode(to: encoder)
            return
        }

        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .default(let value):
            try container.encode(Kind.default, forKey: .kind)
            try container.encodeIfPresent(value, forKey: .value)
        case .minimum(let value):
            try container.encode(Kind.minimum, forKey: .kind)
            try container.encodeIfPresent(value, forKey: .value)
        case .minimumExclusive(let value):
            try container.encode(Kind.minimumExclusive, forKey: .kind)
            try container.encodeIfPresent(value, forKey: .value)
        case .maximum(let value):
            try container.encode(Kind.maximum, forKey: .kind)
            try container.encodeIfPresent(value, forKey: .value)
        case .maximumExclusive(let value):
            try container.encode(Kind.maximumExclusive, forKey: .kind)
            try container.encodeIfPresent(value, forKey: .value)
        case .minimumLength(let value):
            try container.encode(Kind.minimumLength, forKey: .kind)
            try container.encodeIfPresent(value, forKey: .value)
        case .maximumLength(let value):
            try container.encode(Kind.maximumLength, forKey: .kind)
            try container.encodeIfPresent(value, forKey: .value)
        case .allowedValues(let values):
            try container.encode(Kind.allowedValues, forKey: .kind)
            try container.encodeIfPresent(values, forKey: .values)
        case .allowedTypes(let values):
            try container.encode(Kind.allowedTypes, forKey: .kind)
            try container.encodeIfPresent(values, forKey: .values)
        case .unknown:
            break // Handled above.
        }
    }
}
