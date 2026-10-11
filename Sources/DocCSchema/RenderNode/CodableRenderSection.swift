// A Codable container that type-erases a RenderSection value, dispatching decode to the correct
// concrete tutorial-page section based on its `kind`.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/RenderNode/CodableRenderSection.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Tolerant: unknown values are preserved instead of failing to decode.
// Extended: decodes the developer.apple.com section kinds (see AppleDeveloper/).
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

import Foundation

/// A Codable container for sections within a Tutorial page.
internal struct CodableRenderSection: Codable {
    internal var section: any RenderSection

    internal init(_ section: any RenderSection) {
        self.section = section
    }

    internal init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(RenderSectionKind.self, forKey: .kind)

        switch kind {
        case .hero, .intro:
            section = try IntroRenderSection(from: decoder)
        case .tasks:
            section = try TutorialSectionsRenderSection(from: decoder)
        case .assessments:
            section = try TutorialAssessmentsRenderSection(from: decoder)
        case .volume:
            section = try VolumeRenderSection(from: decoder)
        case .contentAndMedia:
            section = try ContentAndMediaSection(from: decoder)
        case .contentAndMediaGroup:
            section = try ContentAndMediaGroupSection(from: decoder)
        case .callToAction:
            section = try CallToActionSection(from: decoder)
        case .articleBody:
            section = try TutorialArticleSection(from: decoder)
        case .resources:
            section = try ResourcesRenderSection(from: decoder)
        // AppleDeveloper:
        case .section:
            section = try HomepageRenderSection(from: decoder)
        case .homepageResources:
            section = try HomepageResourcesRenderSection(from: decoder)
        case .technologies:
            section = try TechnologiesRenderSection(from: decoder)
        default:
            section = try UnknownRenderSection(from: decoder)
        }
    }

    private enum CodingKeys: CodingKey {
        case kind
    }

    internal func encode(to encoder: any Encoder) throws {
        try section.encode(to: encoder)
    }
}
