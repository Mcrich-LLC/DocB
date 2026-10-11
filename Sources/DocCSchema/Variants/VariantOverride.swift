// An override for a JSON value for a set of traits.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Variants/VariantOverride.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// Defines an override for a JSON value for a set of traits.
///
/// Override values are contain the ``patch`` that should be applied for clients that want to process documentation for the override's ``traits``.
public struct VariantOverride: Codable {
    /// The traits associated with the override.
    public var traits: [RenderNode.Variant.Trait]

    /// The patch to apply as part of the override.
    public var patch: JSONPatch

    /// Creates an override value for the given traits.
    ///
    /// - Parameters:
    ///   - traits: The traits associated with this override value.
    ///   - patch: The patch to apply as part of the override.
    public init(traits: [RenderNode.Variant.Trait], patch: JSONPatch) {
        self.traits = traits
        self.patch = patch
    }
}
