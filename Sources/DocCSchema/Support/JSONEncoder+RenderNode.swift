// Mutable accessors that store render JSON encoding options in a `JSONEncoder`'s user info.
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

import Foundation

extension JSONEncoder {
    /// The variant overrides accumulated as part of the encoding process.
    internal var userInfoVariantOverrides: VariantOverrides? {
        get {
            userInfo[.variantOverrides] as? VariantOverrides
        }
        set {
            userInfo[.variantOverrides] = newValue
        }
    }
    
    /// The base path to use when creating dynamic JSON pointers
    /// with this encoder.
    internal var baseJSONPatchPath: [String]? {
        get {
            userInfo[.baseEncodingPath] as? [String]
        }
        set {
            userInfo[.baseEncodingPath] = newValue
        }
    }
    
    /// A Boolean that is true if this encoder skips the encoding any render references.
    ///
    /// These references will then be encoded at a later stage by `TopicRenderReferenceEncoder`.
    internal var skipsEncodingReferences: Bool {
        get {
            userInfo[.skipsEncodingReferences] as? Bool ?? false
        }
        set {
            userInfo[.skipsEncodingReferences] = newValue
        }
    }
}
