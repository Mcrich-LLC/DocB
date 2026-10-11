// `VariantCollectionPatchable` conformances for `Optional`, `Array`, and `String`, plus the
// `VariantCollection` helpers that apply a patchable value's variant patches.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Variants/VariantPatchOperation.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: `private import DocCCommon` removed; `SourceLanguage` is part of this module here.
//
// Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

extension Optional: VariantCollectionPatchable where Wrapped: VariantCollectionPatchable {
    internal mutating func add(_ other: Wrapped?) {
        guard var wrapped = self, let other else { return }
        wrapped.add(other)
        self = wrapped
    }

    internal mutating func remove() {
        self = nil
    }
}

extension Array: VariantCollectionPatchable {
    internal mutating func add(_ other: [Element]) {
        append(contentsOf: other)
    }

    internal mutating func remove() {
        self.removeAll()
    }
}

extension String: VariantCollectionPatchable {
    internal mutating func add(_ other: String) {
        append(contentsOf: other)
    }

    internal mutating func remove() {
        self.removeAll()
    }
}

extension VariantCollection where Value: VariantCollectionPatchable {
    /// Returns the transformed value after applying the patch operations for all variants that match the given source language to the default value.
    /// - Parameters:
    ///   - language: The source language that determine what variant's patches to apply to the default value.
    /// - Returns: The transformed value, or the default value if no variants match the given source language.
    internal func value(for language: SourceLanguage) -> Value {
        applied(to: defaultValue, for: [.interfaceLanguage(language.id)])
    }

    /// Returns the transformed value after applying the patch operations for all variants that match the given traits to the default value.
    /// - Parameters:
    ///   - traits: The traits that determine what variant's patches to apply to the default value.
    /// - Returns: The transformed value, or the default value if no variants match the given traits.
    internal func value(for traits: [RenderNode.Variant.Trait]) -> Value {
        applied(to: defaultValue, for: traits)
    }

    /// Returns the transformed value after applying the patch operations for all variants that match the given traits to the original value.
    /// - Parameters:
    ///   - originalValue: The original value to transform.
    ///   - traits: The traits that determine what variant's patches to apply to the original value.
    /// - Returns: The transformed value, or the original value if no variants match the given traits.
    internal func applied(to originalValue: Value, for traits: [RenderNode.Variant.Trait]) -> Value {
        var patchedValue = originalValue
        for variant in variants where variant.traits == traits {
            for patch in variant.patch {
                switch patch {
                case .replace(let value):
                    patchedValue = value
                case .add(let value):
                    patchedValue.add(value)
                case .remove:
                    patchedValue.remove()
                }
            }
        }
        return patchedValue
    }
}
