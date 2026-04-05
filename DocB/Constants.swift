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

#if os(macOS)
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

#else
typealias PlatformColor = UIColor

extension Color {
    init(platformColor: PlatformColor) {
        self.init(uiColor: platformColor)
    }
}

typealias PlatformFont = UIFont
#endif
