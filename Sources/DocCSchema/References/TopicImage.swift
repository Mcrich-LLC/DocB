// A custom authored image (icon or card) that can be associated with a documentation topic.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/References/TopicImage.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Tolerant: string enums keep unrecognised raw values in an `unknown` case instead of failing to decode.
// Trimmed: the `init(pageImagePurpose:identifier:)` and `init?(pageImage:with:in:)` initializers,
// which convert from the semantic `PageImage` type.
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// A custom authored image that can be associated with a documentation topic.
///
/// Allows an author to provide a custom icon or card image for a given documentation page.
public struct TopicImage: Codable, Hashable {
    /// The type of this topic image.
    public let type: TopicImageType

    /// The reference identifier for the image.
    public var identifier: RenderReferenceIdentifier

    /// Create a new topic image with the given type and reference identifier.
    public init(
        type: TopicImage.TopicImageType,
        identifier: RenderReferenceIdentifier
    ) {
        self.type = type
        self.identifier = identifier
    }
}

extension TopicImage {
    /// The type of topic image.
    public enum TopicImageType: TolerantStringEnum {
        /// An icon image that should be used to represent this page wherever a default icon
        /// is currently used.
        case icon

        /// An icon image that should be used to represent this page wherever a default icon
        /// is currently used.
        case card

        /// A value this version of the schema does not know. The raw string is preserved and re-encoded unchanged.
        case unknown(String)

        public init(rawValue: String) {
            switch rawValue {
            case "icon": self = .icon
            case "card": self = .card
            default: self = .unknown(rawValue)
            }
        }

        public var rawValue: String {
            switch self {
            case .icon: "icon"
            case .card: "card"
            case .unknown(let rawValue): rawValue
            }
        }
    }
}
