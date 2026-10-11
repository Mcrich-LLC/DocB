// A render section that contains a list of REST parameters, such as query, path,
// header, or cookie parameters.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Symbol/RESTParametersRenderSection.swift`
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

/// A section that contains a list of REST parameters.
public struct RESTParametersRenderSection: RenderSection, Equatable {
    public var kind: RenderSectionKind = .restParameters
    /// The title for the section.
    public var title: String
    /// The list of REST parameters.
    public var parameters: [RenderProperty]
    /// The kind of listed parameters.
    public let source: RESTParameterSource

    internal enum CodingKeys: String, CodingKey {
        case kind
        case title
        case parameters = "items"
        case source
    }

    /// Creates a new REST parameters section.
    /// - Parameters:
    ///   - title: The title for the section.
    ///   - parameters: The list of REST parameters.
    ///   - source: The kind of listed parameters.
    public init(title: String, parameters: [RenderProperty], source: RESTParameterSource) {
        self.title = title
        self.parameters = parameters
        self.source = source
    }
}
