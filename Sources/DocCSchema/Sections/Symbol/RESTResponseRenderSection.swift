// A render section that displays a list of possible REST responses.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Symbol/RESTResponseRenderSection.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: the RenderJSONDiffable conformance is removed.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

import Foundation

/// A section that displays a list of REST responses.
public struct RESTResponseRenderSection: RenderSection, Equatable {
    public var kind: RenderSectionKind = .restResponses
    /// The title for the section.
    public var title: String
    /// The list of possible REST responses.
    public var responses: [RESTResponse]

    internal enum CodingKeys: String, CodingKey {
        case kind
        case title
        case responses = "items"
    }

    /// Creates a new REST response section.
    /// - Parameters:
    ///   - title: The title for the section.
    ///   - responses: The list of possible REST responses.
    public init(title: String, responses: [RESTResponse]) {
        self.title = title
        self.responses = responses
    }
}
