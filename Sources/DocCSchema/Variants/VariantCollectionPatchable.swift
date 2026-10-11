// A type that can be transformed by incrementally applying variant patch operations.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Variants/VariantPatchOperation.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
//
// Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// A type that can be transformed by incrementally applying variant patch operations.
internal protocol VariantCollectionPatchable {
    /// Apply an "add" patch operation to the value
    mutating func add(_ other: Self)
    /// Apply a "remove" patch operation to the value
    mutating func remove()
}
