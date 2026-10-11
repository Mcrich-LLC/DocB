// A namespace for creating configured `JSONEncoder` instances for encoding ``RenderNode`` values.
//
// Copied from swift-docc `Sources/SwiftDocC/Converter/RenderNode+Coding.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: the `DOCC_JSON_PRETTYPRINT` environment-variable global (`shouldPrettyPrintOutputJSON`)
// is removed; `prettyPrint` now defaults to the literal `false`. The `RenderNode.CodingError`
// type and the `decode(fromJSON:with:)`/`encodeToJSON(with:renderReferenceCache:)` methods,
// which need `RenderReferenceCache`/`TopicRenderReferenceEncoder`, are also removed.
//
// Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

import Foundation

/// A namespace for encoders for render node JSON.
public enum RenderJSONEncoder {
    /// Creates a new JSON encoder for render node values.
    ///
    /// Returns an encoder that's configured to encode ``RenderNode`` values.
    ///
    /// > Important: Don't reuse encoders returned by this function to encode multiple render nodes, as the encoder accumulates state during the encoding
    /// process which should not be shared in other encoding units. Instead, call this API to create a new encoder for each render node you want to encode.
    ///
    /// - Parameters:
    ///   - prettyPrint: If `true`, the encoder formats its output to make it easy to read; if `false`, the output is compact.
    ///   - emitVariantOverrides: Whether the encoder should emit the top-level ``RenderNode/variantOverrides`` property that holds language-specific documentation data.
    ///   - assetPrefixComponent: A path component to include in destination URLs for local assets (images, videos, downloads, etc.)
    /// - Returns: The new JSON encoder.
    public static func makeEncoder(
        prettyPrint: Bool = false,
        emitVariantOverrides: Bool = true,
        assetPrefixComponent: String? = nil
    ) -> JSONEncoder {
        let encoder = JSONEncoder()
        
        encoder.outputFormatting = if prettyPrint {
            [.prettyPrinted, .sortedKeys]
        } else {
            [.sortedKeys]
        }
        
        if emitVariantOverrides {
            encoder.userInfo[.variantOverrides] = VariantOverrides()
        }
        if let bundleIdentifier = assetPrefixComponent {
            encoder.userInfo[.assetPrefixComponent] = bundleIdentifier
        }
        
        return encoder
    }
}
