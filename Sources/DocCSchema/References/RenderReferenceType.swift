// The type of a render reference, used to discriminate the kinds of resources a
// documentation page can reference.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/References/RenderReference.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Tolerant: string enums keep unrecognised raw values in an `unknown` case instead of failing to decode.
//
// Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// The type of a reference.
public enum RenderReferenceType: TolerantStringEnum {
    case image, video, file, fileType, xcodeRequirement, topic, section, download, link, externalLocation
    case unresolvable

    /// A value this version of the schema does not know. The raw string is preserved and re-encoded unchanged.
    case unknown(String)

    public init(rawValue: String) {
        switch rawValue {
        case "image": self = .image
        case "video": self = .video
        case "file": self = .file
        case "fileType": self = .fileType
        case "xcodeRequirement": self = .xcodeRequirement
        case "topic": self = .topic
        case "section": self = .section
        case "download": self = .download
        case "link": self = .link
        case "externalLocation": self = .externalLocation
        case "unresolvable": self = .unresolvable
        default: self = .unknown(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .image: "image"
        case .video: "video"
        case .file: "file"
        case .fileType: "fileType"
        case .xcodeRequirement: "xcodeRequirement"
        case .topic: "topic"
        case .section: "section"
        case .download: "download"
        case .link: "link"
        case .externalLocation: "externalLocation"
        case .unresolvable: "unresolvable"
        case .unknown(let rawValue): rawValue
        }
    }
}
