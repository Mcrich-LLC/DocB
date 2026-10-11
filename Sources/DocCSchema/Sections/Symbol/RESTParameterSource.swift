// A kind of a REST request parameter.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Symbol/RESTParametersRenderSection.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Tolerant: string enums keep unrecognised raw values in an `unknown` case instead of failing to decode.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// A kind of a REST request parameter.
///
/// Parameter sections might describe parameters used in
/// the URL query, the URL path, HTTP headers, or a multi-part HTTP body.
public enum RESTParameterSource: TolerantStringEnum {
    /// A named URL query parameter, for example, `?category=90s`.
    case query
    /// A named URL path parameter, for example, `/artists/MyArtist`.
    case path
    /// An HTTP header sent with the request, for example, `Authorization: MyCredentials`.
    case header
    /// An HTTP cookie sent with the request.
    case cookie

    /// A value this version of the schema does not know. The raw string is preserved and re-encoded unchanged.
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "query": self = .query
        case "path": self = .path
        case "header": self = .header
        case "cookie": self = .cookie
        default: self = .unknown(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .query: "query"
        case .path: "path"
        case .header: "header"
        case .cookie: "cookie"
        case .unknown(let rawValue): rawValue
        }
    }
}
