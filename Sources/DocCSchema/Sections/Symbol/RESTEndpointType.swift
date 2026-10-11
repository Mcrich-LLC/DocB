// A kind of a REST request endpoint.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Symbol/RESTEndpointRenderSection.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Tolerant: string enums keep unrecognised raw values in an `unknown` case instead of failing to decode.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// A kind of a REST request endpoint.
///
/// Endpoints can describe either a production or sandbox URL.
internal enum RESTEndpointType: TolerantStringEnum {
    /// A production endpoint.
    case production
    /// A sandbox endpoint used for testing.
    case sandbox

    /// A value this version of the schema does not know. The raw string is preserved and re-encoded unchanged.
    case unknown(String)

    internal init(rawValue: String) {
        switch rawValue {
        case "production": self = .production
        case "sandbox": self = .sandbox
        default: self = .unknown(rawValue)
        }
    }

    internal var rawValue: String {
        switch self {
        case .production: "production"
        case .sandbox: "sandbox"
        case .unknown(let rawValue): rawValue
        }
    }
}
