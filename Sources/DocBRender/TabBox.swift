// The box around a tab group, bar and content: a thin outline in the separator color, which
// the web does not draw but which shows where the tab's content ends, with a line under the
// bar across it. A tab that is one code listing gets the listing's fill under the line.
// Written on the group's text as an attribute and drawn by the document behind it, as the
// callout boxes are.

import Foundation
#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

struct TabBox: Hashable {
    let group: TabGroup

    static let padding: CGFloat = 16
    static let border: CGFloat = 1
    static let radius: CGFloat = 15
    static let gap: CGFloat = 16

    var indent: CGFloat { group.indent }

    static func == (lhs: TabBox, rhs: TabBox) -> Bool { lhs.group === rhs.group }
    func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(group)) }

    /// Draws the box, with the line under the bar at `barBottom`.
    @MainActor func draw(in rect: CGRect, barBottom: CGFloat, context: CGContext, dark: Bool) {
        let path = CGPath(roundedRect: rect.insetBy(dx: Self.border / 2, dy: Self.border / 2), cornerWidth: Self.radius, cornerHeight: Self.radius, transform: nil)
        #if canImport(AppKit)
        let separator = NSColor.separatorColor.cgColor
        #else
        let separator = UIColor.separator.cgColor
        #endif
        context.saveGState()
        if group.showsListingAlone {
            context.saveGState()
            context.addPath(path)
            context.clip()
            context.setFillColor(CodeBox.fill(dark: dark).cgColor)
            context.fill(CGRect(x: rect.minX, y: barBottom, width: rect.width, height: rect.maxY - barBottom))
            context.restoreGState()
        }
        context.setFillColor(separator)
        context.fill(CGRect(x: rect.minX + Self.border, y: barBottom, width: rect.width - 2 * Self.border, height: Self.border))
        context.addPath(path)
        context.setStrokeColor(separator)
        context.setLineWidth(Self.border)
        context.strokePath()
        context.restoreGState()
    }
}

extension NSAttributedString.Key {
    /// On a tab group's bar and content: the box drawn around them.
    static let tabBox = NSAttributedString.Key("docb.tabBox")
    /// On the showing tab's content: the group, for the document to find what to swap.
    static let tabContent = NSAttributedString.Key("docb.tabContent")
}
