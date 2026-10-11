// A style for how to render links to a property list key or an entitlement key.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Symbol/PropertyListDetailsRenderSection.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Tolerant: string enums keep unrecognised raw values in an `unknown` case instead of failing to decode.
//
// Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// A style for how to render links to a property list key or an entitlement key.
public enum PropertyListTitleStyle: TolerantStringEnum {
    /// Render links to the property list key using the raw key, for example "com.apple.enableDataAccess".
    ///
    /// ## See Also
    /// - ``TopicRenderReference/PropertyListKeyNames/rawKey``
    case useRawKey
    /// Render links to the property list key using the display name, for example "Enables Data Access".
    ///
    /// ## See Also
    /// - ``TopicRenderReference/PropertyListKeyNames/displayName``
    case useDisplayName

    /// A value this version of the schema does not know. The raw string is preserved and re-encoded unchanged.
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "symbol": self = .useRawKey
        case "title": self = .useDisplayName
        default: self = .unknown(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .useRawKey: "symbol"
        case .useDisplayName: "title"
        case .unknown(let rawValue): rawValue
        }
    }
}
