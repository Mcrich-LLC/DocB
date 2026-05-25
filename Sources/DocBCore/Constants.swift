//
//  Constants.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/6/24.
//

import Foundation
import SwiftUI
import DocCKit

/// Scene and window identifiers used by the app.
public struct WindowTypes {
    /// Secondary window for adding custom DocC sources.
    public static let addSites = "add_sites"
    /// Main documentation browsing window.
    public static let main = "main"
    /// macOS Open Quickly search palette window.
    public static let searchPalette = "search_palette"
}

/// Defines app-wide constants and URL helpers for loading documentation resources.
public struct Constants {
    /// Custom deep-link scheme used to route in-app documentation links.
    public static let deeplinkScheme = "com.Mcrich.Apple-Documentation://"
    
    /// Fetch variant URLs based on identifier. Fundamentally, the url structure is the same, which allows finding both photo and video urls in one go.
    public static func fetchPhotoVideoURL(for identifier: String, references: [String : Reference], colorScheme: ColorScheme, docCSite: DocCSource?) -> URL? {
        guard let reference = references[identifier], let variants = reference.variants else {
            return nil
        }
        
        var mainUrl: URL?
        
        if let darkVariant = variants.first(where: { $0.traits.contains("dark") }), colorScheme == .dark, let url = URL(string: darkVariant.url) {
            mainUrl = url
        } else if let lightVariant = variants.first, let url = URL(string: lightVariant.url) {
            mainUrl = url
        }
        
        if mainUrl?.host() == nil, let url = mainUrl, let docCSite {
            mainUrl = URL(string: "\(docCSite.url)\(url.path)")
        }
        
        return mainUrl
    }
}

#if canImport(AppKit)
public typealias PlatformColor = NSColor
extension NSColor {
    public static let systemBackground = NSColor.windowBackgroundColor
    public static let separator = NSColor.separatorColor
}

extension Color {
    public init(platformColor: PlatformColor) {
        self.init(nsColor: platformColor)
    }
}

public typealias PlatformFont = NSFont

extension ToolbarPlacement {
    @MainActor public static let navigationBar = ToolbarPlacement.windowToolbar
}

extension View {
    public func listRowSpacing(_ spacing: CGFloat) -> some View {
        self
    }
}

#elseif canImport(UIKit)
public typealias PlatformColor = UIColor

extension Color {
    public init(platformColor: PlatformColor) {
        self.init(uiColor: platformColor)
    }
}

extension UIColor {
    public convenience init?(named: String, bundle: Bundle = .main) {
        self.init(named: named, in: bundle, compatibleWith: .current)
    }
}

public typealias PlatformFont = UIFont
#endif

extension PlatformColor {
    #if os(visionOS)
    public static let accent = PlatformColor(named: "AccentColor_visionOS", bundle: .module)!
    #else
    public static let accent = PlatformColor(named: "AccentColor", bundle: .module)!
    #endif
    
    public static let homepageBackground = PlatformColor(named: "Homepage Background", bundle: .module)!
    public static let article = PlatformColor(named: "Article", bundle: .module)!
    public static let collection = PlatformColor(named: "Collection", bundle: .module)!
    public static let collectionGroup = PlatformColor(named: "CollectionGroup", bundle: .module)!
    public static let sampleCode = PlatformColor(named: "SampleCode", bundle: .module)!
}

extension ShapeStyle where Self == Color {
    public static var accent: Self { .accent }
    public static var homepageBackground: Self { .homepageBackground }
    public static var article: Self { .article }
    public static var collection: Self { .collection }
    public static var collectionGroup: Self { .collectionGroup }
    public static var sampleCode: Self { .sampleCode }
}

extension Color {
    public static let accent = Self(platformColor: .accent)
    public static let homepageBackground = Self(platformColor: .homepageBackground)
    public static let article = Self(platformColor: .article)
    public static let collection = Self(platformColor: .collection)
    public static let collectionGroup = Self(platformColor: .collectionGroup)
    public static let sampleCode = Self(platformColor: .sampleCode)
}
