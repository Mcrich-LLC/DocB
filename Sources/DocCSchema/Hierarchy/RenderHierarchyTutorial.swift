// A hierarchy tree node that represents a tutorial or a tutorial article.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Navigation Tree/RenderHierarchyTutorial.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// A hierarchy tree node that represents a tutorial or a tutorial article.
public struct RenderHierarchyTutorial: Codable, Equatable {
    /// The topic reference.
    public var reference: RenderReferenceIdentifier

    /// The landmarks on the page.
    public var landmarks: [RenderHierarchyLandmark] = []

    private enum CodingKeys: String, CodingKey {
        case reference
        case landmarks = "sections"
    }

    /// Creates a new tutorial or tutorial article.
    /// - Parameter identifier: The topic reference.
    public init(identifier: RenderReferenceIdentifier) {
        self.reference = identifier
    }
}
