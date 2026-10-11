// A render section describing a single, named symbol parameter.
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

/// A section that contains a single, named parameter.
public struct ParameterRenderSection: Codable, Equatable {
    /// The parameter name.
    public let name: String
    /// Free-form content to provide information about the parameter.
    public var content: [RenderBlockContent]
}
