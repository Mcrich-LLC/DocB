// A proxy value for information about an asset variant, shared by the image and video
// reference variant proxies.
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

/// A proxy value for information about an asset variant.
internal protocol MediaVariantProxy {
    /// The URL of the file for this variant.
    var url: URL { get }
    /// The traits of this variant.
    var traits: [String] { get }
}

extension MediaVariantProxy {
    /// Compares two variants by their rendered URL, and by traits for variants with identical URLs.
    internal static func areInIncreasingOrder(_ lhs: Self, _ rhs: Self) -> Bool {
        if lhs.url.path != rhs.url.path {
            return lhs.url.path < rhs.url.path
        }
        return lhs.traits.joined() < rhs.traits.joined()
    }
}
