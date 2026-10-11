// A section that groups content and media sections.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Tutorials Overview/Sections/ContentAndMediaGroupSection.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Tolerant: the initializer no longer traps on an empty or mixed-layout group.
// Trimmed: the RenderJSONDiffable conformance is removed.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// A section that groups content and media sections.
public struct ContentAndMediaGroupSection: RenderSection, Equatable {
    public var kind: RenderSectionKind = .contentAndMediaGroup

    /// The layout direction of all content and media sections in this group.
    public var layout: ContentAndMediaSection.Layout?

    /// The content and media sections in this group.
    public var sections: [ContentAndMediaSection]

    /// Creates a group of content and media sections.
    ///
    /// The layout is taken from the first section, or is `.horizontal` when there are none.
    public init(sections: [ContentAndMediaSection]) {
        self.layout = sections.first?.layout ?? .horizontal
        self.sections = sections
    }
}
