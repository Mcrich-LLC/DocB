// A horizontal rule as developer.apple.com draws it: a 1-point line in the grid color across
// the whole column. It is written on an empty paragraph as an attribute, and the document
// draws it through the paragraph's middle, as it draws the callout boxes.

import Foundation
#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

struct Rule: Hashable {
    /// Where the line starts, in container coordinates: the indent of what holds the rule.
    let indent: CGFloat

    static let thickness: CGFloat = 1

    func draw(in rect: CGRect, context: CGContext) {
        #if canImport(AppKit)
        context.setFillColor(NSColor.separatorColor.cgColor)
        #else
        context.setFillColor(UIColor.separator.cgColor)
        #endif
        context.fill(rect)
    }
}

extension NSAttributedString.Key {
    /// On the empty paragraph that stands for a rule: the line drawn through it.
    static let rule = NSAttributedString.Key("docb.rule")
}
