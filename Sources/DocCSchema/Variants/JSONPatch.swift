// A patch to update a JSON value, expressed as an ordered list of patch operations.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Variants/JSONPatchOperation.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
//
// Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// A patch to update a JSON value.
public typealias JSONPatch = [JSONPatchOperation]
