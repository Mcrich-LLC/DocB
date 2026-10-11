// Convenience accessors that read render JSON encoding options out of an `Encoder`'s user info.
//
// Copied from swift-docc `Sources/SwiftDocC/Converter/RenderNode+Coding.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
//
// Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

extension Encoder {
    /// The variant overrides accumulated as part of the encoding process.
    internal var userInfoVariantOverrides: VariantOverrides? {
        userInfo[.variantOverrides] as? VariantOverrides
    }
    
    /// The base path to use when creating dynamic JSON pointers
    /// with this encoder.
    internal var baseJSONPatchPath: [String]? {
        userInfo[.baseEncodingPath] as? [String]
    }
    
    /// A Boolean that is true if this encoder skips the encoding of any render references.
    ///
    /// These references will then be encoded at a later stage by `TopicRenderReferenceEncoder`.
    internal var skipsEncodingReferences: Bool {
        userInfo[.skipsEncodingReferences] as? Bool ?? false
    }
    
    /// A base path to use when creating destination URLs for local assets (images, videos, downloads, etc.)
    internal var assetPrefixComponent: String? {
        userInfo[.assetPrefixComponent] as? String
    }
}
