// A render section listing the pages that mention a symbol.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Symbol/MentionsRenderSection.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: the TextIndexing and RenderJSONDiffable conformances are removed.
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

import Foundation

public struct MentionsRenderSection: RenderSection, Codable, Equatable {
    public var kind: RenderSectionKind = .mentions
    public var mentions: [URL]

    public init(mentions: [URL]) {
        self.mentions = mentions
    }
}
