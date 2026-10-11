// A type that contains variant collections, with utility APIs for reading and writing default values.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Variants/VariantContainer.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Tolerant: no forced unwrap.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// A type that contains variant collections.
///
/// This protocol provides utility APIs for types that contain ``VariantCollection`` values.
public protocol VariantContainer {}

extension VariantContainer {
    /// Sets the given value, if present, as the default value of the variant collection at the given key path.
    ///
    /// If a variant collection is present, this function updates its default value to the given value. Otherwise, it creates a new variant container with the given
    /// value as its default value.
    public mutating func setVariantDefaultValue<Value>(
        _ newValue: Value?,
        keyPath: WritableKeyPath<Self, VariantCollection<Value>?>
    ) {
        if var collection = self[keyPath: keyPath] {
            newValue.map { collection.defaultValue = $0 }
            self[keyPath: keyPath] = collection
        } else {
            self[keyPath: keyPath] = newValue.map { VariantCollection<Value>.init(defaultValue: $0) }
        }
    }

    /// Returns the default value of the variant collection at the given key path, if present.
    public func getVariantDefaultValue<Value>(
        keyPath: WritableKeyPath<Self, VariantCollection<Value>?>
    ) -> Value? {
        self[keyPath: keyPath]?.defaultValue
    }

    /// Sets the given value as the default value of the variant collection at the given key path.
    public mutating func setVariantDefaultValue<Value>(
        _ newValue: Value,
        keyPath: WritableKeyPath<Self, VariantCollection<Value>>
    ) {
        self[keyPath: keyPath].defaultValue = newValue
    }

    /// Returns the default value of the variant collection at the given key path.
    public func getVariantDefaultValue<Value>(
        keyPath: WritableKeyPath<Self, VariantCollection<Value>>
    ) -> Value {
        self[keyPath: keyPath].defaultValue
    }
}
