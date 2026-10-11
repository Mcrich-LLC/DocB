// A single line's highlight, as it appears in a tutorial step's code listing in render JSON.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Tutorial/LineHighlighter.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: this keeps only the nested `Highlight` type. The diff-computing highlighter logic
// itself (which needs `DocumentationContext`, `TutorialSection`, and `ResolvedTopicReference`
// resolution) is removed, along with the private `Result` type and `Code`/file-diffing methods.
//
// Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// A utility type that computes highlighted lines for diffs between ``Code``
/// elements in a ``TutorialSection``'s ``Step``s.
public struct LineHighlighter {
    /// A single line's highlight.
    public struct Highlight: Codable, Equatable {
        /// The line to highlight.
        public let line: Int
        
        /// If non-`nil`, the column to start the highlight.
        public let start: Int?
        
        /// If non-`nil`, the length of the highlight in columns.
        public let length: Int?
        
        /// Creates a new highlight for a single line.
        ///
        /// - Parameters:
        ///   - line: The line to highlight.
        ///   - start: The column in which to start the highlight.
        ///   - length: The character length of the highlight.
        public init(line: Int, start: Int? = nil, length: Int? = nil) {
            self.line = line
            self.start = start
            self.length = length
        }
    }
}
