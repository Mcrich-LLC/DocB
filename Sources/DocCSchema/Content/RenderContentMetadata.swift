// Additional metadata (an anchor, custom title/abstract, device frame) attachable to a content element.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Content/RenderContentMetadata.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: the `rawIndexableTextContent(references:)` extension, which depends on the
// `RenderInlineContent` TextIndexing extension that isn't part of this copy set.
//
// Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

import Foundation

/// Additional metadata that might belong to a content element.
public struct RenderContentMetadata: Equatable, Codable {
    /// An optional named anchor to the current element.
    public var anchor: String?
    /// An optional custom title.
    public var title: String?
    /// An optional custom abstract.
    public var abstract: [RenderInlineContent]?
    /// An optional identifier for the device frame that should wrap this element.
    public var deviceFrame: String?

    /// Creates a new metadata value for a content element.
    /// - Parameters:
    ///   - anchor: The named anchor of the content element.
    ///   - title: The customized title for the content element.
    ///   - abstract: The customized abstract for the content element.
    ///   - deviceFrame: The identifier for the device frame that should wrap the content element.
    public init(anchor: String? = nil, title: String? = nil, abstract: [RenderInlineContent]? = nil, deviceFrame: String? = nil) {
        self.anchor = anchor
        self.title = title
        self.abstract = abstract
        self.deviceFrame = deviceFrame
    }
}
