// The band behind a page's header, as developer.apple.com draws it (its deployed build of
// swift-docc-render's DocumentationHero): every page but a symbol that is not a module gets
// one. Three layers: a top-to-bottom gradient of the accent color from opaque to 30%, the
// page's type icon at 250 points on the right in the same accent, multiplied into the gradient
// in light mode and screened at 70% in dark, and the page background laid over both at 85% in
// light and 55% in dark. The accent is the page's standard color when it declares one, else
// the type-icon color for its kind. The web's 40 points of padding inside the band and of gap
// below it are 30 here, in step with the smaller body text.

import DocBPage
#if canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

struct Hero: Hashable {
    /// The accent for the light and dark appearances.
    var accent: (light: PlatformColor, dark: PlatformColor)
    /// The SF Symbol drawn large on the right.
    var symbol: String

    static func == (lhs: Hero, rhs: Hero) -> Bool { lhs.symbol == rhs.symbol && lhs.accent.light == rhs.accent.light && lhs.accent.dark == rhs.accent.dark }
    func hash(into hasher: inout Hasher) { hasher.combine(symbol) }

    init?(page: Page) {
        // The web's rule: a symbol page has a hero only when the symbol is a module.
        if let kind = page.symbolKind, kind != "module" { return nil }
        // Roles map to the navigator's type names: a framework is "collection", an API collection "collectionGroup".
        let type: String = switch page.role {
        case "collection": "module"
        case "collectionGroup": "collection"
        default: page.symbolKind ?? page.role ?? "article"
        }
        if let standard = page.standardColor, let colors = Self.standardColors[standard] {
            accent = colors
        } else {
            let single = Self.typeIconColors[Self.heroColor(for: type)] ?? Self.typeIconColors["teal"]!
            accent = (single, single)
        }
        symbol = switch TopicIcon.icon(for: type) {
        case .glyph(let name, _): name
        case .letters: "curlybraces"
        }
    }

    /// swift-docc-render's HeroColorsMap; teal when a type is not in it.
    static func heroColor(for type: String) -> String {
        switch type {
        case "article": "teal"
        case "init", "method", "subscript": "blue"
        case "case", "enum", "extension", "typealias": "orange"
        case "class", "dictionarySymbol", "protocol", "sampleCode", "struct", "union", "var": "purple"
        case "collection", "macro": "pink"
        case "collectionGroup", "property": "teal"
        case "func", "op", "httpRequest", "propertyListKey", "propertyListKeyReference": "green"
        case "module": "sky"
        default: "teal"
        }
    }

    /// Apple's `--color-type-icon-*`, the same in both appearances.
    static let typeIconColors: [String: PlatformColor] = [
        "blue": PlatformColor(hex: 0x272AD8), "green": PlatformColor(hex: 0x009900), "orange": PlatformColor(hex: 0x947100),
        "pink": PlatformColor(hex: 0xD82797), "purple": PlatformColor(hex: 0xBF6AF7), "sky": PlatformColor(hex: 0x0066CC), "teal": PlatformColor(hex: 0x509CA3),
    ]

    /// swift-docc-render's `--color-standard-*` for a page that declares a color.
    static let standardColors: [String: (light: PlatformColor, dark: PlatformColor)] = [
        "red": (PlatformColor(hex: 0xFFC2C2), PlatformColor(hex: 0x8B0000)),
        "orange": (PlatformColor(hex: 0xFFCC99), PlatformColor(hex: 0x8B4000)),
        "yellow": (PlatformColor(hex: 0xFFE0A3), PlatformColor(hex: 0x8F7200)),
        "blue": (PlatformColor(hex: 0x99CCFF), PlatformColor(hex: 0x002D75)),
        "green": (PlatformColor(hex: 0x99CCCC), PlatformColor(hex: 0x023B2D)),
        "purple": (PlatformColor(hex: 0xCCCCFF), PlatformColor(hex: 0x512B55)),
        "gray": (PlatformColor(hex: 0xF5F5F7), PlatformColor(hex: 0x1D1D1F)),
    ]

    /// The web's icon box: 250 wide, 10 above and below, hidden on narrow layouts. The web
    /// keeps it 25 from the band's edge; here it ends where the text column ends, so it stays
    /// with the article on a wide window instead of drifting off to the side.
    static let iconWidth: CGFloat = 250
    static let minimumWidthForIcon: CGFloat = 600
    /// Inside the band above and below the header.
    static let padding: CGFloat = 30
    /// Between the band and the content.
    static let gap: CGFloat = 24

    private struct StripKey: Hashable { var accent: PlatformColor; var height: CGFloat; var alpha: CGFloat }
    @MainActor private static var strips: [StripKey: CGImage] = [:]

    /// The gradient as a strip one point wide, rendered once per height and stretched across:
    /// shading a whole band is milliseconds, and a live resize asks for it at every width.
    @MainActor private static func strip(accent: PlatformColor, height: CGFloat, alpha: CGFloat) -> CGImage? {
        let key = StripKey(accent: accent, height: height, alpha: alpha)
        if let strip = strips[key] { return strip }
        guard height > 0, let context = CGContext(data: nil, width: 1, height: Int(height * 2), bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { return nil }
        // Opaque at the top to 30% at the bottom; the top is the end of the image, which is drawn flipped.
        let colors = [accent.withAlphaComponent(alpha).cgColor, accent.withAlphaComponent(0.3 * alpha).cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
            context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: height * 2), end: .zero, options: [])
        }
        guard let strip = context.makeImage() else { return nil }
        if strips.count > 16 { strips.removeAll() }
        strips[key] = strip
        return strip
    }

    /// Paints the band under `dirty`: the gradient, the icon blended in, and the page background
    /// over both at 85% (55% dark). `trailing` is where the text column ends, in `rect`'s
    /// coordinates; the icon ends there too. A clear `fill` means the page has no background
    /// of its own (visionOS, where the text sits on the window's glass): the gradient and icon
    /// are then painted at the strength that overlay would leave them, over nothing.
    @MainActor func draw(in rect: CGRect, dirty: CGRect, trailing: CGFloat, context: CGContext, dark: Bool, fill: PlatformColor) {
        let translucent = fill.cgColor.alpha == 0
        let accent = dark ? accent.dark : accent.light
        let showing: CGFloat = translucent ? (dark ? 0.45 : 0.15) : 1
        context.saveGState()
        context.clip(to: rect.intersection(dirty))
        if !translucent {
            context.setFillColor(fill.cgColor)
            context.fill(rect)
        }
        if let strip = Self.strip(accent: accent, height: rect.height, alpha: showing) {
            // The page is drawn flipped; an image is not.
            context.saveGState()
            context.translateBy(x: rect.minX, y: rect.maxY)
            context.scaleBy(x: 1, y: -1)
            context.draw(strip, in: CGRect(origin: .zero, size: rect.size))
            context.restoreGState()
        }
        if rect.width >= Self.minimumWidthForIcon {
            let box = CGRect(x: trailing - Self.iconWidth, y: rect.minY + 10, width: Self.iconWidth, height: rect.height - 20)
            let image = Self.icon(symbol, color: accent, fitting: box.size)
            let origin = CGPoint(x: box.maxX - image.size.width, y: box.midY - image.size.height / 2)
            Self.draw(image, in: CGRect(origin: origin, size: image.size), dark: dark, blended: !translucent)
        }
        if !translucent {
            context.setFillColor(fill.withAlphaComponent(dark ? 0.55 : 0.85).cgColor)
            context.fill(rect)
        }
        context.restoreGState()
    }

    private struct IconKey: Hashable { var symbol: String; var color: PlatformColor; var box: CGSize }
    @MainActor private static var icons: [IconKey: PlatformImage] = [:]

    /// The symbol as a bitmap that fits the box, rendered once: rasterizing a 250-point symbol
    /// costs milliseconds, and the band is drawn tile by tile into the scroll cache.
    @MainActor private static func icon(_ symbol: String, color: PlatformColor, fitting box: CGSize) -> PlatformImage {
        let key = IconKey(symbol: symbol, color: color, box: box)
        if let image = icons[key] { return image }
        let image = rasterize(symbol, color: color, fitting: box)
        icons[key] = image
        return image
    }

    #if canImport(AppKit)
    private static func rasterize(_ symbol: String, color: NSColor, fitting box: CGSize) -> NSImage {
        guard let glyph = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 250, weight: .regular).applying(.init(paletteColors: [color]))) else { return NSImage() }
        let scale = min(iconWidth / glyph.size.width, box.height / glyph.size.height)
        let size = CGSize(width: floor(glyph.size.width * scale), height: floor(glyph.size.height * scale))
        guard size.width > 0, size.height > 0 else { return NSImage() }
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        glyph.draw(in: CGRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: size)
        image.addRepresentation(rep)
        return image
    }

    /// Multiplied into the gradient in light mode, screened at 70% in dark; the image's own
    /// draw sets the operation, so it is passed here rather than on the context. Unblended
    /// (no page background to wash it out afterwards) it is drawn at the strength that wash
    /// would leave.
    private static func draw(_ image: NSImage, in rect: CGRect, dark: Bool, blended: Bool) {
        // The view is flipped; only this form of draw honors that.
        image.draw(in: rect, from: .zero, operation: dark ? .screen : .multiply, fraction: blended ? (dark ? 0.7 : 1) : (dark ? 0.3 : 0.15), respectFlipped: true, hints: nil)
    }
    #else
    private static func rasterize(_ symbol: String, color: UIColor, fitting box: CGSize) -> UIImage {
        guard let glyph = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 250, weight: .regular))?.withTintColor(color, renderingMode: .alwaysOriginal) else { return UIImage() }
        let scale = min(iconWidth / glyph.size.width, box.height / glyph.size.height)
        let size = CGSize(width: floor(glyph.size.width * scale), height: floor(glyph.size.height * scale))
        guard size.width > 0, size.height > 0 else { return UIImage() }
        return UIGraphicsImageRenderer(size: size).image { _ in glyph.draw(in: CGRect(origin: .zero, size: size)) }
    }

    private static func draw(_ image: UIImage, in rect: CGRect, dark: Bool, blended: Bool) {
        image.draw(in: rect, blendMode: dark ? .screen : .multiply, alpha: blended ? (dark ? 0.7 : 1) : (dark ? 0.3 : 0.15))
    }
    #endif
}

extension NSAttributedString.Key {
    /// On the header's text: the hero drawn behind it, and how far down it reaches.
    static let hero = NSAttributedString.Key("docb.hero")
}

extension PlatformColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
