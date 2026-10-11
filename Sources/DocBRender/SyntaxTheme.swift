// The web renderer's syntax colors (swift-docc-render, src/styles/core/_syntax.scss and the
// light and dark color schemes) for the highlighter's scopes. As in its stylesheet, the
// innermost scope with a color decides; scopes without one are transparent.

import DocBHighlight
import SwiftUI

enum SyntaxTheme {
    /// The color for a token, or nil for the text's own.
    static func color(for scopes: [String]) -> PlatformColor? {
        for scope in scopes.reversed() {
            if let group = groups[scope] { return group == .plain ? nil : colors[group] }
        }
        return nil
    }

    static func isBold(_ scopes: [String]) -> Bool { scopes.contains { $0 == "doctag" || $0 == "strong" } }
    static func isItalic(_ scopes: [String]) -> Bool { scopes.contains { $0 == "emphasis" || $0 == "link" } }

    private enum Group { case addition, comments, deletion, keywords, strings, characters, otherTypeNames, plain }

    private static let groups: [String: Group] = [
        "addition": .addition,
        "comment": .comments, "quote": .comments,
        "deletion": .deletion,
        "keyword": .keywords, "literal": .keywords, "selector-tag": .keywords,
        "string": .strings,
        "bullet": .characters, "meta": .characters, "number": .characters, "symbol": .characters, "tag": .characters,
        "attr": .otherTypeNames, "built_in": .otherTypeNames, "builtin-name": .otherTypeNames, "class": .otherTypeNames,
        "params": .otherTypeNames, "section": .otherTypeNames, "title": .otherTypeNames, "type": .otherTypeNames,
        "attribute": .plain, "identifier": .plain, "subst": .plain,
    ]

    private static let colors: [Group: PlatformColor] = [
        .addition: dynamic(light: (0, 128, 0), dark: (0, 153, 0)),
        .comments: dynamic(light: (112, 127, 140), dark: (127, 140, 152)),
        .deletion: dynamic(light: (255, 0, 0), dark: (255, 51, 51)),
        .keywords: dynamic(light: (173, 61, 164), dark: (255, 122, 178)),
        .strings: dynamic(light: (209, 47, 27), dark: (255, 129, 112)),
        .characters: dynamic(light: (39, 42, 216), dark: (217, 201, 124)),
        .otherTypeNames: dynamic(light: (112, 61, 170), dark: (218, 186, 255)),
    ]

    private static func dynamic(light: (Int, Int, Int), dark: (Int, Int, Int)) -> PlatformColor {
        func color(_ rgb: (Int, Int, Int)) -> PlatformColor {
            PlatformColor(red: CGFloat(rgb.0) / 255, green: CGFloat(rgb.1) / 255, blue: CGFloat(rgb.2) / 255, alpha: 1)
        }
        #if canImport(AppKit)
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? color(dark) : color(light)
        }
        #else
        return UIColor { traits in traits.userInterfaceStyle == .dark ? color(dark) : color(light) }
        #endif
    }
}
