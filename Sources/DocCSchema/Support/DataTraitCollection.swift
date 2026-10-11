// A collection of environment traits (user-interface style and display scale) that describes
// which asset variant is best suited for a given rendering environment.
//
// Copied from swift-docc `Sources/SwiftDocC/Infrastructure/Bundle Assets/DataAssetManager.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Trimmed: `allCases` is a constant and the type is `Sendable`; upstream's deprecated mutable setter is removed for Swift 6 concurrency safety.
//
// Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// A collection of environment traits for an asset variant.
///
/// Traits describe properties of a rendering environment, such as a user-interface style (light or dark mode) and display-scale
/// (1x, 2x, or 3x). A trait collection is a combination of traits and describes the rendering environment in which an asset variant is best
/// suited for, e.g., an environment that uses the dark mode user-interface style and a display-scale of 3x.
public struct DataTraitCollection: Hashable, Codable, Sendable {
    /// The style associated with the user-interface.
    public var userInterfaceStyle: UserInterfaceStyle?
    
    /// The display-scale of the trait collection.
    public var displayScale: DisplayScale?
    
    /// Creates a new trait collection with traits set to their default, unspecified, values.
    public init() {
        self.userInterfaceStyle = nil
        self.displayScale = nil
    }
    
    /// Returns a new trait collection consisting of traits merged from a specified array of trait collections.
    public init(traitsFrom traitCollections: [DataTraitCollection]) {
        for trait in traitCollections {
            userInterfaceStyle = trait.userInterfaceStyle ?? userInterfaceStyle
            displayScale = trait.displayScale ?? displayScale
        }
    }
    
    /// Creates a trait collection from an array of raw values.
    public init(from rawValues: [String]) {
        for value in rawValues {
            if let validUserInterfaceStyle = UserInterfaceStyle(rawValue: value) {
                userInterfaceStyle = validUserInterfaceStyle
            } else if let validDisplayScale = DisplayScale(rawValue: value) {
                displayScale = validDisplayScale
            }
        }
    }

    /// Creates a trait collection that contains only the specified user-interface style and display-scale traits.
    public init(userInterfaceStyle: UserInterfaceStyle? = nil, displayScale: DisplayScale? = nil) {
        self.userInterfaceStyle = userInterfaceStyle
        self.displayScale = displayScale
    }
    
    /// Returns an array of raw values associated with the trait collection.
    public func toArray() -> [String] {
        var result = [String]()
        
        result.append((displayScale ?? .standard).rawValue)
        
        if let rawUserInterfaceStyle = userInterfaceStyle?.rawValue {
            result.append(rawUserInterfaceStyle)
        }
        
        return result
    }
    
    /// Returns all the asset's registered variants.
    public static let allCases: [DataTraitCollection] = UserInterfaceStyle.allCases.flatMap { style in DisplayScale.allCases.map { .init(userInterfaceStyle: style, displayScale: $0)}}
}
