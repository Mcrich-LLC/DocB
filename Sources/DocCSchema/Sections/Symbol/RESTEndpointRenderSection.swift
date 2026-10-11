// A render section that describes a REST API endpoint as a list of tokens: a method,
// base URL, path, and any dynamic parameters.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Symbol/RESTEndpointRenderSection.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Tolerant: string enums keep unrecognised raw values in an `unknown` case instead of failing to decode.
// Trimmed: the RenderJSONDiffable conformances (on this type and on `Token`) are removed.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

import Foundation

/// A section that contains a REST API endpoint.
///
/// This section is similar to ``DeclarationRenderSection`` for symbols and
/// describes a tokenized endpoint for a REST API. The token list starts with
/// an HTTP method token followed by tokens for the complete endpoint URL. Any path
/// components that are dynamic instead of fixed are represented with a parameter name
/// enclosed in curly brackets.
///
/// A complete token representation for the endpoint `GET https://www.example.com/api/artists/{id}`
/// is (the token kind is in brackets):
///  - (method) `GET`
///  - (baseURL) `https://www.example.com`
///  - (path) `/api/artists/`
///  - (parameter) `{id}`
public struct RESTEndpointRenderSection: RenderSection, Equatable {
    public var kind: RenderSectionKind = .restEndpoint
    /// A single token in a REST endpoint.
    public struct Token: Codable, Equatable {
        /// The kind of REST endpoint token.
        public enum Kind: TolerantStringEnum {
            case method, baseURL, path, parameter, text

            /// A value this version of the schema does not know. The raw string is preserved and re-encoded unchanged.
            case unknown(String)

            public init(rawValue: String) {
                switch rawValue {
                case "method": self = .method
                case "baseURL": self = .baseURL
                case "path": self = .path
                case "parameter": self = .parameter
                case "text": self = .text
                default: self = .unknown(rawValue)
                }
            }

            public var rawValue: String {
                switch self {
                case .method: "method"
                case .baseURL: "baseURL"
                case .path: "path"
                case .parameter: "parameter"
                case .text: "text"
                case .unknown(let rawValue): rawValue
                }
            }
        }

        /// The endpoint specific token kind.
        public let kind: Kind
        /// The plain text of the token.
        public let text: String
    }

    /// The title for the section.
    public var title: String

    /// The list of tokens.
    public let tokens: [Token]

    /// Creates a new REST endpoint section.
    /// - Parameters:
    ///   - title: The title for the section.
    ///   - tokens: The list of tokens.
    public init(title: String, tokens: [Token]) {
        self.title = title
        self.tokens = tokens
    }
}
