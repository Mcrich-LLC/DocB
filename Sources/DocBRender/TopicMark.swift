// The icon in the gutter before a topic in a list, which says what kind of page the link
// goes to, as the web's topic lists do. It is written on the topic's text as an attribute and
// the document draws it centered on the topic's lines, title and abstract together.

import Foundation
#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

struct TopicMark: Hashable {
    /// The page's role: "article", "sampleCode", "symbol"…
    let role: String
    /// Where the gutter starts, in container coordinates.
    let indent: CGFloat
    /// Where the topic's text starts: two topics alike would otherwise read as one run.
    let start: Int

    /// The gutter's width; the text after it is indented this far.
    static let width: CGFloat = 40

    /// Draws the icon for the size of the text beside it, centered in the box the topic's lines make.
    /// Where the symbol goes, centered in the box: larger than the box, which is the title's
    /// cap height, so this is what to test a dirty rect against.
    @MainActor func rect(centeredIn box: CGRect, textSize: CGFloat) -> CGRect {
        let size = Self.image(for: role, size: textSize).size
        return CGRect(x: box.minX + (Self.width - size.width) / 2, y: box.midY - size.height / 2, width: size.width, height: size.height)
    }

    @MainActor func draw(centeredIn box: CGRect, textSize: CGFloat, context: CGContext) {
        let image = Self.image(for: role, size: textSize)
        let rect = rect(centeredIn: box, textSize: textSize)
        #if canImport(AppKit)
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        #else
        image.draw(in: rect)
        #endif
    }

    private struct Key: Hashable { var role: String; var size: CGFloat }
    @MainActor private static var images: [Key: PlatformImage] = [:]

    /// The role's symbol, a touch larger than the text, in the secondary color of whichever
    /// appearance is current when drawn; made once per role and size.
    @MainActor private static func image(for role: String, size: CGFloat) -> PlatformImage {
        let key = Key(role: role, size: size)
        if let image = images[key] { return image }
        let name = TopicIcon.symbolName(for: role)
        let points = (size * 1.2).rounded()
        #if canImport(AppKit)
        let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(.init(pointSize: points, weight: .medium)) ?? NSImage()
        let image = NSImage(size: symbol.size, flipped: false) { rect in
            symbol.draw(in: rect)
            NSColor.secondaryLabelColor.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        #else
        let image = UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: points, weight: .medium))?.withTintColor(.secondaryLabel, renderingMode: .alwaysOriginal) ?? UIImage()
        #endif
        images[key] = image
        return image
    }
}

extension NSAttributedString.Key {
    /// On a topic's title and abstract: the icon drawn in the gutter before them.
    static let topicMark = NSAttributedString.Key("docb.topicMark")
}
