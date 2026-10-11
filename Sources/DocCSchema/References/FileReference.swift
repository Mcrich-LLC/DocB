// A reference to a file resource, such as the contents of a source file shown in a tutorial step.
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

/// A reference to a file resource.
///
/// File resources are used, for example, to display the contents of a source code file in a Tutorial's step.
public struct FileReference: RenderReference, Equatable {
    /// The type of this file reference.
    ///
    /// This value is always `.file`.
    public var type: RenderReferenceType = .file

    /// The identifier of this reference.
    public var identifier: RenderReferenceIdentifier

    /// The name of the file.
    public var fileName: String

    /// The type of the file, typically represented by its file extension.
    public var fileType: String

    /// The syntax for the content in the file, for example "swift".
    ///
    /// You can use this value to identify the syntax of the content. This would allow, for example, a renderer to perform syntax highlighting of the file's content.
    public var syntax: String

    /// The line-by-line contents of the file.
    public var content: [String]

    /// The line highlights for this file.
    public var highlights: [LineHighlighter.Highlight] = []

    /// Creates a new file reference.
    ///
    /// - Parameters:
    ///   - identifier: The identifier for this file reference.
    ///   - fileName: The name of the references file.
    ///   - fileType: The type of file, typically represented by its file extension.
    ///   - syntax: The syntax of the file's content.
    ///   - content: The line-by-line contents of the file.
    ///   - highlights: The line highlights for this file.
    public init(
        identifier: RenderReferenceIdentifier,
        fileName: String,
        fileType: String,
        syntax: String,
        content: [String],
        highlights: [LineHighlighter.Highlight] = []
    ) {
        self.identifier = identifier
        self.fileName = fileName
        self.fileType = fileType
        self.syntax = syntax
        self.content = content
        self.highlights = highlights
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        type = try values.decode(RenderReferenceType.self, forKey: .type)
        identifier = try values.decode(RenderReferenceIdentifier.self, forKey: .identifier)
        fileName = try values.decode(String.self, forKey: .fileName)
        fileType = try values.decode(String.self, forKey: .fileType)
        syntax = try values.decode(String.self, forKey: .syntax)
        content = try values.decode([String].self, forKey: .content)
        highlights = try values.decodeIfPresent([LineHighlighter.Highlight].self, forKey: .highlights) ?? []
    }
}
