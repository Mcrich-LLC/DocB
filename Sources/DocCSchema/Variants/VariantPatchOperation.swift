// A patch to update a render node value with a strongly-typed replacement, addition, or removal.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Variants/VariantPatchOperation.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: split `VariantCollectionPatchable` and its conformance extensions into their own files.
//
// Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// A patch to update a render node value.
public enum VariantPatchOperation<Value: Codable> {
    /// A replacement operation.
    ///
    /// - Parameter value: The value to use in the replacement.
    case replace(value: Value)

    /// An addition operation.
    ///
    /// - Parameter value: The value to use in the addition.
    case add(value: Value)

    /// A removal operation.
    case remove

    /// The operation to apply.
    public var operation: PatchOperation {
        switch self {
        case .replace(_):
            return .replace
        case .add(_):
            return .add
        case .remove:
            return .remove
        }
    }

    /// Returns a new patch operation with its value transformed using the given closure.
    ///
    /// If the patch operation doesn't have a value---for example, if it's a removal operation---the operation is returned unmodified.
    internal func map<TransformedValue>(
        _ transform: (Value) -> TransformedValue
    ) -> VariantPatchOperation<TransformedValue> {
        switch self {
        case .replace(let value):
            return VariantPatchOperation<TransformedValue>.replace(value: transform(value))

        case .add(let value):
            return VariantPatchOperation<TransformedValue>.add(value: transform(value))

        case .remove:
            return .remove
        }
    }
}

// The synthesized implementation is sufficient for this conformance.
extension VariantPatchOperation: Equatable where Value: Equatable {}
