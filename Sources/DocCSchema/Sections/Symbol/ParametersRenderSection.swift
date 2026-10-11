// A render section that contains the list of named parameter sub-sections for a symbol.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Symbol/ParameterRenderSection.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: the RenderJSONDiffable conformance is removed.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// A section that contains a list of parameters.
public struct ParametersRenderSection: RenderSection, Equatable {
    public var kind: RenderSectionKind = .parameters
    /// The list of parameter sub-sections.
    public var parameters: [ParameterRenderSection]

    /// Creates a new parameters section with the given list.
    public init(parameters: [ParameterRenderSection]) {
        self.parameters = parameters
    }
}
