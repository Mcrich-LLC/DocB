import SwiftUI

#if canImport(AppKit)
public typealias PlatformColor = NSColor
public typealias PlatformFont = NSFont

extension NSColor {
    /// Platform background color for documentation surfaces.
    public static let systemBackground = NSColor.windowBackgroundColor
    /// Platform separator color for documentation surfaces.
    public static let separator = NSColor.separatorColor
}

extension Color {
    /// Creates a SwiftUI color from a platform-native color.
    ///
    /// - Parameter platformColor: Platform-native color.
    public init(platformColor: PlatformColor) {
        self.init(nsColor: platformColor)
    }
}

extension ToolbarPlacement {
    /// Cross-platform navigation toolbar placement used by DocCKit renderers.
    @MainActor public static let navigationBar = ToolbarPlacement.windowToolbar
}

#elseif canImport(UIKit)
public typealias PlatformColor = UIColor
public typealias PlatformFont = UIFont

extension Color {
    /// Creates a SwiftUI color from a platform-native color.
    ///
    /// - Parameter platformColor: Platform-native color.
    public init(platformColor: PlatformColor) {
        self.init(uiColor: platformColor)
    }
}
#endif

extension PlatformColor {
    /// Default accent color used by attributed inline links.
    public static var accent: PlatformColor {
        #if canImport(AppKit)
        PlatformColor.controlAccentColor
        #else
        PlatformColor.systemBlue
        #endif
    }
}

extension Color {
    /// Default DocCKit color for homepage surfaces.
    public static let homepageBackground = Color.secondary.opacity(0.08)
    /// Default DocCKit color for article surfaces.
    public static let article = Color.secondary.opacity(0.18)
    /// Default DocCKit color for collection references.
    public static let collection = Color.blue.opacity(0.18)
    /// Default DocCKit color for collection groups.
    public static let collectionGroup = Color.pink.opacity(0.18)
    /// Default DocCKit color for sample code references.
    public static let sampleCode = Color.green.opacity(0.18)
    /// DocCKit green adjusted for readable text, links, and tint controls.
    public static let docCReadableGreen = Color(red: 0, green: 0.45, blue: 0.12)
    /// DocCKit orange adjusted for readable text, links, and tint controls.
    public static let docCReadableOrange = Color(red: 0.72, green: 0.32, blue: 0)
    /// DocCKit yellow adjusted for readable text, links, and tint controls.
    public static let docCReadableYellow = Color(red: 0.56, green: 0.42, blue: 0)
}
