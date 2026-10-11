// A container for a collection of data that represent multiple ways to describe a single
// asset (for example, light/dark or 1x/2x/3x variants of an image), as referenced by render
// JSON content.
//
// Copied from swift-docc `Sources/SwiftDocC/Infrastructure/Bundle Assets/DataAssetManager.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: `data(bestMatching:)` (which returned a `BundleData` value not in this copy) is
// removed, along with the sibling `DataAssetManager` type and its file-registration logic,
// which need `DocumentationContext`/`FileManager`.
//
// Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

import Foundation

/// A container for a collection of data that represent multiple ways to describe a single asset.
///
/// Assets can be media files, source code files, or files for download.
/// A ``DataAsset`` instance represents one asset, which might be represented by multiple files. For example, a single image
/// asset might have a light and dark variants, and 1x, 2x, and 3x image sizes.
///
/// Each variant of an asset is identified by a ``DataTraitCollection`` and represents the best asset file for the given
/// combination of traits, e.g. a 2x scale image when rendered for Dark Mode.
/// 
/// ## Topics
///
/// ### Asset Traits
/// - ``DisplayScale``
/// - ``UserInterfaceStyle``
public struct DataAsset: Codable, Equatable {
    /// A context in which you intend clients to use a data asset.
    public enum Context: String, CaseIterable, Codable {
        /// An asset that a user intends to view alongside documentation content.
        case display
        /// An asset that a user intends to download.
        case download
    }
    
    /// The variants associated with the resource.
    ///
    /// An asset can have multiple variants which you can use in different environments.
    /// For example, an image asset can have distinct light and dark variants, so a renderer can select the appropriate variant
    /// depending on the system's appearance.
    public var variants = [DataTraitCollection: URL]()
    
    /// The metadata associated with each variant.
    public var metadata = [URL : Metadata]()
    
    /// The context in which you intend to use the data asset.
    public var context = Context.display
    
    /// Creates an empty asset.
    public init() {}
    
    internal init(
        variants: [DataTraitCollection : URL] = [DataTraitCollection: URL](),
        metadata: [URL : DataAsset.Metadata] = [URL : Metadata](),
        context: DataAsset.Context = Context.display
    ) {
        self.variants = variants
        self.metadata = metadata
        self.context = context
    }
    
    /// Registers a variant of the asset.
    /// - Parameters:
    ///   - url: The location of the variant.
    ///   - traitCollection: The trait collection associated with the variant.
    ///   - metadata: Metadata specific to this variant of the asset.
    public mutating func register(_ url: URL, with traitCollection: DataTraitCollection, metadata: Metadata = Metadata()) {
        variants[traitCollection] = url
        self.metadata[url] = metadata
    }
}

extension DataAsset {
    /// Metadata specific to this data asset.
    public struct Metadata: Codable, Equatable {
        /// The first ID found in the SVG asset.
        ///
        /// This value is nil if the data asset is not an SVG or if it is an SVG that does not contain an ID.
        public var svgID: String?
        
        /// Create a new data asset metadata with the given SVG ID.
        public init(svgID: String? = nil) {
            self.svgID = svgID
        }
    }
}
