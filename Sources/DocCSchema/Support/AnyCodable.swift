// A type-erased codable value, used to carry loosely-typed JSON data in render JSON.
//
// Copied from swift-docc `Sources/SwiftDocC/Infrastructure/Communication/Foundation/AnyCodable.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// A type-erased codable value.
///
/// An `AnyCodable` value forwards encoding and decoding operations to the underlying base.
public struct AnyCodable: Codable, CustomDebugStringConvertible {
    /// The base encodable value.
    public var value: any Encodable
    
    /// Creates a codable value that wraps the given base.
    public init(_ encodable: any Encodable) {
        value = encodable
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = JSON.null
        } else {
            value = try container.decode(JSON.self)
        }
    }
    
    public func encode(to encoder: any Encoder) throws {
        try value.encode(to: encoder)
    }
    
    public var debugDescription: String {
        return String(describing: value)
    }
}
