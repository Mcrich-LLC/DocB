// A REST response that includes the HTTP status, reason, and the MIME type encoding
// of the response body.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Symbol/RESTResponseRenderSection.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: the TextIndexing and RenderJSONDiffable conformances are removed.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

import Foundation

/// A REST response that includes the HTTP status, reason,
/// and the MIME type encoding of the response body.
///
/// If the response is a decodable object, a declaration-style `type` property
/// describes the expected type and can provide an optional link to the expected
/// documentation symbol.
public struct RESTResponse: Codable, Equatable {
    /// The HTTP status code for the response.
    public let status: UInt
    /// An optional plain-text reason for the response.
    public let reason: String?
    /// An optional response MIME content-type.
    public let mimeType: String?
    /// A type declaration of the response's content.
    public let type: [DeclarationRenderSection.Token]
    /// Response details, if any.
    public var content: [RenderBlockContent]?

    /// Creates a new REST response section.
    /// - Parameters:
    ///   - status: The HTTP status code for the response.
    ///   - reason: An optional plain-text reason for the response.
    ///   - mimeType: An optional response MIME content-type.
    ///   - type: A type declaration of the response's content.
    ///   - content: Response details, if any.
    public init(
        status: UInt,
        reason: String?,
        mimeType: String?,
        type: [DeclarationRenderSection.Token],
        content: [RenderBlockContent]?
    ) {
        self.status = status
        self.reason = reason
        self.mimeType = mimeType
        self.type = type
        self.content = content
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(UInt.self, forKey: .status)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType)
        type = try container.decode([DeclarationRenderSection.Token].self, forKey: .type)
        content = try container.decodeIfPresent([RenderBlockContent].self, forKey: .content)
    }
}
