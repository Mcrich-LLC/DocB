// A reference to a video asset, including its size/appearance variants and an optional poster
// image.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/References/VideoReference.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: the RenderJSONDiffable conformances.
//
// Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

import Foundation

/// A reference to a video.
public struct VideoReference: MediaReference, URLReference, Equatable {
    /// The type of this video reference.
    ///
    /// This value is always `.video`.
    public var type: RenderReferenceType = .video

    /// The identifier of this reference.
    public var identifier: RenderReferenceIdentifier

    /// Alternate text for the video.
    ///
    /// This text helps screen readers describe the video.
    public var altText: String?

    /// The data associated with this asset, including its variants.
    public var asset: DataAsset

    /// The reference to a poster image for this video.
    public var poster: RenderReferenceIdentifier?

    /// Creates a new video reference.
    ///
    /// - Parameters:
    ///   - identifier: The identifier for this video reference.
    ///   - altText: Alternate text for the video.
    ///   - asset: The data associated with this asset, including its variants.
    ///   - poster: The reference to a poster image for this video.
    public init(identifier: RenderReferenceIdentifier, altText: String? = nil, videoAsset asset: DataAsset, poster: RenderReferenceIdentifier?) {
        self.identifier = identifier
        self.asset = asset
        self.altText = altText
        self.poster = poster
    }

    internal enum CodingKeys: String, CodingKey {
        case type
        case identifier
        case alt
        case variants
        case poster
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        type = try values.decode(RenderReferenceType.self, forKey: .type)
        identifier = try values.decode(RenderReferenceIdentifier.self, forKey: .identifier)
        altText = try values.decodeIfPresent(String.self, forKey: .alt)

        // rebuild the data asset
        asset = DataAsset()
        let variants = try values.decode([VariantProxy].self, forKey: .variants)
        for variant in variants {
            asset.register(variant.url, with: DataTraitCollection(from: variant.traits))
        }

        poster = try values.decodeIfPresent(RenderReferenceIdentifier.self, forKey: .poster)
    }

    /// The relative URL to the folder that contains all images in the built documentation output.
    public static let baseURL = URL(string: "/videos/")!

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type.rawValue, forKey: .type)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(altText, forKey: .alt)

        // convert the data asset to a serializable object
        var result = [VariantProxy]()
        for (key, value) in asset.variants {
            let url = renderURL(for: value, prefixComponent: encoder.assetPrefixComponent)
            result.append(VariantProxy(url: url, traits: key))
        }
        result.sort(by: VariantProxy.areInIncreasingOrder)

        try container.encode(result, forKey: .variants)

        try container.encode(poster, forKey: .poster)
    }

    /// A codable proxy value that the video reference uses to serialize information about its asset variants.
    public struct VariantProxy: MediaVariantProxy, Codable, Equatable {
        /// The URL to the file for this video variant.
        public var url: URL
        /// The traits of this video reference.
        public var traits: [String]

        /// Creates a new proxy value with the given information about a video variant.
        ///
        /// - Parameters:
        ///   - url: The URL to the file for this video variant.
        ///   - traits: The traits of this video reference.
        internal init(url: URL, traits: DataTraitCollection) {
            self.url = url
            self.traits = traits.toArray()
        }

        internal enum CodingKeys: String, CodingKey {
            case size
            case url
            case traits
        }

        public init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            url = try values.decode(URL.self, forKey: .url)
            traits = try values.decode([String].self, forKey: .traits)
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(url, forKey: .url)
            try container.encode(traits, forKey: .traits)
        }
    }
}
