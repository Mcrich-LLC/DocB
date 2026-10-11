// One icon per topic kind, following swift-docc-render's TopicTypeIcon mapping and colors:
// symbols get a filled rounded square with a letter, as in Apple's Developer app; pages
// that are not symbols get an SF Symbol. `type` is a navigator node type, a render node
// role, or a symbol kind; the same names are used across all three.

import SwiftUI

public enum TopicIcon: Equatable {
    case letters(String, Color)
    case glyph(String, Color)

    /// The SF Symbol for a type, or a generic page for the lettered kinds.
    public static func symbolName(for type: String) -> String {
        if case .glyph(let name, _) = icon(for: type) { return name }
        return "text.document"
    }

    public static func icon(for type: String) -> TopicIcon {
        switch type {
        case "class": .letters("C", .purple)
        case "struct": .letters("S", .purple)
        case "enum", "case": .letters("E", .orange)
        case "protocol": .letters("Pr", .purple)
        case "method", "init": .letters("M", .blue)
        case "property": .letters("P", .teal)
        case "var": .letters("V", .purple)
        case "typealias": .letters("T", .orange)
        case "extension": .letters("Ex", .orange)
        case "macro": .letters("#", .pink)
        case "union": .letters("U", .purple)
        case "namespace": .letters("N", .secondary)
        case "dictionarySymbol", "dictionary": .letters("O", .purple)
        case "httpRequest", "restRequestSymbol": .letters("E", .green)
        case "propertyListKey", "propertyListKeyReference": .letters("K", .green)
        case "subscript": .letters("[]", .blue)
        case "op": .letters("op", .green)
        case "func": .glyph("f.cursive", .green)
        case "article": .glyph("text.document", .teal)
        case "sampleCode": .glyph("curlybraces", .purple)
        case "module": .glyph("square.stack.3d.up.fill", .cyan)
        case "tutorial", "project": .glyph("graduationcap", .secondary)
        case "overview", "learn", "resources": .glyph("app.connected.to.app.below.fill", .secondary)
        case "home": .glyph("house", .secondary)
        case "collection": .glyph("list.bullet", .pink)
        case "collectionGroup": .glyph("list.bullet", .teal)
        default: .glyph("list.bullet", .secondary)
        }
    }
}

public struct TopicIconView: View {
    let type: String
    var size: CGFloat = 14

    public init(type: String, size: CGFloat = 14) {
        self.type = type
        self.size = size
    }

    public var body: some View {
        switch TopicIcon.icon(for: type) {
        case .letters(let text, let color):
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(color)
                .frame(width: size, height: size)
                .overlay {
                    Text(text)
                        .font(.system(size: text.count > 1 ? size * 0.55 : size * 0.7, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
        case .glyph(let name, let color):
            Image(systemName: name)
                .font(.system(size: size * 0.8, weight: .medium))
                .foregroundStyle(color)
                .frame(width: size, height: size)
        }
    }
}

extension TopicIconView {
    /// The icon as a bitmap, for places that only take an `Image`, such as menu items.
    /// Uncolored glyphs stay symbols so the menu tints them for the current appearance.
    @MainActor public static func image(for type: String) -> Image {
        #if os(macOS)
        Image(nsImage: nsImage(for: type))
        #else
        if case .glyph(let name, .secondary) = TopicIcon.icon(for: type) {
            return Image(systemName: name)
        }
        let renderer = ImageRenderer(content: TopicIconView(type: type, size: 16))
        renderer.scale = 2
        return renderer.uiImage.map { Image(uiImage: $0) } ?? Image(systemName: "list.bullet")
        #endif
    }

    #if os(macOS)
    @MainActor public static func nsImage(for type: String) -> NSImage {
        if let cached = images[type] { return cached }
        let image: NSImage
        if case .glyph(let name, .secondary) = TopicIcon.icon(for: type) {
            image = NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? NSImage()
        } else {
            // System colors differ between light and dark; render both and pick when drawn,
            // which is when the menu's or title bar's appearance is current, so the bitmap
            // matches the sidebar's live view.
            let light = render(type, in: .light), dark = render(type, in: .dark)
            image = NSImage(size: light.size, flipped: false) { rect in
                let isDark = NSAppearance.currentDrawing().bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                (isDark ? dark : light).draw(in: rect)
                return true
            }
        }
        images[type] = image
        return image
    }

    @MainActor private static func render(_ type: String, in scheme: ColorScheme) -> NSImage {
        let renderer = ImageRenderer(content: TopicIconView(type: type, size: 16).environment(\.colorScheme, scheme))
        renderer.scale = 2
        return renderer.nsImage ?? NSImage()
    }

    @MainActor private static var images: [String: NSImage] = [:]
    #endif
}
