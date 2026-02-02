//
//  Constants.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/6/24.
//

import Foundation
import SwiftUI

/// A collection of shared constants and configuration values for the application.
struct Constants {
    /// The base URL for fetching documentation data.
    static let basePath = URL(string: "https://developer.apple.com/tutorials/data")!
    /// The custom scheme used for deep linking into the application.
    static let deeplinkScheme = "com.Mcrich.Apple-Documentation://"
    
    /// Fetches the URL for a photo or video variant based on the current context.
    ///
    /// This method resolves the appropriate URL by checking for dark/light mode traits and appending the base URL if necessary.
    ///
    /// - Parameters:
    ///   - identifier: The identifier of the reference containing the variants.
    ///   - references: A dictionary of available references.
    ///   - colorScheme: The current color scheme (light or dark).
    ///   - docCSite: The DocC site configuration, if applicable.
    /// - Returns: A `URL` pointing to the media resource, or `nil` if not found.
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
