//
//  Constants.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/6/24.
//

import Foundation
import SwiftUI
import PrivateObfuscationMacro

/// Defines app-wide constants and URL helpers for loading documentation resources.
struct Constants {
    /// Base URL for Apple Developer Documentation.
    static let aDeveloperURLBase = #base64Encoded("https://developer.apple.com")!
    /// Legacy tutorials data endpoint used by older Apple payloads.
    static let basePath = URL(string: "\(Constants.aDeveloperURLBase)/tutorials/data")!
    /// Custom deep-link scheme used to route in-app documentation links.
    static let deeplinkScheme = "com.Mcrich.Apple-Documentation://"
    
    /// Fetch variant URLs based on identifier. Fundamentally, the url structure is the same, which allows finding both photo and video urls in one go.
    static func fetchPhotoVideoURL(for identifier: String, references: [String : Reference], colorScheme: ColorScheme, docCSite: DocCSiteDTO?) -> URL? {
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
typealias PlatformColor = NSColor
extension NSColor {
    static let systemBackground = NSColor.windowBackgroundColor
    static let separator = NSColor.separatorColor
}

extension Color {
    init(platformColor: PlatformColor) {
        self.init(nsColor: platformColor)
    }
}

typealias PlatformFont = NSFont

extension ToolbarPlacement {
    @MainActor static let navigationBar = ToolbarPlacement.windowToolbar
}

extension View {
    func listRowSpacing(_ spacing: CGFloat) -> some View {
        self
    }
}

#elseif canImport(UIKit)
typealias PlatformColor = UIColor

extension Color {
    init(platformColor: PlatformColor) {
        self.init(uiColor: platformColor)
    }
}

typealias PlatformFont = UIFont
#endif

extension PlatformColor {
    #if os(visionOS)
    static let accent = PlatformColor(named: "AccentColor_visionOS")!
    #else
    static let accent = PlatformColor(named: "AccentColor")!
    #endif
    
    static let homepageBackground = PlatformColor(named: "Homepage Background")!
    static let article = PlatformColor(named: "Article")!
    static let collection = PlatformColor(named: "Collection")!
    static let collectionGroup = PlatformColor(named: "CollectionGroup")!
    static let sampleCode = PlatformColor(named: "SampleCode")!
}

extension ShapeStyle where Self == Color {
    static var accent: Self { .accent }
    static var homepageBackground: Self { .homepageBackground }
    static var article: Self { .article }
    static var collection: Self { .collection }
    static var collectionGroup: Self { .collectionGroup }
    static var sampleCode: Self { .sampleCode }
}

extension Color {
    static let accent = Self(platformColor: .accent)
    static let homepageBackground = Self(platformColor: .homepageBackground)
    static let article = Self(platformColor: .article)
    static let collection = Self(platformColor: .collection)
    static let collectionGroup = Self(platformColor: .collectionGroup)
    static let sampleCode = Self(platformColor: .sampleCode)
}
