// A task group section that contains links to other symbols.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Symbol/TaskGroupRenderSection.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: `init(title:abstract:discussion:identifiers:generated:anchor:)` no longer falls back
// to `title.map(urlReadableFragment)` when `anchor` is nil (a free function outside the copy
// set) and instead stores `anchor` as given; `init(from:)`'s call to
// `decoder.registerReferences(_:)` (outside the copy set) is removed; the
// `init(taskGroup:)` extension (which referenced `AutomaticCuration.TaskGroup`, outside the
// copy set) and the RenderJSONDiffable conformance are also removed.
//
// Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// A task group section that contains links to other symbols.
public struct TaskGroupRenderSection: RenderSection, Equatable {
    public let kind: RenderSectionKind = .taskGroup

    /// An optional title for the section.
    public var title: String?
    /// An optional abstract summary for the section.
    public var abstract: [RenderInlineContent]?
    /// An optional discussion for the section.
    public var discussion: (any RenderSection)? {
        get {
            typeErasedSection?.value
        }
        set {
            if let newValue {
                typeErasedSection = AnyRenderSection(newValue)
            } else {
                typeErasedSection = nil
            }
        }
    }

    private var typeErasedSection: AnyRenderSection?

    /// A list of topic graph references.
    public let identifiers: [String]
    /// If true, this is an automatically generated group. If false, this is an authored group.
    public let generated: Bool
    /// An optional anchor that can be used to link to the task group.
    public let anchor: String?

    /// Creates a new task group.
    /// - Parameters:
    ///   - title: An optional title for the section.
    ///   - abstract: An optional abstract summary for the section.
    ///   - discussion: An optional discussion for the section.
    ///   - identifiers: A list of topic-graph references.
    ///   - generated: If `true`, this is an automatically generated group. If `false`, this is an authored group.
    ///   - anchor: An optional anchor that can be used to link to the task group.
    public init(title: String?, abstract: [RenderInlineContent]?, discussion: (any RenderSection)?, identifiers: [String], generated: Bool = false, anchor: String? = nil) {
        self.title = title
        self.abstract = abstract
        self.identifiers = identifiers
        self.generated = generated
        self.anchor = anchor
        self.discussion = discussion
    }

    /// The list of keys you use to encode or decode this section.
    private enum CodingKeys: CodingKey {
        case title, abstract, discussion, identifiers, generated, anchor
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(abstract, forKey: .abstract)
        try container.encodeIfPresent(discussion.map(CodableRenderSection.init), forKey: .discussion)
        try container.encode(identifiers, forKey: .identifiers)
        if generated {
            try container.encode(generated, forKey: .generated)
        }
        try container.encodeIfPresent(anchor, forKey: .anchor)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        title = try container.decodeIfPresent(String.self, forKey: .title)
        abstract = try container.decodeIfPresent([RenderInlineContent].self, forKey: .abstract)
        identifiers = try container.decode([String].self, forKey: .identifiers)

        generated = try container.decodeIfPresent(Bool.self, forKey: .generated) ?? false
        anchor = try container.decodeIfPresent(String.self, forKey: .anchor)
        discussion = (try container.decodeIfPresent(CodableContentSection.self, forKey: .discussion)).map { $0.section }
    }
}
