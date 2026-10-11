// A reference to a type of file (not a specific file), used to display an icon for that file
// type alongside a file's content.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/References/FileReference.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: the RenderJSONDiffable conformance.
//
// Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

import Foundation

/// A reference to a type of file.
///
/// This is not a reference to a specific file, but rather to a type of file. Use a file type reference together with a file reference to display an icon for that file type
/// alongside the content of that file. For example, a property list file icon alongside the content of a specific property list file.
public struct FileTypeReference: RenderReference, Equatable {
    public var type: RenderReferenceType = .fileType

    /// The identifier of this reference.
    public var identifier: RenderReferenceIdentifier

    /// The display name of the file type.
    public var displayName: String

    /// The icon for this file type, encoded in Base64.
    public var iconBase64: Data

    /// Creates a new file type reference.
    /// - Parameters:
    ///   - identifier: The identifier of this reference.
    ///   - displayName: The display name of the file type.
    ///   - iconBase64: The icon for this file type, encoded in Base64.
    public init(identifier: RenderReferenceIdentifier, displayName: String, iconBase64: Data) {
        self.identifier = identifier
        self.displayName = displayName
        self.iconBase64 = iconBase64
    }
}
