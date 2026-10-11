// A reference to a resource in render JSON, looked up by identifier from a render node's
// references dictionary.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/References/RenderReference.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
//
// Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

import Foundation

/// A reference to a resource.
///
/// The reference can refer to a resource within a unit of documentation (e.g., another symbol) or an external resource (e.g., a web URL).
/// Check the conforming types to browse the different kinds of references.
public protocol RenderReference: Codable {
    /// The type of the reference.
    var type: RenderReferenceType { get }

    /// The identifier of the reference.
    ///
    /// The identifier can be used to look up a value in the render node's ``RenderNode/references`` dictionary.
    var identifier: RenderReferenceIdentifier { get }
}
