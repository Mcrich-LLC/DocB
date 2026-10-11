// Helpers for decoding `VariantCollection` values.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Variants/VariantCollection+Coding.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: split into `KeyedDecodingContainer+VariantCollection.swift` (this file) and
// `KeyedEncodingContainer+VariantCollection.swift`.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

extension KeyedDecodingContainer {
    /// Decodes the given variant collection.
    internal func decodeVariantCollection<Value>(
        ofValueType: Value.Type,
        forKey key: Key
    ) throws -> VariantCollection<Value> {
        try decode(VariantCollection<Value>.self, forKey: key)
    }

    /// Decodes the given variant collection and returns nil if it's not present.
    internal func decodeVariantCollectionIfPresent<Value>(
        ofValueType: Value.Type,
        forKey key: Key
    ) throws -> VariantCollection<Value>? {
        try decodeIfPresent(VariantCollection<Value>.self, forKey: key)
    }

    /// Decodes the given variant collection of optional value and empty variant collection if it's no value is present.
    internal func decodeVariantCollectionIfPresent<Value>(
        ofValueType: Value?.Type,
        forKey key: Key
    ) throws -> VariantCollection<Value?> {
        try decodeIfPresent(VariantCollection<Value?>.self, forKey: key) ?? .init(defaultValue: nil)
    }

    /// Decodes the given array of variant collections.
    internal func decodeVariantCollectionArrayIfPresent<Value>(
        ofValueType: Value?.Type,
        forKey key: Key
    ) throws -> [VariantCollection<Value?>] {
        try decodeIfPresent([VariantCollection<Value?>].self, forKey: key) ?? []
    }
}
