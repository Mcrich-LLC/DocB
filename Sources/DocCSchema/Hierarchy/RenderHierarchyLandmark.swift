// A hierarchy tree node that represents a landmark, such as a task or heading, on a page.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Navigation Tree/RenderHierarchyLandmark.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Tolerant: string enums keep unrecognised raw values in an `unknown` case instead of failing to decode.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// A hierarchy tree node that represents a landmark on a page.
public struct RenderHierarchyLandmark: Codable, Equatable {
    /// The kind of a landmark.
    public enum Kind: TolerantStringEnum {
        /// A landmark at the start of a task.
        case task
        /// A landmark at the start of an assessment.
        case assessment
        /// A landmark to a heading in the content.
        case heading

        /// A value this version of the schema does not know. The raw string is preserved and re-encoded unchanged.
        case unknown(String)

        public init(rawValue: String) {
            switch rawValue {
            case "task": self = .task
            case "assessment": self = .assessment
            case "heading": self = .heading
            default: self = .unknown(rawValue)
            }
        }

        public var rawValue: String {
            switch self {
            case .task: "task"
            case .assessment: "assessment"
            case .heading: "heading"
            case .unknown(let rawValue): rawValue
            }
        }
    }

    /// The topic reference for the landmark.
    public var reference: RenderReferenceIdentifier

    /// The kind of landmark.
    public var kind: Kind

    /// Creates a new hierarchy landmark.
    /// - Parameters:
    ///   - reference: The topic reference for the landmark.
    ///   - kind: The kind of landmark.
    public init(reference: RenderReferenceIdentifier, kind: Kind) {
        self.reference = reference
        self.kind = kind
    }
}
