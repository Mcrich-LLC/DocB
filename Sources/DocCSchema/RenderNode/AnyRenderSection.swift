// A type-erased RenderSection wrapper, used internally by CodableContentSection to hold a
// concrete section value behind the `any RenderSection` existential.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Diffing/AnyRenderSection.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Tolerant: equality uses conditional casts, compares unknown sections by their JSON, and never traps.
// Extended: compares the developer.apple.com section kinds (see AppleDeveloper/).
// Trimmed: dropped the `RenderJSONDiffable` conformance and its `difference(from:at:)` and
// `isSimilar(to:)` methods; kept only the type-erased wrapper, `Encodable`, and `Equatable`.
//
// Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// A type-erased RenderSection value.
internal struct AnyRenderSection: Equatable, Encodable {
    internal var value: any RenderSection

    internal init(_ value: any RenderSection) {
        self.value = value
    }

    internal func encode(to encoder: any Encoder) throws {
        try value.encode(to: encoder)
    }

    internal static func == (lhs: AnyRenderSection, rhs: AnyRenderSection) -> Bool {
        // Tolerant: conditional casts instead of forced ones, so a mismatched pair compares unequal rather than trapping.
        func equal<T: RenderSection & Equatable>(_: T.Type) -> Bool {
            guard let lhsValue = lhs.value as? T, let rhsValue = rhs.value as? T else { return false }
            return lhsValue == rhsValue
        }

        switch (lhs.value.kind, rhs.value.kind) {

        // MARK: Symbol Sections

        case (.attributes, .attributes):
            return equal(AttributesRenderSection.self)
        case (.discussion, .discussion), (.content, .content):
            return equal(ContentRenderSection.self)
        case (.declarations, .declarations):
            return equal(DeclarationsRenderSection.self)
        case (.parameters, .parameters):
            return equal(ParametersRenderSection.self)
        case (.plistDetails, .plistDetails):
            return equal(PropertyListDetailsRenderSection.self)
        case (.possibleValues, .possibleValues):
            return equal(PossibleValuesRenderSection.self)
        case (.relationships, .relationships):
            return equal(RelationshipsRenderSection.self)
        case (.restBody, .restBody):
            return equal(RESTBodyRenderSection.self)
        case (.restEndpoint, .restEndpoint):
            return equal(RESTEndpointRenderSection.self)
        case (.restParameters, .restParameters):
            return equal(RESTParametersRenderSection.self)
        case (.restResponses, .restResponses):
            return equal(RESTResponseRenderSection.self)
        case (.sampleDownload, .sampleDownload):
            return equal(SampleDownloadSection.self)
        case (.taskGroup, .taskGroup):
            return equal(TaskGroupRenderSection.self)
        case (.mentions, .mentions):
            return equal(MentionsRenderSection.self)

        // MARK: Tutorial Sections

        case (.intro, .intro), (.hero, .hero):
            return equal(IntroRenderSection.self)
        case (.assessments, .assessments):
            return equal(TutorialAssessmentsRenderSection.self)
        case (.tasks, .tasks):
            return equal(TutorialSectionsRenderSection.self)

        // MARK: Tutorial Article Sections

        case (.articleBody, .articleBody):
            return equal(TutorialArticleSection.self)

        // MARK: Tutorials Overview Sections

        case (.callToAction, .callToAction):
            return equal(CallToActionSection.self)
        case (.contentAndMediaGroup, .contentAndMediaGroup):
            return equal(ContentAndMediaGroupSection.self)
        case (.contentAndMedia, .contentAndMedia):
            return equal(ContentAndMediaSection.self)
        case (.resources, .resources):
            return equal(ResourcesRenderSection.self)
        case (.volume, .volume):
            return equal(VolumeRenderSection.self)

        // AppleDeveloper:
        case (.section, .section):
            return equal(HomepageRenderSection.self)
        case (.homepageResources, .homepageResources):
            return equal(HomepageResourcesRenderSection.self)
        case (.technologies, .technologies):
            return equal(TechnologiesRenderSection.self)

        // Tolerant: sections of unrecognised kinds compare by their preserved JSON.
        case (.unknown, .unknown):
            return equal(UnknownRenderSection.self)

        default:
            return false
        }
    }
}
