// The `metadata.json` DocC writes at the root of a built archive or static site: the bundle's
// display name and identifier. Discovery uses it to recognise a DocC site that predates the
// navigator index.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/BuildMetadata.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: `bundleID` is a plain `String` coded as `bundleIdentifier` (upstream wraps it in
// `DocumentationContext.Inputs.Identifier`, which is outside this package).
//
// Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

import Foundation

/// A value that encapsulates metadata for a documentation archive that DocC built.
public struct BuildMetadata: Codable, Equatable {
    
    /// The current version of the build metadata schema.
    public var schemaVersion = SemanticVersion(
        major: 0,
        minor: 1,
        patch: 0
    )
    
    /// The display name of the documentation archive that DocC built.
    public var bundleDisplayName: String
    
    /// The bundle identifier of the documentation archive that DocC built.
    public let bundleID: String

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, bundleDisplayName
        case bundleID = "bundleIdentifier"
    }
    
    /// Creates a build metadata value for a documentation archive built by DocC.
    ///
    /// - Parameters:
    ///   - bundleDisplayName: The display name of the documentation archive.
    ///   - bundleID: The bundle identifier of the documentation archive.
    public init(bundleDisplayName: String, bundleID: String) {
        self.bundleDisplayName = bundleDisplayName
        self.bundleID = bundleID
    }
}
