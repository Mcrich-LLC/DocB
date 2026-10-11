// The kind discriminator used to decode a type-erased RenderSection into its concrete type.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/RenderSection.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Tolerant: string enums keep unrecognised raw values in an `unknown` case instead of failing to decode.
// Extended: `section`, `homepageResources`, and `technologies` for developer.apple.com payloads (see AppleDeveloper/).
// Split: extracted from RenderSection.swift, which also declares the `RenderSection` protocol.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

public enum RenderSectionKind: TolerantStringEnum {
    // Article render sections
    case hero, intro, tasks, assessments, volume, contentAndMedia, contentAndMediaGroup, callToAction, tile, articleBody, resources

    // Symbol render sections
    case mentions, discussion, content, taskGroup, relationships, declarations, parameters, sampleDownload, row

    // Rest symbol sections
    case restParameters, restResponses, restBody, restEndpoint, properties

    // Plist
    case plistDetails, attributes, possibleValues

    // AppleDeveloper: developer.apple.com homepage and technologies catalog sections
    case section, homepageResources, technologies

    /// A value this version of the schema does not know. The raw string is preserved and re-encoded unchanged.
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "hero": self = .hero
        case "intro": self = .intro
        case "tasks": self = .tasks
        case "assessments": self = .assessments
        case "volume": self = .volume
        case "contentAndMedia": self = .contentAndMedia
        case "contentAndMediaGroup": self = .contentAndMediaGroup
        case "callToAction": self = .callToAction
        case "tile": self = .tile
        case "articleBody": self = .articleBody
        case "resources": self = .resources
        case "mentions": self = .mentions
        case "discussion": self = .discussion
        case "content": self = .content
        case "taskGroup": self = .taskGroup
        case "relationships": self = .relationships
        case "declarations": self = .declarations
        case "parameters": self = .parameters
        case "sampleDownload": self = .sampleDownload
        case "row": self = .row
        case "restParameters": self = .restParameters
        case "restResponses": self = .restResponses
        case "restBody": self = .restBody
        case "restEndpoint": self = .restEndpoint
        case "properties": self = .properties
        case "details": self = .plistDetails
        case "attributes": self = .attributes
        case "possibleValues": self = .possibleValues
        case "section": self = .section
        case "homepageResources": self = .homepageResources
        case "technologies": self = .technologies
        default: self = .unknown(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .hero: "hero"
        case .intro: "intro"
        case .tasks: "tasks"
        case .assessments: "assessments"
        case .volume: "volume"
        case .contentAndMedia: "contentAndMedia"
        case .contentAndMediaGroup: "contentAndMediaGroup"
        case .callToAction: "callToAction"
        case .tile: "tile"
        case .articleBody: "articleBody"
        case .resources: "resources"
        case .mentions: "mentions"
        case .discussion: "discussion"
        case .content: "content"
        case .taskGroup: "taskGroup"
        case .relationships: "relationships"
        case .declarations: "declarations"
        case .parameters: "parameters"
        case .sampleDownload: "sampleDownload"
        case .row: "row"
        case .restParameters: "restParameters"
        case .restResponses: "restResponses"
        case .restBody: "restBody"
        case .restEndpoint: "restEndpoint"
        case .properties: "properties"
        case .plistDetails: "details"
        case .attributes: "attributes"
        case .possibleValues: "possibleValues"
        case .section: "section"
        case .homepageResources: "homepageResources"
        case .technologies: "technologies"
        case .unknown(let rawValue): rawValue
        }
    }
}
