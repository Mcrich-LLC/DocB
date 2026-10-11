// A tag that can be assigned to a render node, such as the SPI badge.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/RenderNode.Tag.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
//
// Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

import Foundation

extension RenderNode {
    /// A tag that can be assigned to a render node.
    public struct Tag: Codable, Equatable, Sendable {
        /// The tag type.
        internal let type: String
        /// The text to display.
        internal let text: String

        /// A pre-defined SPI tag.
        internal static let spi = Tag(type: "spi", text: "SPI")
    }
}
