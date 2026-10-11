// The page on screen: the platform's text view on TextKit 1, which lays the whole document
// out contiguously, so every position is exact and nothing is estimated, relocated or laid
// out a pass late; and which brings selection, copy, the context menus (Look Up, Translate,
// Services, the link menu), find, pointers and accessibility. What it does not do is done
// here: the hero band and the callout boxes are drawn behind the text, SwiftUI blocks
// (images, card grids) are views placed over their attachments, sized to the column, and
// links are routed to the host by their page reference.

import DocBPage
import SwiftUI
#if canImport(AppKit)
import AppKit
typealias PlatformView = NSView
#else
import UIKit
typealias PlatformView = UIView
#endif

/// A page, laid out as one document that reflows like a browser. Links call `openLink` with the
/// page model's reference string for the host to resolve; images ask `loadImage` for their
/// bytes by the same kind of reference, and are fitted in as they arrive.
public struct PageView: View {
    let page: Page
    let openLink: (String) -> Void
    let loadImage: ImageLoader

    public init(page: Page, openLink: @escaping (String) -> Void, loadImage: @escaping ImageLoader = defaultImageLoader) {
        self.page = page
        self.openLink = openLink
        self.loadImage = loadImage
    }

    public var body: some View {
        PageTextView(page: page, openLink: openLink, loadImage: loadImage)
    }
}

// MARK: - What the text carries

/// What a page's text carries besides text, found once when the text is set: the hero, the
/// callouts, and the hosted blocks; and where each sits once laid out.
final class PageContent {
    let text: NSAttributedString
    let hero: Hero?
    private let heroLength: Int
    let callouts: [(range: NSRange, callout: Callout)]
    let tabBoxes: [(range: NSRange, box: TabBox)]
    let codeBoxes: [(range: NSRange, box: CodeBox)]
    let rules: [(index: Int, rule: Rule)]
    let topicMarks: [(range: NSRange, mark: TopicMark)]
    let blocks: [(index: Int, block: BlockAttachment)]

    init(text: NSAttributedString) {
        self.text = text
        let all = NSRange(location: 0, length: text.length)
        var range = NSRange()
        hero = text.length > 0 ? text.attribute(.hero, at: 0, longestEffectiveRange: &range, in: all) as? Hero : nil
        heroLength = range.length
        var callouts: [(NSRange, Callout)] = []
        text.enumerateAttribute(.callout, in: all) { value, range, _ in
            if let callout = value as? Callout { callouts.append((range, callout)) }
        }
        self.callouts = callouts
        var tabBoxes: [(NSRange, TabBox)] = []
        text.enumerateAttribute(.tabBox, in: all) { value, range, _ in
            if let box = value as? TabBox { tabBoxes.append((range, box)) }
        }
        self.tabBoxes = tabBoxes
        var codeBoxes: [(NSRange, CodeBox)] = []
        text.enumerateAttribute(.codeBox, in: all) { value, range, _ in
            if let box = value as? CodeBox { codeBoxes.append((range, box)) }
        }
        self.codeBoxes = codeBoxes
        var rules: [(Int, Rule)] = []
        text.enumerateAttribute(.rule, in: all) { value, range, _ in
            if let rule = value as? Rule { rules.append((range.location, rule)) }
        }
        self.rules = rules
        var marks: [(NSRange, TopicMark)] = []
        text.enumerateAttribute(.topicMark, in: all) { value, range, _ in
            if let mark = value as? TopicMark { marks.append((range, mark)) }
        }
        topicMarks = marks
        var blocks: [(Int, BlockAttachment)] = []
        text.enumerateAttribute(.attachment, in: all) { value, range, _ in
            if let block = value as? BlockAttachment { blocks.append((range.location, block)) }
        }
        self.blocks = blocks
    }

    /// The line a character is on, in container coordinates: the whole fragment, with the
    /// paragraph's spacing before and after as part of it.
    private func line(at index: Int, in layout: NSLayoutManager) -> CGRect {
        layout.lineFragmentRect(forGlyphAt: layout.glyphIndexForCharacter(at: index), effectiveRange: nil)
    }

    /// Where the hero reaches down to, in container coordinates: the header's last line carries
    /// the band's bottom padding and the gap below the band in its paragraph spacing.
    func heroBottom(in layout: NSLayoutManager) -> CGFloat? {
        guard hero != nil, heroLength > 0 else { return nil }
        return line(at: heroLength - 1, in: layout).maxY - Hero.gap
    }

    /// A box reaches from the first paragraph's spacing before down to the last one's spacing
    /// after, less the padding each carries for it (a line's rect includes both).
    private func box(around range: NSRange, padding: CGFloat, indent: CGFloat, width: CGFloat, in layout: NSLayoutManager) -> CGRect? {
        guard range.length > 0 else { return nil }
        let before = (text.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle)?.paragraphSpacingBefore ?? 0
        let after = (text.attribute(.paragraphStyle, at: NSMaxRange(range) - 1, effectiveRange: nil) as? NSParagraphStyle)?.paragraphSpacing ?? 0
        let top = line(at: range.location, in: layout).minY + before - padding
        let bottom = line(at: NSMaxRange(range) - 1, in: layout).maxY - after + padding
        return CGRect(x: indent, y: top, width: width - indent, height: bottom - top)
    }

    func calloutBoxes(in layout: NSLayoutManager, width: CGFloat) -> [(callout: Callout, box: CGRect)] {
        callouts.compactMap { range, callout in
            box(around: range, padding: Callout.padding, indent: callout.indent, width: width, in: layout).map { (callout, $0) }
        }
    }

    /// The tab boxes, each with where its bar ends: the bar is the first block in the box, on
    /// the baseline of its line.
    func tabBoxes(in layout: NSLayoutManager, width: CGFloat) -> [(box: TabBox, rect: CGRect, barBottom: CGFloat)] {
        tabBoxes.compactMap { range, tab in
            guard let rect = box(around: range, padding: TabBox.padding, indent: tab.indent, width: width, in: layout) else { return nil }
            var barBottom = rect.minY
            if let bar = blocks.first(where: { NSLocationInRange($0.index, range) }) {
                let glyph = layout.glyphIndexForCharacter(at: bar.index)
                barBottom = line(at: bar.index, in: layout).minY + layout.location(forGlyphAt: glyph).y
            }
            return (tab, rect, barBottom)
        }
    }

    func codeBoxes(in layout: NSLayoutManager, width: CGFloat) -> [(box: CodeBox, rect: CGRect)] {
        codeBoxes.compactMap { range, code in
            box(around: range, padding: CodeBox.padding, indent: code.indent, width: width, in: layout).map { (code, $0) }
        }
    }

    /// The showing content of a tab group, for the document to swap.
    func tabContentRange(of group: TabGroup) -> NSRange? {
        var found: NSRange?
        text.enumerateAttribute(.tabContent, in: NSRange(location: 0, length: text.length)) { value, range, stop in
            if let value = value as? TabGroup, value === group { found = range; stop.pointee = true }
        }
        return found
    }

    /// Every topic mark and the box of its title's capitals on the first line, in container
    /// coordinates: the line's own box has its extra leading above the glyphs, so its middle
    /// is not the text's.
    func topicBoxes(in layout: NSLayoutManager) -> [(mark: TopicMark, box: CGRect)] {
        topicMarks.map { range, mark in
            let glyph = layout.glyphIndexForCharacter(at: range.location)
            let baseline = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil).minY + layout.location(forGlyphAt: glyph).y
            let capHeight = (text.attribute(.font, at: range.location, effectiveRange: nil) as? PlatformFont)?.capHeight ?? 0
            return (mark, CGRect(x: mark.indent, y: baseline - capHeight, width: TopicMark.width, height: capHeight))
        }
    }

    /// Every rule and its line, through the middle of its paragraph's own line, in container coordinates.
    func ruleRects(in layout: NSLayoutManager, width: CGFloat) -> [(rule: Rule, rect: CGRect)] {
        rules.map { index, rule in
            let style = text.attribute(.paragraphStyle, at: index, effectiveRange: nil) as? NSParagraphStyle
            let line = line(at: index, in: layout)
            let middle = line.minY + (style?.paragraphSpacingBefore ?? 0) + (line.height - (style?.paragraphSpacingBefore ?? 0) - (style?.paragraphSpacing ?? 0)) / 2
            return (rule, CGRect(x: rule.indent, y: (middle - Rule.thickness / 2).rounded(), width: width - rule.indent, height: Rule.thickness))
        }
    }

    /// Every block and where its attachment sits, in container coordinates.
    func blockFrames(in layout: NSLayoutManager, container: NSTextContainer) -> [(block: BlockAttachment, frame: CGRect)] {
        blocks.map { index, block in
            let glyphs = layout.glyphRange(forCharacterRange: NSRange(location: index, length: 1), actualCharacterRange: nil)
            let rect = layout.boundingRect(forGlyphRange: glyphs, in: container)
            // On the baseline of its line, per its bounds: a glyph's location is baseline-relative.
            let line = layout.lineFragmentRect(forGlyphAt: glyphs.location, effectiveRange: nil)
            let baseline = line.minY + layout.location(forGlyphAt: glyphs.location).y
            return (block, CGRect(x: rect.minX, y: baseline - block.bounds.maxY, width: block.bounds.width, height: block.bounds.height))
        }
    }
}

/// Where the reader is: the line at the top of the viewport and how far into it the top is,
/// as a character, so it can be put back after a relayout.
struct LineAnchor {
    var index: Int
    var offset: CGFloat

    init?(_ layout: NSLayoutManager, container: NSTextContainer, viewportTop y: CGFloat) {
        guard layout.numberOfGlyphs > 0 else { return nil }
        let glyph = layout.glyphIndex(for: CGPoint(x: 0, y: max(0, y)), in: container)
        let line = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        index = layout.characterIndexForGlyph(at: glyph)
        offset = y - line.minY
    }

    /// Where the viewport top belongs after relayout.
    func viewportTop(in layout: NSLayoutManager) -> CGFloat? {
        guard layout.numberOfGlyphs > 0 else { return nil }
        let glyph = min(layout.glyphIndexForCharacter(at: index), layout.numberOfGlyphs - 1)
        return layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil).minY + offset
    }
}

/// The page's hosted blocks, sized to the column, and the images they show; the view is told
/// when sizes changed so it lays the text out again.
@MainActor
final class PageAssets {
    var loadImage: ImageLoader = defaultImageLoader { didSet { pageImages.loader = loadImage } }
    var openLink: (String) -> Void = { _ in }
    var selectTab: (TabGroup, Int) -> Void = { _, _ in }
    /// The appearance the images are chosen for; changing it fetches the other variants.
    var dark = false { didSet { pageImages.dark = dark } }
    /// Runs after sizes changed, on the main actor.
    var changed: (() -> Void)?
    let pageImages = PageImages()
    private var blocks: [BlockAttachment] = []
    private var sizers: [ObjectIdentifier: PlatformHostingController] = [:]
    private var width: CGFloat = 0
    private var fitPending = false
    /// Changes when the blocks are to drop their text selections: a block's view is identified
    /// by it, so a new value is a new view, with nothing selected. There is no way to ask a
    /// SwiftUI text for its selection or to clear it.
    private var selectionGeneration = 0

    /// The blocks' views, made anew: whatever they had selected is gone.
    func deselectBlocks() { selectionGeneration += 1 }

    init() {
        pageImages.arrived = { [weak self] in self?.scheduleFit() }
    }

    func set(_ content: PageContent, width: CGFloat) {
        blocks = content.blocks.map(\.block)
        sizers = [:]
        self.width = width
        _ = fit()
    }

    /// The column changed: everything is sized to it again. Returns whether anything changed.
    func fit(width: CGFloat) -> Bool {
        guard width != self.width else { return false }
        self.width = width
        return fit()
    }

    private var measuring = false

    private func fit() -> Bool {
        measuring = true
        defer { measuring = false }
        var changed = false
        for block in blocks {
            let id = ObjectIdentifier(block)
            let sizer = sizers[id] ?? { let sizer = PlatformHostingController(rootView: hosted(block)); sizers[id] = sizer; return sizer }()
            sizer.rootView = hosted(block)
            let blockWidth = max(1, width - block.insets)
            let height = ceil(sizer.sizeThatFits(in: CGSize(width: blockWidth, height: .greatestFiniteMagnitude)).height)
            let bounds = CGRect(x: 0, y: 0, width: blockWidth, height: height)
            changed = changed || block.bounds != bounds
            block.bounds = bounds
        }
        return changed
    }

    /// A block's view with the page's environment on it, for measuring. Fixed vertically, so
    /// measuring proposes a width and gets the height the view wants.
    private func hosted(_ block: BlockAttachment) -> AnyView {
        AnyView(block.content(max(1, width - block.insets))
            .id(selectionGeneration)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.openPageLink, openLink)
            .environment(\.selectTab, selectTab)
            .environment(pageImages))
    }

    /// A block's view for placing on the page: it reports its height as it changes (a picture
    /// arrived, text rewrapped), which is what the block is; the measuring controller's answer
    /// is only for before the view exists. Only the placed view reports: the measuring one is
    /// never given a frame, and what it would report, laid out at no width, is nonsense.
    func placed(_ block: BlockAttachment) -> AnyView {
        AnyView(hosted(block)
            .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { [weak self, weak block] height in
                guard let self, let block else { return }
                reported(block, height: height)
            })
    }

    /// A block's view says it is another height: the block takes it and the page is laid out again.
    private func reported(_ block: BlockAttachment, height: CGFloat) {
        let height = ceil(height)
        // The measuring controller's view reports too, mid-measurement; that answer is taken there.
        guard !measuring, height > 0, height != block.bounds.height, blocks.contains(where: { $0 === block }) else { return }
        block.bounds.size.height = height
        changed?()
    }

    /// Pictures arriving together are fitted once, on the next turn of the run loop.
    private func scheduleFit() {
        guard !fitPending else { return }
        fitPending = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            fitPending = false
            if fit() { changed?() }
        }
    }
}

// MARK: - macOS

#if canImport(AppKit)
struct PageTextView: NSViewRepresentable {
    let page: Page
    let openLink: (String) -> Void
    let loadImage: ImageLoader

    func makeNSView(context: Context) -> NSScrollView {
        TextDocumentView.scrollable()
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let view = scrollView.documentView as? TextDocumentView else { return }
        view.openLink = openLink
        view.assets.loadImage = loadImage
        view.show(page)
    }
}

/// The cell for a block's attachment: nothing is drawn, the block's view is over it.
private final class BlockCell: NSTextAttachmentCell {
    override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {}
    override func cellSize() -> NSSize { attachment?.bounds.size ?? .zero }
    override func cellBaselineOffset() -> NSPoint { .zero }
}

/// The text, in a text view that cannot scroll: its frame is the page's and its scroll
/// requests stop at the view around it, so it never moves the reader on its own.
final class PageText: NSTextView {
    var openLink: (String) -> Void = { _ in }
    /// No pointer of its own: its cursor rects and pointer updates would keep asserting the
    /// I-beam under the hosted blocks beside it, over their own pointers, and its mouse moves
    /// would set the I-beam over a link in a race with the page, which sets the pointer over
    /// the text from its mouse tracking, and alone.
    override func resetCursorRects() {}
    override func cursorUpdate(with event: NSEvent) {}
    override func mouseMoved(with event: NSEvent) {}

    /// No scroll view of its own: what it would scroll into view (its insertion point after a
    /// text change, a line boundary after a live resize) it cannot; the page keeps its place.
    override var enclosingScrollView: NSScrollView? { nil }
    override func scrollToVisible(_ rect: NSRect) -> Bool { false }
    override func scrollRangeToVisible(_ range: NSRange) {}

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event)
        // ponytail: the link items act on the private link URL; "Copy Link" goes until the host
        // can hand over the page's web address.
        menu?.items.filter { $0.title == "Copy Link" }.forEach { menu?.removeItem($0) }
        return menu
    }

    /// Code listings are one paragraph with line separators; copied, they become lines.
    override func writeSelection(to pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        guard let storage = textStorage else { return false }
        let text = NSMutableAttributedString(attributedString: storage.attributedSubstring(from: selectedRange()))
        text.mutableString.replaceOccurrences(of: "\u{2028}", with: "\n", range: NSRange(location: 0, length: text.length))
        switch type {
        case .string: return pboard.setString(text.string, forType: type)
        case .rtf: return pboard.setData(text.rtf(from: NSRange(location: 0, length: text.length)), forType: type)
        default: return super.writeSelection(to: pboard, type: type)
        }
    }
}

/// The page: the scroll view's document. It owns the offset and the reader's place across
/// relayouts, draws the hero and the callouts behind the text, and places the blocks' views.
final class TextDocumentView: NSView, NSTextViewDelegate {
    private(set) var page: Page?
    private(set) var content: PageContent?
    let assets = PageAssets()
    let textView: PageText
    var openLink: (String) -> Void = { _ in } {
        didSet { assets.openLink = openLink; textView.openLink = openLink }
    }
    /// Space around the text; the sides grow past a measure so lines stay readable when wide.
    private var inset = NSSize(width: 24, height: 24)
    /// The one view hosting the blocks' views, over the text.
    let host = BlockHost()
    private var hostedViews: [ObjectIdentifier: AnyView] = [:]
    /// Whether a block was clicked since the blocks last dropped their selections: only then
    /// might one hold a selection to drop when the text starts its own.
    private var blockClicked = false
    /// Sees every click in the window before its view does: a click in a block ends the
    /// text's selection. The blocks' own views never see it; SwiftUI's selectable text is a
    /// text field of its own inside them, and it takes the click.
    private var clickMonitor: Any?

    static func scrollable() -> NSScrollView {
        let view = TextDocumentView(frame: .zero)
        let scrollView = NSScrollView()
        scrollView.documentView = view
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .windowBackgroundColor
        // AppKit resets every cursor rect in the window on each frame of a scroll, walking every
        // view; with a sidebar of forty rows that is a tenth of the frame. Cursor rects are off
        // while the page keeps moving and rebuilt once when it has come to rest.
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(view, selector: #selector(scrolled), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        return scrollView
    }

    override init(frame: NSRect) {
        // The TextKit 1 stack by hand, laid out contiguously: no estimates, ever.
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        layout.allowsNonContiguousLayout = false
        let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        container.widthTracksTextView = true
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        textView = PageText(frame: .zero, textContainer: container)
        super.init(frame: frame)
        autoresizingMask = [.width]
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.drawsBackground = false
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = false
        textView.linkTextAttributes = [.foregroundColor: NSColor.linkColor, .cursor: NSCursor.pointingHand]
        textView.delegate = self
        addSubview(textView)
        addSubview(host)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect], owner: self))
        assets.changed = { [weak self] in self?.sizesChanged() }
        assets.selectTab = { [weak self] group, index in self?.select(tab: index, in: group) }
    }

    private var lastBlock: ObjectIdentifier?

    /// The pointer: an I-beam over text and a hand over a link, set here since the text view
    /// keeps no cursor rects. A hosted block sets its own (a link, an I-beam over selectable
    /// text), so on the way into one the pointer is reset once and then left alone.
    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let hit = hitTest(point)
        let block = hit?.isDescendant(of: host) == true ? host.item(at: point)?.id : nil
        defer { lastBlock = block }
        guard hit === textView || hit?.isDescendant(of: textView) == true else {
            if block != lastBlock || block == nil { NSCursor.arrow.set() }
            return
        }
        (link(at: textView.convert(point, from: self)) == nil ? NSCursor.iBeam : NSCursor.pointingHand).set()
    }

    /// The link under a point in the text view, if the point is on a glyph of one.
    private func link(at point: NSPoint) -> URL? {
        let local = NSPoint(x: point.x - textView.textContainerOrigin.x, y: point.y - textView.textContainerOrigin.y)
        var fraction: CGFloat = 0
        let glyph = layout.glyphIndex(for: local, in: container, fractionOfDistanceThroughGlyph: &fraction)
        guard glyph < layout.numberOfGlyphs, layout.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: container).contains(local) else { return nil }
        return textView.textStorage?.attribute(.link, at: layout.characterIndexForGlyph(at: glyph), effectiveRange: nil) as? URL
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { true }

    /// The text view's scroll requests end here: after a text change it would scroll its
    /// insertion point into view, and at the end of a live resize a line boundary; the page's
    /// place is this view's to keep.
    override func scrollToVisible(_ rect: NSRect) -> Bool { false }

    /// Shows a page; the same page again is left alone, so SwiftUI updates cost nothing.
    func show(_ page: Page) {
        guard page != self.page else { return }
        self.page = page
        show(NSAttributedString(page: page))
    }

    func show(_ text: NSAttributedString) {
        let content = PageContent(text: text)
        self.content = content
        for (_, block) in content.blocks { block.attachmentCell = BlockCell() }
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.textStorage?.setAttributedString(text)
        assets.set(content, width: columnWidth)
        kept = nil
        relayout(keeping: nil)
        scroll(top: -.infinity)
        needsDisplay = true
    }

    private var columnWidth: CGFloat { max(1, frame.width - 2 * inset.width) }
    private var textSize: CGFloat { PlatformFont.preferredFont(forTextStyle: .body).pointSize }
    private var origin: CGPoint { CGPoint(x: inset.width, y: inset.height) }
    private var dark: Bool { effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua }
    private var layout: NSLayoutManager { textView.layoutManager! }
    private var container: NSTextContainer { textView.textContainer! }

    // MARK: Layout

    /// The reader's place: the line at the top of the viewport and how far into it the top is.
    /// Kept from one relayout to the next while the viewport is where the last one left it:
    /// taken anew from each layout, it walks back a line at a time, as the character that
    /// started the line at the top ends up mid-line once the text rewraps, and the line it is
    /// on then starts earlier, until a resize ends at the start of a paragraph.
    private var kept: (anchor: LineAnchor, top: CGFloat)?
    private var place: LineAnchor? {
        guard let clip = enclosingScrollView?.contentView else { return nil }
        if let kept, abs(kept.top - clip.bounds.minY) < 0.5 { return kept.anchor }
        return LineAnchor(layout, container: container, viewportTop: clip.bounds.minY - inset.height)
    }

    /// Lays the text out, sizes the text view and this view to it, places the blocks' views,
    /// and puts the reader's line back under the viewport top.
    private func relayout(keeping place: LineAnchor?) {
        textView.textContainerInset = inset
        textView.frame.size.width = frame.width
        layout.ensureLayout(for: container)
        let height = layout.usedRect(for: container).height + 2 * inset.height
        textView.frame = NSRect(x: 0, y: 0, width: frame.width, height: height)
        let clip = enclosingScrollView?.contentView.bounds ?? .zero
        // A third of a viewport below the page, so the last lines can be brought up to read.
        super.setFrameSize(NSSize(width: frame.width, height: max(height + clip.height / 3, clip.height)))
        placeBlocks()
        if let place { settle(place) }
        prepareContent(in: bounds)
    }

    private func settle(_ place: LineAnchor) {
        guard let top = place.viewportTop(in: layout) else { return }
        scroll(top: top + inset.height)
        if let clip = enclosingScrollView?.contentView { kept = (place, clip.bounds.minY) }
    }

    /// Puts the viewport top at `y`, within what the clip view allows: under a toolbar its
    /// content inset makes the resting position at the top a negative origin, and the page end
    /// caps it. On the pixel grid: the clip view snaps its origin there afterwards anyway, and
    /// the place kept for the next relayout must be where the viewport then is.
    private func scroll(top y: CGFloat) {
        guard let clip = enclosingScrollView?.contentView else { return }
        let scale = window?.backingScaleFactor ?? 2
        var rect = clip.bounds
        rect.origin = NSPoint(x: 0, y: y.isFinite ? (y * scale).rounded() / scale : y)
        let target = clip.constrainBoundsRect(rect).origin
        guard abs(clip.bounds.minY - target.y) > 0.5 else { return }
        clip.scroll(to: target)
        enclosingScrollView?.reflectScrolledClipView(clip)
    }

    /// The blocks' views over their attachments, made on first sight and moved thereafter.
    private func placeBlocks() {
        guard let content else { return }
        var placed = Set<ObjectIdentifier>()
        host.frame = bounds
        host.placements.size = bounds.size
        host.placements.items = content.blockFrames(in: layout, container: container).map { block, frame in
            let id = ObjectIdentifier(block)
            placed.insert(id)
            let view = hostedViews[id] ?? { let view = assets.placed(block); hostedViews[id] = view; return view }()
            return BlockPlacements.Item(id: id, view: view, frame: frame.offsetBy(dx: origin.x, dy: origin.y))
        }
        for id in hostedViews.keys where !placed.contains(id) { hostedViews[id] = nil }
    }

    /// The column: the text sits in a measure of at most 760 points, centered, with 24 points
    /// around it; the view is as wide as the scroll view. A new width is a new layout, with
    /// the reader's line kept under the viewport top.
    override func setFrameSize(_ newSize: NSSize) {
        guard newSize.width != frame.width else { return super.setFrameSize(newSize) }
        let place = self.place
        super.setFrameSize(newSize)
        inset.width = max(24, (newSize.width - 760) / 2)
        _ = assets.fit(width: columnWidth)
        rehostBlocks()
        relayout(keeping: place)
        needsDisplay = true
    }

    /// The blocks' views built again: for a new width, or to drop their selections.
    private func rehostBlocks() {
        guard let content else { return }
        for (_, block) in content.blocks { hostedViews[ObjectIdentifier(block)] = assets.placed(block) }
        placeBlocks()
    }

    /// Blocks changed size: the text is laid out again around them.
    private func sizesChanged() {
        let place = self.place
        layout.invalidateLayout(forCharacterRange: NSRange(location: 0, length: textView.textStorage?.length ?? 0), actualCharacterRange: nil)
        relayout(keeping: place)
        needsDisplay = true
    }

    /// Responsive scrolling shows only what is already drawn into its cache, so the whole page
    /// is drawn into it, right after layout rather than when AppKit gets around to asking: a
    /// viewport draws in a few milliseconds, the longest page in under a second, and a flick
    /// can then land anywhere. Viewports of overdraw, one to five, were always outrun.
    // ponytail: the cache is a bitmap, roughly 15 MB per viewport of a 1200-point window at 2x;
    // a bound on it would come back to overdraw counted from the viewport.
    override func prepareContent(in rect: NSRect) {
        super.prepareContent(in: bounds)
        // The text view is a layer of its own, with its own cache: prepared alongside.
        textView.prepareContent(in: textView.bounds)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        assets.dark = dark
        needsDisplay = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        assets.dark = dark
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        clickMonitor = window == nil ? nil : NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.clicked(event)
            return event
        }
    }

    private var cameToRest: DispatchWorkItem?

    @objc private func scrolled() {
        guard let window else { return }
        if window.areCursorRectsEnabled { window.disableCursorRects() }
        cameToRest?.cancel()
        let rest = DispatchWorkItem { [weak self] in
            guard let window = self?.window, !window.areCursorRectsEnabled else { return }
            window.enableCursorRects()
            window.resetCursorRects()
        }
        cameToRest = rest
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: rest)
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        NSColor.windowBackgroundColor.setFill()
        dirtyRect.fill()
        guard let content else { return }
        if let hero = content.hero, let bottom = content.heroBottom(in: layout) {
            let band = NSRect(x: 0, y: 0, width: bounds.width, height: bottom + origin.y)
            if band.intersects(dirtyRect) {
                hero.draw(in: band, dirty: dirtyRect, trailing: bounds.width - inset.width, context: context, dark: dark, fill: .windowBackgroundColor)
            }
        }
        for (callout, box) in content.calloutBoxes(in: layout, width: columnWidth) {
            let box = box.offsetBy(dx: origin.x, dy: origin.y)
            if box.intersects(dirtyRect) { callout.draw(in: box, context: context, dark: dark) }
        }
        for (box, rect, barBottom) in content.tabBoxes(in: layout, width: columnWidth) {
            let rect = rect.offsetBy(dx: origin.x, dy: origin.y)
            if rect.intersects(dirtyRect) { box.draw(in: rect, barBottom: barBottom + origin.y, context: context, dark: dark) }
        }
        for (box, rect) in content.codeBoxes(in: layout, width: columnWidth) {
            let rect = rect.offsetBy(dx: origin.x, dy: origin.y)
            if rect.intersects(dirtyRect) { box.draw(in: rect, context: context, dark: dark) }
        }
        for (rule, rect) in content.ruleRects(in: layout, width: columnWidth) {
            let rect = rect.offsetBy(dx: origin.x, dy: origin.y)
            if rect.intersects(dirtyRect) { rule.draw(in: rect, context: context) }
        }
        for (mark, box) in content.topicBoxes(in: layout) {
            let box = box.offsetBy(dx: origin.x, dy: origin.y)
            if mark.rect(centeredIn: box, textSize: textSize).intersects(dirtyRect) { mark.draw(centeredIn: box, textSize: textSize, context: context) }
        }
    }

    // MARK: Tabs

    /// Shows a tab: its content takes the place of what the group showed, and the page is laid
    /// out again from there, with the reader's place, above the bar that was clicked, kept.
    func select(tab index: Int, in group: TabGroup) {
        guard let content, let storage = textView.textStorage, index != group.selected, let range = content.tabContentRange(of: group) else { return }
        group.selected = index
        let place = self.place
        let shown = tabContent(of: group, atEnd: NSMaxRange(range) == storage.length)
        storage.replaceCharacters(in: range, with: shown)
        let swapped = PageContent(text: NSAttributedString(attributedString: storage))
        self.content = swapped
        // Every attachment comes with a default cell: ours, or the swapped blocks size to nothing.
        for (_, block) in swapped.blocks { block.attachmentCell = BlockCell() }
        assets.set(swapped, width: columnWidth)
        // The edit may already be laid out, with the blocks at no size yet: again, at theirs.
        layout.invalidateLayout(forCharacterRange: NSRange(location: range.location, length: shown.length), actualCharacterRange: nil)
        relayout(keeping: place)
        needsDisplay = true
    }

    // MARK: Selection

    /// A click in a block ends the text's selection: one selection at a time.
    func clicked(_ event: NSEvent) {
        guard event.window === window, let superview,
              let hit = hitTest(superview.convert(event.locationInWindow, from: nil)),
              hit.isDescendant(of: host) else { return }
        blockClicked = true
        textView.setSelectedRange(NSRange(location: textView.selectedRange().location, length: 0))
    }

    /// The text started a selection: the blocks drop theirs.
    func textViewDidChangeSelection(_ notification: Notification) {
        guard blockClicked, textView.selectedRange().length > 0 else { return }
        blockClicked = false
        assets.deselectBlocks()
        rehostBlocks()
    }

    // MARK: Links

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard let url = link as? URL, let reference = PageLink.reference(from: url) else { return false }
        openLink(reference)
        return true
    }
}

// MARK: - iOS

#else
struct PageTextView: UIViewRepresentable {
    let page: Page
    let openLink: (String) -> Void
    let loadImage: ImageLoader

    func makeUIView(context: Context) -> UIScrollView {
        TextDocumentView.scrollable()
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let view = scrollView.subviews.first as? TextDocumentView else { return }
        view.openLink = openLink
        view.assets.loadImage = loadImage
        view.show(page)
    }
}

extension UIColor {
    /// What the page sits on: nothing on visionOS, where the text sits on the window's glass
    /// (`systemBackground` there is opaque white or black); the system background elsewhere.
    static var pageBackground: UIColor {
        #if os(visionOS)
        .clear
        #else
        .systemBackground
        #endif
    }
}

/// The scroll view around the page: a UIKit scroll view lays out nothing for its content, so
/// its own layout hands the size down.
final class PageScrollView: UIScrollView {
    override func layoutSubviews() {
        super.layoutSubviews()
        (subviews.first as? TextDocumentView)?.fit(to: bounds.size)
    }
}

/// The page: the scroll view's content. It owns the offset and the reader's place across
/// relayouts, draws the hero and the callouts behind the text, and places the blocks' views.
/// The text is in a text view that does not scroll, so it never moves the reader on its own.
final class TextDocumentView: UIView, UITextViewDelegate {
    private(set) var page: Page?
    private(set) var content: PageContent?
    let assets = PageAssets()
    let textView: UITextView
    var openLink: (String) -> Void = { _ in } {
        didSet { assets.openLink = openLink }
    }
    private var inset = CGSize(width: 24, height: 24)
    private var blockViews: [ObjectIdentifier: UIHostingController<AnyView>] = [:]

    static func scrollable() -> UIScrollView {
        let scrollView = PageScrollView()
        let view = TextDocumentView(frame: .zero)
        scrollView.addSubview(view)
        scrollView.alwaysBounceVertical = true
        scrollView.backgroundColor = .pageBackground
        return scrollView
    }

    override init(frame: CGRect) {
        // The TextKit 1 stack by hand, laid out contiguously: no estimates, ever.
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        layout.allowsNonContiguousLayout = false
        let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        container.widthTracksTextView = true
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        textView = UITextView(frame: .zero, textContainer: container)
        super.init(frame: frame)
        backgroundColor = .pageBackground
        isOpaque = false
        contentMode = .redraw
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.linkTextAttributes = [.foregroundColor: UIColor.link]
        textView.delegate = self
        addSubview(textView)
        assets.changed = { [weak self] in self?.sizesChanged() }
        assets.selectTab = { [weak self] group, index in self?.select(tab: index, in: group) }
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
            self.assets.dark = self.traitCollection.userInterfaceStyle == .dark
            self.setNeedsDisplay()
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    private var scrollView: UIScrollView? { superview as? UIScrollView }
    private var columnWidth: CGFloat { max(1, frame.width - 2 * inset.width) }
    private var textSize: CGFloat { PlatformFont.preferredFont(forTextStyle: .body).pointSize }
    private var origin: CGPoint { CGPoint(x: inset.width, y: inset.height) }
    private var layout: NSLayoutManager { textView.layoutManager }
    private var container: NSTextContainer { textView.textContainer }

    /// A page shown before the view has a size (a window opened for it) waits for the size.
    private var pending: NSAttributedString?

    func show(_ page: Page) {
        guard page != self.page else { return }
        self.page = page
        show(NSAttributedString(page: page))
    }

    func show(_ text: NSAttributedString) {
        guard frame.width > 0 else { pending = text; return }
        pending = nil
        let content = PageContent(text: text)
        self.content = content
        textView.textStorage.setAttributedString(text)
        assets.set(content, width: columnWidth)
        relayout(keeping: nil)
        scrollView?.contentOffset.y = -(scrollView?.adjustedContentInset.top ?? 0)
        kept = nil
        setNeedsDisplay()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        assets.dark = traitCollection.userInterfaceStyle == .dark
    }

    // MARK: Tabs

    /// Shows a tab, as on the Mac: the content swapped, the page laid out again from there.
    func select(tab index: Int, in group: TabGroup) {
        guard let content, index != group.selected, let range = content.tabContentRange(of: group) else { return }
        group.selected = index
        let place = self.place
        let storage = textView.textStorage
        let shown = tabContent(of: group, atEnd: NSMaxRange(range) == storage.length)
        storage.replaceCharacters(in: range, with: shown)
        let swapped = PageContent(text: NSAttributedString(attributedString: storage))
        self.content = swapped
        assets.set(swapped, width: columnWidth)
        // The edit may already be laid out, with the blocks at no size yet: again, at theirs.
        layout.invalidateLayout(forCharacterRange: NSRange(location: range.location, length: shown.length), actualCharacterRange: nil)
        relayout(keeping: place)
    }

    // MARK: Layout

    /// The reader's place, kept across relayouts while the viewport stays put, as on the Mac.
    private var kept: (anchor: LineAnchor, top: CGFloat)?
    private var place: LineAnchor? {
        guard let scrollView else { return nil }
        if let kept, abs(kept.top - scrollView.contentOffset.y) < 0.5 { return kept.anchor }
        return LineAnchor(layout, container: container, viewportTop: scrollView.contentOffset.y - inset.height)
    }

    private func relayout(keeping place: LineAnchor?) {
        textView.textContainerInset = UIEdgeInsets(top: inset.height, left: inset.width, bottom: inset.height, right: inset.width)
        textView.frame = CGRect(x: 0, y: 0, width: frame.width, height: textView.frame.height)
        layout.ensureLayout(for: container)
        let height = layout.usedRect(for: container).height + 2 * inset.height
        textView.frame = CGRect(x: 0, y: 0, width: frame.width, height: height)
        let viewport = scrollView?.bounds.height ?? 0
        let total = height + viewport / 3
        frame.size.height = total
        scrollView?.contentSize = CGSize(width: frame.width, height: total)
        placeBlocks()
        setNeedsDisplay()
        guard let place, let scrollView, let top = place.viewportTop(in: layout) else { return }
        let y = max(-scrollView.adjustedContentInset.top, min(top + inset.height, total - scrollView.bounds.height + scrollView.adjustedContentInset.bottom))
        if abs(scrollView.contentOffset.y - y) >= 0.5 { scrollView.contentOffset.y = y }
        kept = (place, scrollView.contentOffset.y)
    }

    private func placeBlocks() {
        guard let content else { return }
        var placed = Set<ObjectIdentifier>()
        for (block, frame) in content.blockFrames(in: layout, container: container) {
            let id = ObjectIdentifier(block)
            let host = blockViews[id] ?? {
                let host = UIHostingController(rootView: assets.placed(block))
                host.view.backgroundColor = .clear
                host.view.autoresizingMask = []
                addSubview(host.view)
                blockViews[id] = host
                return host
            }()
            host.view.frame = frame.offsetBy(dx: origin.x, dy: origin.y)
            placed.insert(id)
        }
        for (id, host) in blockViews where !placed.contains(id) {
            host.view.removeFromSuperview()
            blockViews[id] = nil
        }
    }

    /// Follows the scroll view's size: the width lays the page out again with the reader's
    /// place kept, the height only resizes the overscroll below it.
    func fit(to size: CGSize) {
        guard size.width != frame.width else { return relayout(keeping: nil) }
        let place = self.place
        frame.size.width = size.width
        inset.width = max(24, (size.width - 760) / 2)
        _ = assets.fit(width: columnWidth)
        if let pending, size.width > 0 { return show(pending) }
        // The blocks' views built for the new width.
        for (_, block) in content?.blocks ?? [] { blockViews[ObjectIdentifier(block)]?.rootView = assets.placed(block) }
        relayout(keeping: place)
    }

    private func sizesChanged() {
        let place = self.place
        layout.invalidateLayout(forCharacterRange: NSRange(location: 0, length: textView.textStorage.length), actualCharacterRange: nil)
        relayout(keeping: place)
    }

    // MARK: Drawing

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), let content else { return }
        let dark = traitCollection.userInterfaceStyle == .dark
        if let hero = content.hero, let bottom = content.heroBottom(in: layout) {
            let band = CGRect(x: 0, y: 0, width: bounds.width, height: bottom + origin.y)
            if band.intersects(rect) {
                hero.draw(in: band, dirty: rect, trailing: bounds.width - inset.width, context: context, dark: dark, fill: .pageBackground)
            }
        }
        for (callout, box) in content.calloutBoxes(in: layout, width: columnWidth) {
            let box = box.offsetBy(dx: origin.x, dy: origin.y)
            if box.intersects(rect) { callout.draw(in: box, context: context, dark: dark) }
        }
        for (box, frame, barBottom) in content.tabBoxes(in: layout, width: columnWidth) {
            let frame = frame.offsetBy(dx: origin.x, dy: origin.y)
            if frame.intersects(rect) { box.draw(in: frame, barBottom: barBottom + origin.y, context: context, dark: dark) }
        }
        for (box, frame) in content.codeBoxes(in: layout, width: columnWidth) {
            let frame = frame.offsetBy(dx: origin.x, dy: origin.y)
            if frame.intersects(rect) { box.draw(in: frame, context: context, dark: dark) }
        }
        for (rule, line) in content.ruleRects(in: layout, width: columnWidth) {
            let line = line.offsetBy(dx: origin.x, dy: origin.y)
            if line.intersects(rect) { rule.draw(in: line, context: context) }
        }
        for (mark, box) in content.topicBoxes(in: layout) {
            let box = box.offsetBy(dx: origin.x, dy: origin.y)
            if mark.rect(centeredIn: box, textSize: textSize).intersects(rect) { mark.draw(centeredIn: box, textSize: textSize, context: context) }
        }
    }

    // MARK: Links

    func textView(_ textView: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction? {
        guard case .link(let url) = textItem.content, let reference = PageLink.reference(from: url) else { return defaultAction }
        return UIAction { [weak self] _ in self?.openLink(reference) }
    }
}
#endif

/// The showing tab's content of a group, to go where the group's content was: the page's last
/// paragraph has no newline after it, so content at the end of the page loses its own.
@MainActor private func tabContent(of group: TabGroup, atEnd: Bool) -> NSAttributedString {
    let fragment = NSMutableAttributedString(attributedString: NSAttributedString(tabContent: group))
    if atEnd, fragment.string.hasSuffix("\n") { fragment.deleteCharacters(in: NSRange(location: fragment.length - 1, length: 1)) }
    return fragment
}
