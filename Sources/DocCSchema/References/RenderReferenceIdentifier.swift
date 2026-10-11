// The identifier of a render reference, a type-safe wrapper around the string key used to look
// a reference up in a render node's references dictionary.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/References/RenderReference.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: the RenderJSONDiffable conformance.
//
// Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// The identifier of a render reference.
///
/// This structure wraps a string value to make handling of render identifiers more type safe and explicit.
public struct RenderReferenceIdentifier: Codable, Hashable, Equatable {
    /// The wrapped string identifier.
    public var identifier: String

    /// Creates a new render identifier.
    /// - Parameter identifier: The string identifier to wrap.
    public init(_ identifier: String) {
        self.identifier = identifier
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        identifier = try container.decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(identifier)
    }

    private enum CodingKeys: CodingKey {
        case identifier
    }
}

extension RenderReferenceIdentifier {
    /// Creates a new render reference identifier, based on the path of the given external link.
    ///
    /// This is not a unique identifier. If you create two render reference identifiers with the same external link destination, they are equal and interchangeable .
    ///
    /// - Parameter linkDestination: The full path of the external link represented as a `String`.
    public init(forExternalLink linkDestination: String) {
        self.identifier = "\(linkDestination)"
    }
}
