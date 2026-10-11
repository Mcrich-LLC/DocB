// A resolved reference to a piece of documentation, as it appears in render JSON (a URL paired
// with the source language it is written in).
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Identifier.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: this is a reduced adaptation of upstream's `ResolvedTopicReference`, which is a
// copy-on-write wrapper around a bundle identifier, path, fragment, and set of source
// languages, backed by a process-wide synchronized reference cache (`Synchronized`) and
// `DocumentationContext.Inputs.Identifier`. None of the path-manipulation methods
// (`withFragment(_:)`, `appendingPath(_:)`, etc.), the reference cache, or the multi-language
// `sourceLanguages` support are kept; only the `url`/`sourceLanguage` pair and its render JSON
// coding as `{"url", "interfaceLanguage"}` survive, matching upstream's `encode(to:)`/
// `init(from:)` for the `.url`/`.interfaceLanguage` keys. `path` and `absoluteString` are
// derived directly from `url` instead of from cached storage.
//
// Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

import Foundation

/// A reference to a piece of documentation which has been verified to exist.
public struct ResolvedTopicReference: Hashable, Codable, Equatable {
    /// The URL scheme of `doc://` links.
    public static let urlScheme = "doc"

    /// The topic URL as you would write in a link.
    public var url: URL

    /// The source language for which this topic is relevant.
    public var sourceLanguage: SourceLanguage

    public init(url: URL, sourceLanguage: SourceLanguage) {
        self.url = url
        self.sourceLanguage = sourceLanguage
    }

    /// A string representation of `url`.
    public var absoluteString: String {
        return url.absoluteString
    }

    /// The absolute path to this topic, delimited by `/`.
    public var path: String {
        return url.path
    }

    internal enum CodingKeys: CodingKey {
        case url, interfaceLanguage
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let url = try container.decode(URL.self, forKey: .url)
        let language = try container.decode(String.self, forKey: .interfaceLanguage)

        self.url = url
        self.sourceLanguage = SourceLanguage(id: language)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(url.absoluteString, forKey: .url)
        try container.encode(sourceLanguage.id, forKey: .interfaceLanguage)
    }
}
