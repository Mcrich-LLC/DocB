// Asides as developer.apple.com draws them: swift-docc-render's Aside.vue in Apple's theme,
// which gives each kind its own colors and replaces the renderer's default 6-point leading bar
// with a 1-point border all round, 15-point corners and 16 points of padding. The box is
// written on the aside's text as an attribute and the document paints it behind, as it does
// the hero.

import DocBPage
#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

struct Callout: Hashable {
    let kind: Aside.Kind
    /// Where the box starts, in container coordinates: the indent of what holds the aside.
    let indent: CGFloat

    static let padding: CGFloat = 16
    static let border: CGFloat = 1
    static let radius: CGFloat = 15
    /// Above and below the box. The web's is 0.8em like any block's, but a heading after the
    /// box adds its own 1.6em and a paragraph before it only 0.8em, which reads as none.
    static let gap: CGFloat = 16

    /// The label and border (`figure`) and box (`fill`) colors, light and dark.
    private var colors: (figure: (UInt32, UInt32), fill: (UInt32, UInt32)) {
        switch kind {
        case .note: ((0x696969, 0x9A9A9E), (0xF5F5F7, 0x323232))
        case .tip: ((0x3D777D, 0x7DFFE4), (0xFAFFFF, 0x002D2B))
        case .important: ((0x9E6700, 0xFFB50F), (0xFFFBF2, 0x2B1E00))
        case .warning: ((0xE30000, 0xFF3037), (0xFFF2F4, 0x330000))
        case .experiment: ((0x8C28C2, 0xA95ED2), (0xFCF8FF, 0x190325))
        case .deprecated: ((0xBF4800, 0xF56300), (0xFFF9F4, 0x290D00))
        }
    }

    /// The label's color, following the appearance.
    var labelColor: PlatformColor {
        let (light, dark) = colors.figure
        return .dynamic(light: PlatformColor(hex: light), dark: PlatformColor(hex: dark))
    }

    func draw(in rect: CGRect, context: CGContext, dark: Bool) {
        let (figure, fill) = (dark ? colors.figure.1 : colors.figure.0, dark ? colors.fill.1 : colors.fill.0)
        let path = CGPath(roundedRect: rect.insetBy(dx: Self.border / 2, dy: Self.border / 2), cornerWidth: Self.radius, cornerHeight: Self.radius, transform: nil)
        context.saveGState()
        context.addPath(path)
        context.setFillColor(PlatformColor(hex: fill).cgColor)
        context.fillPath()
        context.addPath(path)
        context.setStrokeColor(PlatformColor(hex: figure).cgColor)
        context.setLineWidth(Self.border)
        context.strokePath()
        context.restoreGState()
    }
}

extension NSAttributedString.Key {
    /// On an aside's text, label and content: the box drawn behind it.
    static let callout = NSAttributedString.Key("docb.callout")
}

extension PlatformColor {
    static func dynamic(light: PlatformColor, dark: PlatformColor) -> PlatformColor {
        #if canImport(AppKit)
        NSColor(name: nil) { $0.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light }
        #else
        UIColor { $0.userInterfaceStyle == .dark ? dark : light }
        #endif
    }
}
