// The overrides for variants of documentation content, accumulated while encoding a tree of objects.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Variants/VariantOverrides.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// Defines the overrides for variants of documentation content.
///
/// This class can be used to accumulate override information while encoding a tree of objects.
///
/// ## Topics
///
/// ### Applying Patches
///
/// - ``RenderNodeVariantOverridesApplier``
public class VariantOverrides: Codable {
    /// The values of the variants, organized by trait.
    public var values = [VariantOverride]()

    /// Whether the collection of overrides is empty.
    public var isEmpty: Bool { values.isEmpty }

    /// Initializes a value given overrides.
    public init(values: [VariantOverride] = []) {
        add(contentsOf: values)
    }

    /// Adds the given override.
    public func add(_ variantOverride: VariantOverride) {
        if let index = values.firstIndex(where: { variantOverride.traits == $0.traits }) {
            values[index].patch.append(contentsOf: variantOverride.patch)
        } else {
            values.append(variantOverride)
        }
    }

    /// Adds the given overrides.
    public func add(
        contentsOf variantOverrides: some Collection<VariantOverride>
    ) {
        for variantOverride in variantOverrides {
            add(variantOverride)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(values)
    }

    public required init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.values = try container.decode([VariantOverride].self)
    }
}
