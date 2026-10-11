// The page text: how blocks map to paragraphs, and what the text view draws and hosts.

import AppKit
import SwiftUI
import DocBPage
import Foundation
import Testing
@testable import DocBRender

/// A page in a text view of a size, laid out. Attachment views are the text view's to place,
/// through display cycles `swift test` does not run; what the page sizes them to is asserted.
@MainActor func shown(_ page: Page, width: CGFloat = 600, height: CGFloat = 400) throws -> (NSScrollView, TextDocumentView) {
    let scrollView = TextDocumentView.scrollable()
    scrollView.frame = NSRect(x: 0, y: 0, width: width, height: height)
    let view = try #require(scrollView.documentView as? TextDocumentView)
    view.show(page)
    view.laidOut()
    return (scrollView, view)
}

extension TextDocumentView {
    func laidOut() {
        layoutSubtreeIfNeeded()
    }

    var layoutManager: NSLayoutManager? { textView.layoutManager }
    var textContainer: NSTextContainer? { textView.textContainer }
    var string: String { textView.string }
    var textContainerOrigin: NSPoint { textView.textContainerOrigin }
}

/// A line's used rect in the view, for the first occurrence of a string.
@MainActor func lineFrame(of needle: String, in view: TextDocumentView) throws -> CGRect {
    let layout = try #require(view.layoutManager)
    let glyph = layout.glyphIndexForCharacter(at: (view.string as NSString).range(of: needle).location)
    return layout.lineFragmentUsedRect(forGlyphAt: glyph, effectiveRange: nil).offsetBy(dx: view.textContainerOrigin.x, dy: view.textContainerOrigin.y)
}

extension NSView {
    /// Every view below this one, depth first.
    var descendants: [NSView] { subviews.flatMap { [$0] + $0.descendants } }
}

#if canImport(AppKit)
@Suite @MainActor struct PageTextMappingTests {
    @Test func blocksBecomeStyledParagraphs() throws {
        let page = Page(title: "T", roleHeading: "Article", body: [
            .heading(level: 2, text: "Overview"),
            .list(List(isOrdered: true, start: 4, items: [[.paragraph([Run("four", .strong)])]])),
            .code(Code(lines: ["a", "b"])),
            .links(Links(items: [Links.Item(title: "Other", link: "/other", abstract: [Run("About.")], isBeta: true)])),
        ])
        let text = NSAttributedString(page: page)
        let string = text.string
        // A topic is the title with its badge and the abstract on a line of its own, both indented past the drawn icon.
        #expect(string == "Article\nT\nOverview\n4.\tfour\na\u{2028}b\nOther \u{FFFC}\nAbout.")
        func attributes(at needle: String) -> [NSAttributedString.Key: Any] {
            text.attributes(at: (string as NSString).range(of: needle).location, effectiveRange: nil)
        }
        #expect((attributes(at: "Overview")[.font] as? NSFont)?.fontDescriptor.symbolicTraits.contains(.bold) == true)
        #expect((attributes(at: "four")[.font] as? NSFont)?.fontDescriptor.symbolicTraits.contains(.bold) == true)
        #expect((attributes(at: "a\u{2028}")[.font] as? NSFont)?.fontDescriptor.symbolicTraits.contains(.monoSpace) == true)
        #expect((attributes(at: "4.")[.paragraphStyle] as? NSParagraphStyle)?.headIndent == 20)
        #expect((attributes(at: "Other")[.link] as? URL).flatMap(PageLink.reference(from:)) == "/other")
        #expect((attributes(at: "About.")[.paragraphStyle] as? NSParagraphStyle)?.headIndent == 40)
        #expect((attributes(at: "Other")[.paragraphStyle] as? NSParagraphStyle)?.firstLineHeadIndent == 40)
        let start = (string as NSString).range(of: "Other").location
        #expect((attributes(at: "Other")[.topicMark] as? TopicMark) == TopicMark(role: "article", indent: 0, start: start))
        #expect((attributes(at: "About.")[.topicMark] as? TopicMark) == TopicMark(role: "article", indent: 0, start: start))
    }
}
#endif

#if canImport(AppKit)
@Suite @MainActor struct PageTextMarkerTests {
    @Test func aListStartingWithAListKeepsItsMarker() {
        let page = Page(title: "T", body: [.list(List(isOrdered: false, items: [[.list(List(isOrdered: true, items: [[.paragraph([Run("inner")])]]))]]))])
        #expect(NSAttributedString(page: page).string == "T\n•\t\n1.\tinner")
    }
}
#endif

#if canImport(AppKit)
@Suite @MainActor struct BadgeTests {
    @Test func aDeprecatedPageWearsAnOrangeBadgeThatGetsDrawn() throws {
        let page = Page(title: "Old", roleHeading: "Structure", isDeprecated: true, body: [
            .links(Links(items: [Links.Item(title: "Newer", link: "/n", isBeta: true), Links.Item(title: "Gone", link: "/g", isDeprecated: true)])),
        ])
        let text = NSAttributedString(page: page)
        // The page badge on the eyebrow line, Beta on the beta topic, none on the deprecated one: the page has that badge.
        var attachments = 0
        text.enumerateAttribute(.attachment, in: NSRange(location: 0, length: text.length)) { value, _, _ in if value is BadgeAttachment { attachments += 1 } }
        #expect(attachments == 2)
        #expect(text.string.hasPrefix("Structure \u{FFFC}\nOld\n"))

        let (_, view) = try shown(page)
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: NSRect(x: 0, y: 0, width: 600, height: 100)))
        view.cacheDisplay(in: NSRect(x: 0, y: 0, width: 600, height: 100), to: bitmap)
        // Somewhere on the eyebrow line there is Apple's deprecated orange, #bf4800 or #f56300 in dark.
        var found = false
        var inked = 0
        for x in stride(from: 0, to: bitmap.pixelsWide, by: 2) {
            for y in stride(from: 0, to: bitmap.pixelsHigh, by: 2) {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                if color.brightnessComponent < 0.9 { inked += 1 }
                let light = abs(color.redComponent - 0xBF / 255) < 0.05 && abs(color.greenComponent - 0x48 / 255) < 0.05
                let dark = abs(color.redComponent - 0xF5 / 255) < 0.05 && abs(color.greenComponent - 0x63 / 255) < 0.05
                if (light || dark), color.blueComponent < 0.05 { found = true }
            }
        }
        #expect(found, "no badge pixels were drawn among \(inked) inked pixels in \(bitmap.pixelsWide)x\(bitmap.pixelsHigh)")
    }
}
#endif

#if canImport(AppKit)
@Suite @MainActor struct HeroTests {
    @Test func whichPagesGetAHero() {
        #expect(Hero(page: Page(title: "SwiftUI", role: "collection", symbolKind: "module"))?.symbol == "square.stack.3d.up.fill")
        #expect(Hero(page: Page(title: "Views", role: "collectionGroup"))?.symbol == "list.bullet")
        #expect(Hero(page: Page(title: "Guide", role: "article"))?.symbol == "text.document")
        #expect(Hero(page: Page(title: "Sample", role: "sampleCode"))?.symbol == "curlybraces")
        #expect(Hero(page: Page(title: "View", role: "symbol", symbolKind: "protocol")) == nil)
        #expect(Hero(page: Page(title: "SwiftUI", role: "collection", symbolKind: "module"))?.accent.light == PlatformColor(hex: 0x0066CC))
        #expect(Hero(page: Page(title: "Views", role: "collectionGroup"))?.accent.light == PlatformColor(hex: 0xD82797))
        #expect(Hero(page: Page(title: "Red", role: "article", standardColor: "red"))?.accent.light == PlatformColor(hex: 0xFFC2C2))
    }

    @Test func theBandCoversTheHeaderAndNothingBelow() throws {
        let page = Page(title: "SwiftUI", roleHeading: "Framework", role: "collection", symbolKind: "module", abstract: [Run("Declare the user interface.")], body: [
            .heading(level: 2, text: "Overview"), .paragraph([Run("Body text.")]),
        ])
        let (_, view) = try shown(page, width: 900, height: 600)
        let bottom = try #require(view.content?.heroBottom(in: view.layoutManager!))
        // Below the header: title, eyebrow, abstract and the web's 40 points of spacing, but above the body.
        #expect(bottom > 100 && bottom < 250, "hero bottom \(bottom), text \(view.string.prefix(60))")
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: NSRect(x: 0, y: 0, width: 900, height: 400)))
        view.cacheDisplay(in: NSRect(x: 0, y: 0, width: 900, height: 400), to: bitmap)
        let scale = CGFloat(bitmap.pixelsWide) / 900
        let background = try #require(bitmap.colorAt(x: 4, y: Int((bottom + 24 + 60) * scale))?.usingColorSpace(.deviceRGB))
        let inBand = try #require(bitmap.colorAt(x: 4, y: 4)?.usingColorSpace(.deviceRGB))
        #expect(abs(inBand.redComponent - background.redComponent) + abs(inBand.blueComponent - background.blueComponent) > 0.02, "the band is tinted")
        // The icon sits at the right; the band is still tinted there but the icon is darker or lighter than the plain band.
        let inIcon = try #require(bitmap.colorAt(x: Int((900 - 25 - 125) * scale), y: Int((bottom + 24) / 2 * scale))?.usingColorSpace(.deviceRGB))
        #expect(inIcon != inBand, "the icon shows")
    }
}
#endif

#if canImport(AppKit)
@Suite @MainActor struct CalloutTests {
    @Test func theBoxWrapsTheAsideWithItsPaddingAndWearsItsColor() throws {
        let page = Page(title: "T", body: [
            .paragraph([Run("Before.")]),
            .aside(Aside(kind: .warning, blocks: [.paragraph([Run("Careful.")]), .paragraph([Run("Very.")])])),
            .paragraph([Run("After.")]),
        ])
        let (_, view) = try shown(page)
        let layout = try #require(view.layoutManager)
        let boxes = try #require(view.content?.calloutBoxes(in: layout, width: view.textContainer!.size.width))
        let box = try #require(boxes.first?.box).offsetBy(dx: view.textContainerOrigin.x, dy: view.textContainerOrigin.y)
        let label = try lineFrame(of: "Warning", in: view)
        let last = try lineFrame(of: "Very.", in: view)
        let after = try lineFrame(of: "After.", in: view)
        #expect(abs(label.minY - box.minY - Callout.padding) < 0.5, "label \(label) box \(box)")
        #expect(abs(box.maxY - last.maxY - Callout.padding) < 0.5, "last \(last) box \(box)")
        #expect(abs(label.minX - box.minX - Callout.border - Callout.padding) < 0.5)
        #expect(after.minY > box.maxY + Callout.gap - 0.5, "the next paragraph clears the box")
        #expect(box.minX == 24 && box.maxX == view.frame.width - 24)

        // The border's pixels are the warning red, #e30000 or #ff3037 in dark; inside is tinted.
        let rect = NSRect(x: 0, y: 0, width: 600, height: 400)
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: rect))
        view.cacheDisplay(in: rect, to: bitmap)
        let scale = Int(CGFloat(bitmap.pixelsWide) / 600)
        let y = Int(box.midY) * scale
        let border = try #require(bitmap.colorAt(x: 24 * scale, y: y)?.usingColorSpace(.deviceRGB))
        #expect(border.redComponent > 0.85 && border.greenComponent < 0.25, "border is \(border)")
        let inside = try #require(bitmap.colorAt(x: (24 + 8) * scale, y: y)?.usingColorSpace(.deviceRGB))
        #expect(inside != border && abs(inside.redComponent - inside.blueComponent) > 0.005, "box is tinted, got \(inside)")
    }

    @Test func onlyTheLastParagraphInABoxCarriesTheBottomPadding() throws {
        let page = Page(title: "T", body: [.aside(Aside(kind: .note, blocks: [.paragraph([Run("One.")]), .paragraph([Run("Two.")]), .paragraph([Run("Three.")])]))])
        let text = NSAttributedString(page: page)
        func spacing(after needle: String) -> CGFloat? {
            (text.attribute(.paragraphStyle, at: (text.string as NSString).range(of: needle).location, effectiveRange: nil) as? NSParagraphStyle)?.paragraphSpacing
        }
        #expect(spacing(after: "One.") == 8 && spacing(after: "Two.") == 8)
        #expect(spacing(after: "Three.") == Callout.padding + Callout.gap)
    }

    @Test func aCalloutFirstInTheBodyClearsTheHeader() throws {
        // A symbol page has no hero band, and its first block would be flattened against the header.
        let page = Page(title: "Old", roleHeading: "Structure", role: "symbol", symbolKind: "struct", platforms: [Platform(name: "watchOS", introduced: "7.0", deprecated: "9.2")], body: [
            .aside(Aside(kind: .deprecated, blocks: [.paragraph([Run("Use the other one.")])])),
        ])
        let (_, view) = try shown(page)
        let layout = try #require(view.layoutManager)
        let box = try #require(view.content?.calloutBoxes(in: layout, width: view.textContainer!.size.width).first?.box).offsetBy(dx: view.textContainerOrigin.x, dy: view.textContainerOrigin.y)
        let platforms = try lineFrame(of: "watchOS", in: view)
        let label = try lineFrame(of: "Deprecated", in: view)
        #expect(box.minY >= platforms.maxY, "box \(box) platforms \(platforms)")
        #expect(abs(label.minY - box.minY - Callout.padding) < 0.5, "label \(label) box \(box)")
    }
}
#endif

#if canImport(AppKit)
@Suite @MainActor struct ImageTests {
    private func png(width: Int, height: Int, color: NSColor) -> Data {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        color.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])!
    }

    @Test func anImageArrivesAndGrowsItsBlockToItsSize() async throws {
        // A 2x variant: 400x200 pixels is 200x100 points, narrower than the column.
        let media = Media(variants: [Media.Variant(url: "images/red.png", scale: 2)], alt: "red")
        let page = Page(title: "T", body: [.paragraph([Run("Before.")]), .image(media), .paragraph([Run("After.")])])
        let data = png(width: 400, height: 200, color: .red)
        let scrollView = TextDocumentView.scrollable()
        scrollView.frame = NSRect(x: 0, y: 0, width: 600, height: 400)
        let view = try #require(scrollView.documentView as? TextDocumentView)
        view.assets.loadImage = { reference in reference == "images/red.png" ? data : nil }
        view.show(page)
        view.laidOut()
        let block = try #require(view.content?.blocks.first?.block)
        #expect(block.bounds.height == 0, "nothing until the picture arrives")
        for _ in 0..<200 where block.bounds.height == 0 { try await Task.sleep(for: .milliseconds(10)) }
        #expect(block.bounds.height == 100, "the block is the image's height: \(block.bounds)")
        view.laidOut()
        let before = try lineFrame(of: "Before.", in: view)
        let after = try lineFrame(of: "After.", in: view)
        #expect(after.minY - before.maxY > 100, "the next paragraph is below the image: \(after.minY - before.maxY)")
    }
}
#endif

#if canImport(AppKit)
@Suite @MainActor struct TopicMarkTests {
    @Test func theSymbolReachesBeyondTheTitlesCapHeight() {
        let box = CGRect(x: 0, y: 100, width: TopicMark.width, height: 12)
        let rect = TopicMark(role: "article", indent: 0, start: 0).rect(centeredIn: box, textSize: 17)
        #expect(rect.minY < box.minY && rect.maxY > box.maxY, "what a dirty rect must be tested against: \(rect)")
        #expect(abs(rect.midY - box.midY) < 0.5 && abs(rect.midX - box.midX) < 0.5)
    }

    @Test func twoTopicsAlikeKeepTheirOwnIcons() {
        let items = (1...2).map { Links.Item(title: "Article \($0)", link: "/a\($0)", abstract: [Run("Words.")], role: "article") }
        let content = PageContent(text: NSAttributedString(page: Page(title: "T", body: [.links(Links(items: items))])))
        #expect(content.topicMarks.count == 2)
    }
}
#endif

#if canImport(AppKit)
@Suite @MainActor struct RowTests {
    @Test func aRowOfPicturesIsOneBlockAndARowOfTextReadsInOrder() throws {
        let picture = Media(variants: [Media.Variant(url: "https://example.com/a.png")], alt: "A", caption: [Run("Caption.")])
        let pictures = Row(columns: [Row.Column(blocks: [.image(picture)]), Row.Column(blocks: [.video(picture, poster: nil)]), Row.Column(blocks: [.image(picture)])])
        let text = Row(columns: [Row.Column(blocks: [.paragraph([Run("Left.")])]), Row.Column(blocks: [.paragraph([Run("Right.")])])])
        let mixed = Row(columns: [Row.Column(blocks: [.paragraph([Run("Words.")])]), Row.Column(blocks: [.image(picture)])])
        let page = Page(title: "T", body: [.row(pictures), .row(text), .row(mixed), .image(picture)])
        let string = NSAttributedString(page: page)
        // The pictures and video as one block, the text columns as one block, a mixed row read in
        // order, then a figure with its caption centered.
        #expect(string.string == "T\n\u{FFFC}\n\u{FFFC}\nWords.\n\u{FFFC}\nCaption.\n\u{FFFC}\nCaption.")
        #expect(PageContent(text: string).blocks.count == 4)
        let caption = string.attribute(.paragraphStyle, at: (string.string as NSString).range(of: "Caption.").location, effectiveRange: nil) as? NSParagraphStyle
        #expect(caption?.alignment == .center)
    }
}
#endif

#if canImport(AppKit)
@Suite @MainActor struct TabTests {
    @Test func aTabGroupShowsOneTabAndSwapsItInPlace() throws {
        let tabs = [
            Tab(title: "SwiftUI", blocks: [.paragraph([Run("Use a modifier.")]), .code(Code(lines: ["view.glassEffect()"]))]),
            Tab(title: "UIKit", blocks: [.paragraph([Run("Use an effect view.")])]),
            Tab(title: "Empty", blocks: []),
        ]
        let page = Page(title: "T", body: [.paragraph([Run("Before.")]), .tabs(tabs), .paragraph([Run("After.")])])
        let (_, view) = try shown(page, width: 800, height: 600)
        let layout = try #require(view.layoutManager)
        #expect(view.string == "T\nBefore.\n\u{FFFC}\nUse a modifier.\nview.glassEffect()\nAfter.")
        let group = try #require(view.content?.tabBoxes.first?.box.group)
        #expect(group.tabs.map(\.title) == ["SwiftUI", "UIKit", "Empty"] && group.selected == 0)
        // The box wraps the bar and the content, between the paragraphs around them.
        func box() throws -> CGRect {
            try #require(view.content?.tabBoxes(in: layout, width: view.textContainer!.size.width).first?.rect).offsetBy(dx: view.textContainerOrigin.x, dy: view.textContainerOrigin.y)
        }
        let before = try lineFrame(of: "Before.", in: view)
        var bar = try #require(view.host.placements.items.first).frame
        var rect = try box()
        #expect(rect.minY > before.maxY && rect.minY < bar.minY, "box \(rect) bar \(bar)")
        #expect(try rect.maxY > lineFrame(of: "glassEffect", in: view).maxY && rect.maxY < lineFrame(of: "After.", in: view).minY)
        // Content is inset from the box on both sides.
        #expect(try lineFrame(of: "Use a", in: view).minX - rect.minX == TabBox.border + TabBox.padding)
        #expect((view.textView.textStorage!.attribute(.paragraphStyle, at: (view.string as NSString).range(of: "Use a").location, effectiveRange: nil) as? NSParagraphStyle)?.tailIndent == -TabBox.padding)

        // Switching swaps the content and nothing else; the bar stays where it was.
        view.select(tab: 1, in: group)
        #expect(view.string == "T\nBefore.\n\u{FFFC}\nUse an effect view.\nAfter.")
        #expect(group.selected == 1)
        #expect(try #require(view.host.placements.items.first).frame == bar)
        rect = try box()
        #expect(try rect.maxY > lineFrame(of: "effect view", in: view).maxY && rect.maxY < lineFrame(of: "After.", in: view).minY)
        // An empty tab is still a stretch of text, so it can be swapped again.
        view.select(tab: 2, in: group)
        #expect(view.string == "T\nBefore.\n\u{FFFC}\n\nAfter.")
        view.select(tab: 0, in: group)
        #expect(view.string == "T\nBefore.\n\u{FFFC}\nUse a modifier.\nview.glassEffect()\nAfter.")
        bar = try #require(view.host.placements.items.first).frame
        #expect(bar.width > 0)
    }

    @Test func aBlockInASwappedTabSitsBelowTheBar() throws {
        let row = Row(columns: [Row.Column(blocks: [.paragraph([Run("UINavigationBar", .code, link: "/a")])]), Row.Column(blocks: [.paragraph([Run("UIToolbar", .code, link: "/b")])])])
        let tabs = [Tab(title: "SwiftUI", blocks: [.paragraph([Run("Words.")])]), Tab(title: "UIKit", blocks: [.row(row)])]
        let page = Page(title: "T", body: [.paragraph([Run("Before.")]), .tabs(tabs), .paragraph([Run("After.")])])
        let (scrollView, view) = try shown(page, width: 800, height: 600)
        // In a window, as in the app: AppKit lays an edited range out at once there.
        let window = NSWindow(contentRect: scrollView.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = scrollView
        view.laidOut()
        let group = try #require(view.content?.tabBoxes.first?.box.group)
        let bar = try #require(view.host.placements.items.first).frame
        view.select(tab: 1, in: group)
        view.laidOut()
        let hosted = view.host.placements.items.map(\.frame).sorted { $0.minY < $1.minY }
        #expect(hosted.count == 2, "bar and row: \(hosted)")
        #expect(hosted.first == bar)
        #expect(try #require(hosted.last).minY >= bar.maxY, "row \(String(describing: hosted.last)) under bar \(bar)")
        #expect(try #require(hosted.last).height > 10)
    }

    @Test func theLineUnderTheBarIsAtTheBarsBottom() throws {
        let tabs = [Tab(title: "A", blocks: [.paragraph([Run("One.")])]), Tab(title: "B", blocks: [.paragraph([Run("Two.")])])]
        let (_, view) = try shown(Page(title: "T", body: [.tabs(tabs)]))
        let layout = try #require(view.layoutManager)
        let box = try #require(view.content?.tabBoxes(in: layout, width: view.textContainer!.size.width).first)
        let bar = try #require(view.content?.blockFrames(in: layout, container: view.textContainer!).first?.frame)
        #expect(box.barBottom == bar.maxY)
        #expect(box.rect.minY < bar.minY && box.rect.maxY > bar.maxY)
    }

    @Test func aTabGroupAtTheEndOfThePageKeepsNoTrailingLine() throws {
        let tabs = [Tab(title: "A", blocks: [.paragraph([Run("One.")])]), Tab(title: "B", blocks: [.paragraph([Run("Two.")])])]
        let page = Page(title: "T", body: [.tabs(tabs)])
        let (_, view) = try shown(page)
        let group = try #require(view.content?.tabBoxes.first?.box.group)
        #expect(view.string == "T\n\u{FFFC}\nOne.")
        view.select(tab: 1, in: group)
        #expect(view.string == "T\n\u{FFFC}\nTwo.")
        view.select(tab: 0, in: group)
        #expect(view.string == "T\n\u{FFFC}\nOne.")
    }
}
#endif

#if canImport(AppKit)
@Suite @MainActor struct RuleTests {
    @Test func aDividerAndAGridDrawALineAcrossTheColumn() throws {
        let items = [Links.Item(title: "Sample", link: "/s", abstract: [Run("Words.")], role: "sampleCode")]
        let page = Page(title: "T", body: [.paragraph([Run("Before.")]), .divider, .paragraph([Run("Middle.")]), .links(Links(style: .detailedGrid, items: items)), .paragraph([Run("After.")])])
        let (_, view) = try shown(page, width: 800, height: 600)
        let layout = try #require(view.layoutManager)
        let rules = try #require(view.content).ruleRects(in: layout, width: view.textContainer!.size.width)
        #expect(rules.count == 2)
        let before = try lineFrame(of: "Before.", in: view)
        let middle = try lineFrame(of: "Middle.", in: view)
        let after = try lineFrame(of: "After.", in: view)
        for (_, rect) in rules {
            #expect(rect.minX == 0 && rect.width == view.textContainer!.size.width && rect.height == 1)
        }
        let first = rules[0].rect.offsetBy(dx: view.textContainerOrigin.x, dy: view.textContainerOrigin.y)
        let second = rules[1].rect.offsetBy(dx: view.textContainerOrigin.x, dy: view.textContainerOrigin.y)
        #expect(first.minY > before.maxY && first.maxY < middle.minY, "first \(first) before \(before) middle \(middle)")
        #expect(second.minY > middle.maxY + 300 && second.maxY < after.minY, "second \(second) after \(after)")
        // The empty paragraph that carries the rule is no taller than a few points.
        let line = layout.lineFragmentUsedRect(forGlyphAt: layout.glyphIndexForCharacter(at: (view.string as NSString).range(of: "Before.\n").location + 8), effectiveRange: nil)
        #expect(line.height < 4, "rule line \(line)")
    }
}
#endif

#if canImport(AppKit)
@Suite @MainActor struct HostedBlockTests {
    @Test func aHostedViewSitsOnItsAttachmentAndStaysThroughResizes() throws {
        let items = (1...2).map { Links.Item(title: "Sample \($0)", link: "/s\($0)", abstract: [Run("Words.")], role: "sampleCode") }
        let page = Page(title: "T", body: [.paragraph([Run("Before.")]), .links(Links(style: .detailedGrid, items: items)), .paragraph([Run("After.")])])
        let (scrollView, view) = try shown(page, width: 800, height: 600)
        let block = try #require(view.content?.blocks.first?.block)
        func hosted() throws -> BlockPlacements.Item { try #require(view.host.placements.items.first) }
        func attachmentFrame() throws -> CGRect {
            let layout = try #require(view.layoutManager)
            let glyph = layout.glyphIndexForCharacter(at: (view.string as NSString).range(of: "\u{FFFC}").location)
            let line = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            let baseline = line.minY + layout.location(forGlyphAt: glyph).y
            return CGRect(x: line.minX + view.textContainerOrigin.x, y: baseline - block.bounds.height + view.textContainerOrigin.y, width: block.bounds.width, height: block.bounds.height)
        }
        var frame = try hosted().frame
        var expected = try attachmentFrame()
        #expect(frame == expected, "hosted \(frame) attachment \(expected)")
        // Between the paragraphs around it.
        let before = try lineFrame(of: "Before.", in: view)
        let after = try lineFrame(of: "After.", in: view)
        #expect(frame.minY > before.maxY && frame.maxY <= after.minY)
        // The text view growing to its content must not drag the hosted view along.
        view.setFrameSize(NSSize(width: view.frame.width, height: view.frame.height + 500))
        #expect(try hosted().frame == frame)
        // Narrower, it follows the attachment to its new place.
        scrollView.frame = NSRect(x: 0, y: 0, width: 500, height: 600)
        view.laidOut()
        frame = try hosted().frame
        expected = try attachmentFrame()
        #expect(frame == expected, "hosted \(frame) attachment \(expected)")
    }

    @Test func aClickInABlockEndsTheTextSelection() throws {
        let items = [Links.Item(title: "Sample", link: "/s", abstract: [Run("Words.")], role: "sampleCode")]
        let page = Page(title: "T", body: [.paragraph([Run("Before.")]), .links(Links(style: .detailedGrid, items: items))])
        let (scrollView, view) = try shown(page, width: 800, height: 600)
        let hosted = try #require(view.host.placements.items.first).frame
        func click(at point: NSPoint, in target: NSView) throws {
            let location = scrollView.convert(point, from: target)
            let event = try #require(NSEvent.mouseEvent(with: .leftMouseDown, location: location, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
            view.clicked(event)
        }
        view.textView.setSelectedRange(NSRange(location: 0, length: 3))
        // A click in the text leaves its selection alone; one in the block ends it.
        try click(at: NSPoint(x: 5, y: 5), in: view.textView)
        #expect(view.textView.selectedRange().length == 3)
        try click(at: NSPoint(x: hosted.minX + 10, y: hosted.minY + 10), in: view)
        #expect(view.textView.selectedRange().length == 0)
    }

    @Test func aDetailedGridIsOneBlockSizedToTheColumn() throws {
        let items = (1...3).map { Links.Item(title: "Sample \($0)", link: "/s\($0)", abstract: [Run(String(repeating: "Words. ", count: $0 * 6))], role: "sampleCode") }
        let page = Page(title: "T", body: [.paragraph([Run("Before.")]), .links(Links(style: .detailedGrid, items: items)), .paragraph([Run("After.")])])
        let (scrollView, view) = try shown(page, width: 800, height: 600)
        let block = try #require(view.content?.blocks.first?.block)
        // As wide as the column, and as tall as two rows of cards need: a 16:9 cover on a
        // (752 - 20) / 2 wide card is 205, so two rows with text come to more than 500.
        #expect(block.bounds.width == view.textContainer!.size.width)
        #expect(block.bounds.height > 500 && block.bounds.height < 900, "block height \(block.bounds.height)")
        // The text after the grid sits below it.
        let before = try lineFrame(of: "Before.", in: view)
        let after = try lineFrame(of: "After.", in: view)
        #expect(after.minY - before.maxY >= block.bounds.height, "after \(after) before \(before)")
        // Narrower, the block is sized again.
        scrollView.frame = NSRect(x: 0, y: 0, width: 500, height: 600)
        view.laidOut()
        #expect(block.bounds.width == view.textContainer!.size.width && block.bounds.height > 500)
        // Narrow as a phone, the cards go one to a row: three covers at 16:9 of the column alone are over 500.
        scrollView.frame = NSRect(x: 0, y: 0, width: 380, height: 600)
        view.laidOut()
        let column = view.textContainer!.size.width
        #expect(column < CardGridView.oneColumnBelow)
        #expect(block.bounds.height > 3 * column * 9 / 16 + 3 * 60, "one column: \(block.bounds.height) at \(column)")
    }
}
#endif

#if canImport(AppKit)
@Suite @MainActor struct ResizeTests {
    @Test func aResizeKeepsTheTopLineAndThePageItsHeight() throws {
        let page = Page(title: "T", body: (0..<400).map { .paragraph([Run("Paragraph \($0) " + String(repeating: "words ", count: 12))]) })
        let (scrollView, view) = try shown(page, width: 600, height: 300)
        // Scroll so paragraph 250 starts 7 points above the viewport top.
        let target = try lineFrame(of: "Paragraph 250 ", in: view)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: target.minY + 7))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        scrollView.frame = NSRect(x: 0, y: 0, width: 400, height: 300)
        view.laidOut()
        let after = try lineFrame(of: "Paragraph 250 ", in: view)
        #expect(abs(scrollView.contentView.bounds.minY - (after.minY + 7)) < 1, "top \(scrollView.contentView.bounds.minY) line \(after.minY)")
        #expect(view.frame.height > 400 * 20, "the page is as tall as its paragraphs: \(view.frame.height)")
    }

    @Test func aResizeThereAndBackLeavesTheViewportWhereItWas() throws {
        // Long paragraphs, so the top of the viewport is mid-paragraph.
        let page = Page(title: "T", body: (0..<40).map { .paragraph([Run("Paragraph \($0) " + String(repeating: "words of some length ", count: 60))]) })
        let (scrollView, view) = try shown(page, width: 600, height: 300)
        let target = try lineFrame(of: "Paragraph 20 ", in: view)
        // Eight lines and a bit into the paragraph.
        let start = target.minY + 8 * target.height + 5
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: start))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        // Shrink step by step, then grow back to the same width: the same layout, the same place.
        for width in Array(stride(from: 590, through: 400, by: -10)) + Array(stride(from: 410, through: 600, by: 10)) {
            scrollView.frame = NSRect(x: 0, y: 0, width: CGFloat(width), height: 300)
            view.laidOut()
        }
        #expect(abs(scrollView.contentView.bounds.minY - start) < 1, "top \(scrollView.contentView.bounds.minY) started at \(start)")
    }
}
#endif

#if canImport(AppKit)
@Suite @MainActor struct OwnershipTests {
    @Test func theTextViewCannotScrollThePageAndThePageOpensAtItsRestingTop() throws {
        let page = Page(title: "T", body: (0..<200).map { .paragraph([Run("Paragraph \($0) words words words.")]) })
        let (scrollView, view) = try shown(page, width: 600, height: 300)
        // Under a toolbar the resting top is above zero; the page opens there, margin and all.
        scrollView.contentInsets = NSEdgeInsets(top: 52, left: 0, bottom: 0, right: 0)
        scrollView.automaticallyAdjustsContentInsets = false
        view.show(Page(title: "U", body: (0..<200).map { .paragraph([Run("Other \($0) words words words.")]) }))
        #expect(scrollView.contentView.bounds.minY == -52, "top \(scrollView.contentView.bounds.minY)")
        // Whatever the text view asks to scroll into view, the page does not move.
        view.textView.scrollRangeToVisible(NSRange(location: view.string.count - 5, length: 1))
        view.textView.setSelectedRange(NSRange(location: view.string.count - 5, length: 1))
        view.textView.scrollRangeToVisible(view.textView.selectedRange())
        #expect(scrollView.contentView.bounds.minY == -52, "top \(scrollView.contentView.bounds.minY)")
    }
}
#endif

@MainActor struct ListingTests {
    @Test func aListingIsHighlightedAsOnTheWeb() throws {
        let page = Page(title: "T", body: [.code(Code(lines: ["func f() {", "    // hi", "}"], language: "swift"))])
        let text = NSAttributedString(page: page)
        let string = text.string
        let function = try #require(string.range(of: "func"))
        let comment = try #require(string.range(of: "// hi"))
        let brace = try #require(string.range(of: "}"))
        let color = { (range: Range<String.Index>) in text.attribute(.foregroundColor, at: string.distance(from: string.startIndex, to: range.lowerBound), effectiveRange: nil) as? PlatformColor }
        #expect(color(function) == SyntaxTheme.color(for: ["keyword"]))
        #expect(color(comment) == SyntaxTheme.color(for: ["comment"]))
        #expect(color(brace) == .label)
        #expect(string.contains("{\u{2028}    // hi\u{2028}}"), "one paragraph, lines separated")
    }

    @Test func aListingSitsInABox() throws {
        let page = Page(title: "T", body: [.paragraph([Run("Before.")]), .code(Code(lines: ["let a = 1"], language: "swift")), .paragraph([Run("After.")])])
        let (_, view) = try shown(page)
        let layout = try #require(view.layoutManager)
        let width = view.textContainer!.size.width
        let box = try #require(view.content?.codeBoxes(in: layout, width: width).first?.rect)
        #expect(box.minX == 0 && box.width == width)
        let code = try #require(view.string.range(of: "let a"))
        let glyph = layout.glyphIndexForCharacter(at: view.string.distance(from: view.string.startIndex, to: code.lowerBound))
        let line = layout.lineFragmentUsedRect(forGlyphAt: glyph, effectiveRange: nil)
        #expect(line.minX == CodeBox.border + CodeBox.inset, "the code keeps clear of the box's edge")
        #expect(box.minY < line.minY && box.maxY > line.maxY, "the box holds the line")
    }

    @Test func aTabThatIsOneListingHasNoBoxOfItsOwn() throws {
        let listing = Block.code(Code(lines: ["let a = 1"], language: "swift"))
        let alone = Page(title: "T", body: [.tabs([Tab(title: "A", blocks: [listing]), Tab(title: "B", blocks: [])])])
        #expect(PageContent(text: NSAttributedString(page: alone)).codeBoxes.isEmpty, "the group's box is the listing's")
        let withText = Page(title: "T", body: [.tabs([Tab(title: "A", blocks: [.paragraph([Run("Do:")]), listing]), Tab(title: "B", blocks: [])])])
        #expect(PageContent(text: NSAttributedString(page: withText)).codeBoxes.count == 1)
    }
}

@MainActor struct DecoratedTitleTests {
    @Test func aSymbolTopicShowsItsDeclarationTokens() throws {
        let item = Links.Item(title: "init(name:)", fragments: [Token("init", kind: "identifier"), Token("(", kind: "text"), Token("name", kind: "externalParam"), Token(": ", kind: "text"), Token("String", kind: "typeIdentifier"), Token(")", kind: "text")], link: "/a", isDeprecated: true)
        let text = NSAttributedString(page: Page(title: "T", body: [.links(Links(items: [item]))]))
        let string = text.string as NSString
        let name = string.range(of: "init(")
        let type = string.range(of: "String")
        #expect(text.attribute(.foregroundColor, at: name.location, effectiveRange: nil) as? PlatformColor == .link)
        #expect(text.attribute(.foregroundColor, at: type.location, effectiveRange: nil) as? PlatformColor == .secondaryLabel, "decorators are secondary")
        #expect((text.attribute(.font, at: type.location, effectiveRange: nil) as? PlatformFont)?.isFixedPitch == true)
        #expect(text.attribute(.link, at: type.location, effectiveRange: nil) != nil, "the whole title is the link")
        #expect(text.attribute(.strikethroughStyle, at: name.location, effectiveRange: nil) != nil, "deprecated symbols are struck through")
    }

    @Test func smallPrintIsSmall() throws {
        let text = NSAttributedString(page: Page(title: "T", body: [.paragraph([Run("Body.")]), .small([Run("Fine print.")])]))
        let string = text.string as NSString
        let body = (text.attribute(.font, at: string.range(of: "Body.").location, effectiveRange: nil) as? PlatformFont)?.pointSize ?? 0
        let small = (text.attribute(.font, at: string.range(of: "Fine").location, effectiveRange: nil) as? PlatformFont)?.pointSize ?? 0
        #expect(small < body)
    }

    @Test func parentsAreLinksAboveTheEyebrow() throws {
        let page = Page(title: "Leaf", roleHeading: "Structure", parents: [Links.Item(title: "X", link: "/x"), Links.Item(title: "Mid", link: "/x/mid")])
        let text = NSAttributedString(page: page)
        let string = text.string as NSString
        let mid = string.range(of: "Mid")
        #expect(mid.location < string.range(of: "Structure").location)
        #expect(text.attribute(.link, at: mid.location, effectiveRange: nil) as? URL == PageLink.url(for: "/x/mid"))
        #expect(text.attribute(.link, at: string.range(of: "›").location, effectiveRange: nil) == nil)
    }

    @Test func aDownloadIsAButtonUnderTheHeader() throws {
        let page = Page(title: "T", download: Download(title: "Download", url: "https://x/y.zip"), body: [.paragraph([Run("Body.")])])
        let content = PageContent(text: NSAttributedString(page: page))
        #expect(content.blocks.count == 1)
        #expect(try #require(content.blocks.first).index < (content.text.string as NSString).range(of: "Body.").location)
    }
}

@MainActor struct TableTests {
    private func cell(_ text: String, columnSpan: Int = 1, rowSpan: Int = 1) -> DocBPage.Table.Cell {
        DocBPage.Table.Cell([.paragraph([Run(text)])], columnSpan: columnSpan, rowSpan: rowSpan)
    }

    @Test func spansTakeTheirPlaces() {
        let table = DocBPage.Table(header: .row, rows: [
            [cell("A", columnSpan: 2), cell("B")],
            [cell("C", rowSpan: 2), cell("D"), cell("E")],
            [cell("F"), cell("G")],
        ])
        let placed = TableView(table: table, width: 600).placed
        #expect(placed.map { $0.map(\.column) } == [[0, 2], [0, 1, 2], [0, 1, 2]])
        #expect(placed[0].map(\.span) == [2, 1])
        #expect(placed[2][0].cell == nil, "under a row span: an empty cell")
        #expect(placed[0].allSatisfy(\.isHeader) && !placed[1][0].isHeader)
    }

    @Test func aTableIsAHostedBlockWithHeight() throws {
        let table = DocBPage.Table(header: .row, rows: [[cell("Name"), cell("Description")], [cell("x"), cell("A value with some words in it.")]])
        let (_, view) = try shown(Page(title: "T", body: [.table(table)]))
        let block = try #require(view.content?.blocks.first?.block)
        #expect(block.bounds.height > 2 * TableView.padding, "two rows of text: \(block.bounds)")
        #expect(block.bounds.width == view.textContainer!.size.width)
    }
}
