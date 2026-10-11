// The Beta and Deprecated badges as developer.apple.com draws them: swift-docc-render's
// Badge.vue (a small label with 2×4 padding) in the colors and 3-point radius of Apple's
// deployed theme, which overrides the renderer's gray default for Beta with teal. A thing
// that is deprecated shows only Deprecated; Beta shows when it is not.

import DocBPage
#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

public enum Badge: Hashable, Sendable {
    case beta
    case deprecated

    public var title: String {
        switch self {
        case .beta: "Beta"
        case .deprecated: "Deprecated"
        }
    }

    /// The badge for something, by the web renderer's rule: Deprecated wins.
    public init?(isBeta: Bool, isDeprecated: Bool) {
        if isDeprecated { self = .deprecated } else if isBeta { self = .beta } else { return nil }
    }

    /// The fill for the light and dark appearances: Apple's figure-teal and figure-orange.
    var fills: (light: PlatformColor, dark: PlatformColor) {
        switch self {
        case .beta: (PlatformColor(hex: 0x3D777D), PlatformColor(hex: 0x7DFFE4))
        case .deprecated: (PlatformColor(hex: 0xBF4800), PlatformColor(hex: 0xF56300))
        }
    }

    /// The label's color: Apple's near-white on the light fills, near-black on the dark ones.
    static let texts = (light: PlatformColor(hex: 0xF5F5F7), dark: PlatformColor(hex: 0x1D1D1F))

    /// The label's font next to text of a size: the web uses 12 against a 17-point body.
    static func font(beside size: CGFloat) -> PlatformFont {
        .systemFont(ofSize: (size * 12 / 17).rounded(), weight: .medium)
    }

    /// The size of the drawn badge beside text of a size.
    func size(beside size: CGFloat) -> CGSize {
        let text = (title as NSString).size(withAttributes: [.font: Self.font(beside: size)])
        return CGSize(width: ceil(text.width) + 8, height: ceil(text.height) + 4)
    }

    /// Draws the badge in a rect, for the appearance that is current when drawing.
    func draw(in rect: CGRect, beside size: CGFloat, dark: Bool) {
        let fill = dark ? fills.dark : fills.light
        let text = dark ? Self.texts.dark : Self.texts.light
        #if canImport(AppKit)
        fill.setFill()
        NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3).fill()
        #else
        fill.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 3).fill()
        #endif
        let font = Self.font(beside: size)
        let textSize = (title as NSString).size(withAttributes: [.font: font])
        let origin = CGPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2)
        (title as NSString).draw(at: origin, withAttributes: [.font: font, .foregroundColor: text])
    }

    #if canImport(AppKit)
    /// The badge as an image, drawn for whichever appearance is current when it is drawn.
    public func image(beside size: CGFloat) -> NSImage {
        let badgeSize = self.size(beside: size)
        return NSImage(size: badgeSize, flipped: false) { rect in
            let dark = NSAppearance.currentDrawing().bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            self.draw(in: rect, beside: size, dark: dark)
            return true
        }
    }
    #endif
}

extension Page {
    public var badge: Badge? { Badge(isBeta: isBeta, isDeprecated: isDeprecated) }
}


/// A badge in text; the document draws it from a bitmap rendered once per size and appearance.
final class BadgeAttachment: NSTextAttachment {
    let badge: Badge
    let textSize: CGFloat

    init(badge: Badge, textSize: CGFloat) {
        self.badge = badge
        self.textSize = textSize
        super.init(data: nil, ofType: nil)
    }

    required init?(coder: NSCoder) { fatalError() }
}

extension Badge {
    /// The badge as a text attachment beside text in a font, sitting on the text's baseline
    /// area so it reads as part of the line.
    func attachment(beside font: PlatformFont) -> NSTextAttachment {
        let attachment = BadgeAttachment(badge: self, textSize: font.pointSize)
        let size = self.size(beside: font.pointSize)
        #if canImport(AppKit)
        attachment.image = image(beside: font.pointSize)
        #else
        let dark = UITraitCollection.current.userInterfaceStyle == .dark
        attachment.image = UIGraphicsImageRenderer(size: size).image { _ in
            self.draw(in: CGRect(origin: .zero, size: size), beside: font.pointSize, dark: dark)
        }
        #endif
        attachment.bounds = CGRect(x: 0, y: (font.capHeight - size.height) / 2, width: size.width, height: size.height)
        return attachment
    }
}

#if canImport(AppKit)
extension Badge {
    private struct Key: Hashable { var badge: Badge; var size: CGFloat; var dark: Bool }
    @MainActor private static var bitmaps: [Key: NSImage] = [:]

    /// The badge as a bitmap at 2x for one appearance, drawn once and blitted thereafter: a
    /// page of topics draws dozens per viewport, and running the handler for each was the
    /// difference between the scroll cache filling in a millisecond and in a frame.
    @MainActor func bitmap(beside size: CGFloat, dark: Bool) -> NSImage {
        let key = Key(badge: self, size: size, dark: dark)
        if let image = Self.bitmaps[key] { return image }
        let points = self.size(beside: size)
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(points.width * 2), pixelsHigh: Int(points.height * 2), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = points
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        draw(in: CGRect(origin: .zero, size: points), beside: size, dark: dark)
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: points)
        image.addRepresentation(rep)
        Self.bitmaps[key] = image
        return image
    }
}
#endif
