// The box behind a code listing as developer.apple.com draws it: swift-docc-render's
// `.code-listing` in the documentation theme, a secondary fill with a 1-point grid-colored
// border. Written on the listing's paragraph as an attribute and drawn by the document behind
// it, as the callout boxes are.

import Foundation
#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

struct CodeBox: Hashable {
    /// Where the box starts, in container coordinates: the indent of what holds the listing.
    let indent: CGFloat
    /// Where the listing starts in the text: two listings in a row are two boxes.
    let start: Int

    /// Above and below the lines. The web's is 8, under a taller line height.
    static let padding: CGFloat = 10
    /// Before and after the lines.
    static let inset: CGFloat = 14
    static let border: CGFloat = 1
    static let radius: CGFloat = 15
    /// Above and below the box: the web's 1em between a listing and its neighbors.
    static let gap: CGFloat = 16

    static func fill(dark: Bool) -> PlatformColor { PlatformColor(hex: dark ? 0x161616 : 0xF7F7F7) }

    func draw(in rect: CGRect, context: CGContext, dark: Bool) {
        let path = CGPath(roundedRect: rect.insetBy(dx: Self.border / 2, dy: Self.border / 2), cornerWidth: Self.radius, cornerHeight: Self.radius, transform: nil)
        context.saveGState()
        context.addPath(path)
        context.setFillColor(Self.fill(dark: dark).cgColor)
        context.fillPath()
        context.addPath(path)
        context.setStrokeColor(PlatformColor(hex: dark ? 0x575757 : 0xCCCCCC).cgColor)
        context.setLineWidth(Self.border)
        context.strokePath()
        context.restoreGState()
    }
}

extension NSAttributedString.Key {
    /// On a code listing: the box drawn behind it.
    static let codeBox = NSAttributedString.Key("docb.codeBox")
}
