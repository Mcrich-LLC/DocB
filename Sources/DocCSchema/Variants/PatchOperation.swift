// The kind of operation a JSON patch or variant patch applies: replace, add, or remove.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Variants/PatchOperation.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// The patch operation to apply.
///
/// Values of this type follow the [JSON Patch](https://datatracker.ietf.org/doc/html/rfc6902) format.
///
/// > Warning: The cases of this enumeration are non-exhaustive for the supported operations of JSON Patch schema. Further JSON Patch operations may
/// be added in the future.
public enum PatchOperation: String, Codable {
    /// A replacement operation.
    case replace

    /// An add operation.
    case add

    /// A removal operation.
    case remove
}
