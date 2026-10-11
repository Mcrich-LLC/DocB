// A node that represents API symbol hierarchy, as a set of breadcrumb paths to the current page.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Navigation Tree/RenderReferenceHierarchy.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: the RenderJSONDiffable conformance is removed.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// A node that represents API symbol hierarchy.
public struct RenderReferenceHierarchy: Codable, Equatable {
    /// The paths (breadcrumbs) that lead from the landing page to the given symbol.
    ///
    /// A single path is a list of topic-graph references, that trace the curation
    /// through the documentation hierarchy from a framework landing page to a
    /// given target symbol.
    ///
    /// Symbols curated multiple times have multiple paths, for example:
    ///  - Example Framework / Example Type / Example Property
    ///  - Example Framework / My Article / Example Type / Example Property
    ///  - Example Framework / Related Type / Example Property
    /// > Note: The first element in `paths` is the _canonical_ breadcrumb for the symbol.
    ///
    /// Landing pages' hierarchy contains a single, empty path.
    public let paths: [[String]]
}
