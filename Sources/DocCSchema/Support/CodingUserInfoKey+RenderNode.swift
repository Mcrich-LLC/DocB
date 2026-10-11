// The coding user-info keys used to pass render JSON encoding options (variant overrides,
// reference/asset handling) through `Encoder`/`Decoder` state.
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

extension CodingUserInfoKey {
    /// A user info key to indicate that Render JSON references should not be encoded.
    internal static let skipsEncodingReferences = CodingUserInfoKey(rawValue: "skipsEncodingReferences")!
    
    /// A user info key that encapsulates variant overrides.
    ///
    /// This key is used by encoders to accumulate language-specific variants of documentation in a ``VariantOverrides`` value.
    internal static let variantOverrides = CodingUserInfoKey(rawValue: "variantOverrides")!
    
    internal static let baseEncodingPath = CodingUserInfoKey(rawValue: "baseEncodingPath")!
    
    /// A user info key to indicate a base path for local asset URLs.
    internal static let assetPrefixComponent = CodingUserInfoKey(rawValue: "assetPrefixComponent")!
}
