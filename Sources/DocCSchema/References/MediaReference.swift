// A reference to media, such as an image or a video.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/References/MediaReference.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
//
// Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

import Foundation

/// A reference to media, such as an image or a video.
public protocol MediaReference: RenderReference {
    /// The data associated with this asset, including its variants.
    var asset: DataAsset { get set }
    /// Alternate text for the media.
    ///
    /// This text helps screen readers describe the media.
    var altText: String? { get set }
}
