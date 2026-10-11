// The introductory hero section of a tutorial page, with its title, image, and optional video.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Tutorial/Sections/IntroRenderSection.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: the RenderJSONDiffable conformance is removed.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// A generic high impact section that may be rendered differently depending on the page type.
public struct IntroRenderSection: RenderSection, Equatable {
    public let kind: RenderSectionKind = .hero

    /// The title of the intro.
    public var title: String

    /// If defined for a Tutorial page, the parent chapter of the tutorial.
    public var chapter: String?

    /// An estimation, in minutes, of how much time is needed to read a documentation page.
    public var estimatedTimeInMinutes: Int?

    /// An Xcode requirement.
    ///
    /// This is the minimum version of Xcode that is required in order to follow this tutorial.
    public var xcodeRequirement: RenderReferenceIdentifier?

    /// An image to display behind the section.
    public var backgroundImage: RenderReferenceIdentifier?

    /// An action to perform.
    public var action: RenderInlineContent?

    /// A key image to display.
    public var image: RenderReferenceIdentifier?

    /// A video to display modally.
    public var video: RenderReferenceIdentifier?

    /// A project download reference, if available.
    public var projectFiles: RenderReferenceIdentifier?

    /// Arbitrary content to display under the subheading.
    public var content: [RenderBlockContent] = []

    /// Creates a new generic introductory section.
    ///
    /// - Parameter title: The title of the section.
    public init(title: String) {
        self.title = title
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        chapter = try container.decodeIfPresent(String.self, forKey: .chapter)
        estimatedTimeInMinutes = try container.decodeIfPresent(Int.self, forKey: .estimatedTimeInMinutes)
        xcodeRequirement = try container.decodeIfPresent(RenderReferenceIdentifier.self, forKey: .xcodeRequirement)
        backgroundImage = try container.decodeIfPresent(RenderReferenceIdentifier.self, forKey: .backgroundImage)
        action = try container.decodeIfPresent(RenderInlineContent.self, forKey: .action)
        image = try container.decodeIfPresent(RenderReferenceIdentifier.self, forKey: .image)
        video = try container.decodeIfPresent(RenderReferenceIdentifier.self, forKey: .video)
        projectFiles = try container.decodeIfPresent(RenderReferenceIdentifier.self, forKey: .projectFiles)
        content = try container.decodeIfPresent([RenderBlockContent].self, forKey: .content) ?? []
    }
}
