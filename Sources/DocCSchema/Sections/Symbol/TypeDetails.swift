// A type's details, including whether it's an array, and optionally the element's type.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Symbol/PropertiesRenderSection.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// A type's details, including whether it's an array, and optionally the element's type.
public struct TypeDetails: Codable, Equatable {
    /// A base type name.
    ///
    /// The plain text name of a symbol's base type. For example, `Int` for an array of integers.
    public var baseType: String?
    /// If true, the type is an array.
    public var arrayMode: Bool? = false
}
