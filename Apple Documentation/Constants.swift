//
//  Constants.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/6/24.
//

import Foundation
import SwiftUI

struct Constants {
    static let basePath = URL(string: "https://developer.apple.com/tutorials/data")!
    static let deeplinkScheme = "com.Mcrich.Apple-Documentation://"
    
    /// Fetch variant URLs based on identifier. Fundamentally, the url structure is the same, which allows finding both photo and video urls in one go.
    static func fetchPhotoVideoURL(for identifier: String, references: [String : Reference], colorScheme: ColorScheme) -> URL? {
        guard let reference = references[identifier], let variants = reference.variants else {
            return nil
        }
        if let darkVariant = variants.first(where: { $0.traits.contains("dark") }), colorScheme == .dark, let url = URL(string: darkVariant.url) {
            return url
        } else if let lightVariant = variants.first, let url = URL(string: lightVariant.url) {
            return url
        }
        
        return nil
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

extension ToolbarItemPlacement {
    static let topBarLeading: ToolbarItemPlacement = .navigation
    static let topBarTrailing: ToolbarItemPlacement = .navigation
}

extension ToolbarPlacement {
    static let navigationBar = ToolbarPlacement.windowToolbar
}

extension View {
    func listRowSpacing(_ spacing: CGFloat) -> some View {
        self
    }
}

#else
typealias PlatformColor = PlatformColor

extension Color {
    init(platformColor: PlatformColor) {
        self.init(uiColor: platformColor)
    }
}

typealias PlatformFont = PlatformFont
#endif
