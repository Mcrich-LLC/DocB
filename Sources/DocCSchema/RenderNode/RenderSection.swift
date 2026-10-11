// The protocol shared by all render node content sections.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/RenderSection.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: dropped the `TextIndexing` conformance. Split: `RenderSectionKind` moved to its own
// file, RenderSectionKind.swift.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

public protocol RenderSection: Codable {
    var kind: RenderSectionKind { get }
}
