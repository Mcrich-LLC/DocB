// Groups a render node's asset-like references (images, videos, files, downloads, and external
// locations) by their reference type.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/References/AssetReferences.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

import Foundation

extension RenderNode {
    /// All image, video, file, and download references of this node, grouped by their type.
    public var assetReferences: [RenderReferenceType: [any RenderReference]] {
        let assetTypes = [RenderReferenceType.image, .video, .file, .download, .externalLocation]
        return .init(grouping: references.values.lazy.filter({ assetTypes.contains($0.type) }), by: { $0.type })
    }
}
