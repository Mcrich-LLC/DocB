// A page as one attributed string for the TextKit document: fonts, colors, paragraph styles,
// and links. Blocks become paragraphs; what is not text yet (images, tables)
// is written as text for now and grows into layout fragments and attachments block by block.

import DocBHighlight
import DocBPage
import Foundation
#if canImport(AppKit)
import AppKit
typealias PlatformFont = NSFont
typealias PlatformColor = NSColor
#else
import UIKit
typealias PlatformFont = UIFont
typealias PlatformColor = UIColor
#endif

extension NSAttributedString {
    @MainActor convenience init(page: Page) {
        var writer = PageTextWriter()
        writer.pageBadge = page.badge
        writer.header(page)
        writer.blocks(page.body, indent: 0)
        writer.flattenFirstBlock()
        self.init(attributedString: writer.finished())
    }

    /// The showing tab's content of a group, as written after its bar, for the document to
    /// put in place of what a group showed before. Ends in a newline like any paragraph.
    @MainActor convenience init(tabContent group: TabGroup) {
        var writer = PageTextWriter()
        writer.pageBadge = group.pageBadge
        writer.tabContent(group)
        self.init(attributedString: writer.out)
    }
}

/// Builds the string paragraph by paragraph. Every paragraph ends in a newline; the last one is
/// trimmed at the end so the document has no empty final line.
@MainActor
private struct PageTextWriter {
    let out = NSMutableAttributedString()
    private let body = PlatformFont.preferredFont(forTextStyle: .body)
    /// The page's own badge, so its topics do not repeat it.
    var pageBadge: Badge?
    private var mono: PlatformFont { .monospacedSystemFont(ofSize: body.pointSize, weight: .regular) }

    func finished() -> NSAttributedString {
        if out.length > 0, out.string.hasSuffix("\n") {
            out.deleteCharacters(in: NSRange(location: out.length - 1, length: 1))
        }
        return out
    }

    // MARK: Header

    /// Where the body starts, so its first block can drop the space it would put before itself.
    private var bodyStart = 0

    /// The header's spacing below is the gap to the body; the body's first block, usually a
    /// heading, does not add its own on top. A callout or a listing keeps its box's top padding,
    /// which its first paragraph carries.
    func flattenFirstBlock() {
        guard bodyStart < out.length else { return }
        let range = (out.string as NSString).paragraphRange(for: NSRange(location: bodyStart, length: 0))
        guard let style = (out.attribute(.paragraphStyle, at: bodyStart, effectiveRange: nil) as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle else { return }
        style.paragraphSpacingBefore = if out.attribute(.callout, at: bodyStart, effectiveRange: nil) != nil { Callout.padding }
            else if out.attribute(.codeBox, at: bodyStart, effectiveRange: nil) != nil { CodeBox.padding }
            else { 0 }
        out.addAttribute(.paragraphStyle, value: style, range: range)
    }

    mutating func header(_ page: Page) {
        defer {
            if let hero = Hero(page: page) { markHero(hero) }
            bodyStart = out.length
        }
        let subheadline = PlatformFont.preferredFont(forTextStyle: .subheadline)
        // The page's ancestors as links, root first, as the web's breadcrumb.
        if !page.parents.isEmpty {
            let crumbs = page.parents.enumerated().flatMap { index, parent in
                (index > 0 ? [Run("  ›  ")] : []) + [Run(parent.title, link: parent.link)]
            }
            paragraph(crumbs, font: subheadline, color: .secondaryLabel, style: style(spacing: 6))
        }
        // The page's badge sits on the eyebrow line, where the web puts it in the breadcrumb.
        if let role = page.roleHeading {
            paragraph([Run(role)], font: subheadline, color: .secondaryLabel, style: style(spacing: 2), badge: page.badge)
        } else if let badge = page.badge {
            paragraph([], font: subheadline, color: .secondaryLabel, style: style(spacing: 2), badge: badge)
        }
        let title = PlatformFont.preferredFont(forTextStyle: .largeTitle)
        paragraph([Run(page.title)], font: .systemFont(ofSize: title.pointSize, weight: .bold), style: style(spacing: 10))
        if !page.abstract.isEmpty {
            paragraph(page.abstract, font: .preferredFont(forTextStyle: .title3), style: style(spacing: 10))
        }
        if !page.platforms.isEmpty {
            // Each platform with its own badge, as the web's availability row.
            let footnote = PlatformFont.preferredFont(forTextStyle: .footnote)
            var runs: [Run] = []
            var badges: [Int: Badge] = [:]
            for (index, platform) in page.platforms.enumerated() {
                if index > 0 { runs.append(Run("  |  ")) }
                var text = platform.name
                if let introduced = platform.introduced {
                    text += " " + introduced + (platform.deprecated.map { $0.isEmpty ? "" : "–" + $0 } ?? "+")
                }
                runs.append(Run(text))
                if let badge = Badge(isBeta: platform.isBeta, isDeprecated: platform.deprecated != nil) { badges[runs.count - 1] = badge }
            }
            paragraph(runs, font: footnote, color: .secondaryLabel, style: style(spacing: 10), badges: badges)
        }
        if let download = page.download {
            attachmentParagraph(BlockAttachment(insets: 0) { _ in DownloadButtonView(download: download) }, style: style(before: 4, spacing: 10), marker: nil)
        }
    }

    /// Marks everything written so far as the hero's, with the hero's padding above and below
    /// it (the view's inset makes up part of the top) and the gap to the content.
    private func markHero(_ hero: Hero) {
        guard out.length > 0 else { return }
        out.addAttribute(.hero, value: hero, range: NSRange(location: 0, length: out.length))
        let string = out.string as NSString
        func adjust(_ range: NSRange, _ change: (NSMutableParagraphStyle) -> Void) {
            out.enumerateAttribute(.paragraphStyle, in: range) { value, range, _ in
                guard let style = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle else { return }
                change(style)
                out.addAttribute(.paragraphStyle, value: style, range: range)
            }
        }
        adjust(string.paragraphRange(for: NSRange(location: 0, length: 0))) { $0.paragraphSpacingBefore = Hero.padding - 24 }
        adjust(string.paragraphRange(for: NSRange(location: out.length - 1, length: 0))) { $0.paragraphSpacing = Hero.padding + Hero.gap }
    }

    // MARK: Blocks

    mutating func blocks(_ blocks: [Block], indent: CGFloat, marker: String? = nil) {
        var marker = marker
        for block in blocks {
            self.block(block, indent: indent, marker: marker)
            marker = nil
        }
    }

    private mutating func block(_ block: Block, indent: CGFloat, marker: String?) {
        // A list or table cannot carry the item marker of the list it starts; it gets a line of its own.
        if let marker, case .list = block { return markerLine(marker, block, indent: indent) }
        if let marker, case .table = block { return markerLine(marker, block, indent: indent) }
        if let marker, case .aside = block { return markerLine(marker, block, indent: indent) }
        switch block {
        case .heading(let level, let text, _):
            // The web's sizes against its 17-point body: 32, 28, 24, 22, 17; semibold, with 1.6em
            // above and 0.8em below.
            let scale: CGFloat = switch level {
            case ...2: 32 / 17
            case 3: 28 / 17
            case 4: 24 / 17
            case 5: 22 / 17
            default: 1
            }
            let size = (body.pointSize * scale).rounded()
            paragraph([Run(text)], font: .systemFont(ofSize: size, weight: .semibold), style: style(indent: indent, before: (body.pointSize * 1.6).rounded(), spacing: (body.pointSize * 0.8).rounded()), marker: marker)
        case .paragraph(let runs):
            paragraph(runs, font: body, style: style(indent: indent, spacing: 8), marker: marker)
        case .small(let runs):
            paragraph(runs, font: .preferredFont(forTextStyle: .footnote), color: .secondaryLabel, style: style(indent: indent, spacing: 8), marker: marker)
        case .code(let code):
            // In its box; above it, the paragraph before leaves 8 and the rest of the gap is here.
            // ponytail: a copy button later.
            let start = out.length
            listing(code, style: style(indent: indent + CodeBox.border + CodeBox.inset, before: CodeBox.padding + max(0, CodeBox.gap - 8), spacing: 10), marker: marker)
            out.box(CodeBox(indent: indent, start: start), key: .codeBox, padding: CodeBox.padding, inset: CodeBox.inset + CodeBox.border, gap: CodeBox.gap, from: start)
        case .declaration(let tokens):
            append(tokens: tokens, style: style(indent: indent, spacing: 10), marker: marker)
        case .list(let list):
            for (index, item) in list.items.enumerated() {
                blocks(item, indent: indent + 20, marker: list.isOrdered ? "\(list.start + index)." : "•")
            }
        case .terms(let terms):
            for term in terms {
                paragraph(term.term, font: body, weight: .semibold, style: style(indent: indent, spacing: 2), marker: marker)
                blocks(term.definition, indent: indent + 20)
            }
        case .table(let table):
            // A grid of its own, with the web's 1em above and below; the paragraph before leaves 8.
            attachmentParagraph(BlockAttachment(insets: indent) { width in TableView(table: table, width: width) }, style: style(indent: indent, before: Self.figureMargin - 8, spacing: Self.figureMargin), marker: marker)
        case .aside(let aside):
            let callout = Callout(kind: aside.kind, indent: indent)
            let start = out.length
            let inner = indent + Callout.border + Callout.padding
            // Above the box: the paragraph before it leaves 8, and the rest of the gap is here.
            paragraph([Run(aside.name)], font: body, weight: .semibold, color: callout.labelColor, style: style(indent: inner, before: Callout.padding + max(0, Callout.gap - 8), spacing: 4))
            blocks(aside.blocks, indent: inner)
            mark(callout, from: start)
        case .image(let media):
            // At its own size or the column's, as the web shows it; the document fills it in.
            // The web's figure margin, 1.6em, above and below; the paragraph before leaves 8 of it.
            attachmentParagraph(BlockAttachment(insets: indent) { _ in ImageBlockView(media: media) }, style: style(indent: indent, before: Self.figureMargin - 8, spacing: media.caption.isEmpty ? Self.figureMargin : 4), marker: marker)
            caption(media, indent: indent)
        case .video(let media, let poster):
            // The poster with a play button, and the player in its place once playing; as a figure.
            attachmentParagraph(BlockAttachment(insets: indent) { _ in VideoBlockView(media: media, poster: poster) }, style: style(indent: indent, before: Self.figureMargin - 8, spacing: media.caption.isEmpty ? Self.figureMargin : 4), marker: marker)
            caption(media, indent: indent)
        case .links(let links) where links.style != .list:
            // A grid of cards, hosted as a view of its own, with the web's figure margins.
            attachmentParagraph(BlockAttachment(insets: indent) { width in CardGridView(items: links.items, compact: links.style == .compactGrid, width: width) }, style: style(indent: indent, before: Self.figureMargin - 8, spacing: Self.figureMargin), marker: marker)
            // The web closes a grid with a rule before what follows.
            rule(indent: indent, before: 0)
        case .links(let links):
            // As the web's topic lists: the page's kind as an icon in the gutter, centered on
            // the title on one line and the abstract on the next; the document draws it.
            for item in links.items {
                // A badge the whole page already wears is not repeated on its topics.
                let badge = Badge(isBeta: item.isBeta && pageBadge != .beta, isDeprecated: item.isDeprecated && pageBadge != .deprecated)
                let inner = indent + TopicMark.width
                let start = out.length
                let titleStyle = style(indent: inner, spacing: item.abstract.isEmpty ? Self.topicSpacing : 6)
                if item.fragments.isEmpty {
                    paragraph([Run(item.title, link: item.link)], font: body, style: titleStyle, badge: badge)
                } else {
                    decoratedTitle(item, style: titleStyle, badge: badge)
                }
                if !item.abstract.isEmpty {
                    paragraph(item.abstract, font: body, style: style(indent: inner, spacing: Self.topicSpacing))
                }
                out.addAttribute(.topicMark, value: TopicMark(role: item.role ?? "article", indent: indent, start: start), range: NSRange(location: start, length: out.length - start))
            }
        case .tabs(let tabs):
            // The bar as a block and the showing tab's content after it, boxed together.
            let group = TabGroup(tabs: tabs, indent: indent, pageBadge: pageBadge)
            let start = out.length
            let inner = indent + TabBox.border + TabBox.padding
            attachmentParagraph(BlockAttachment(insets: inner + TabBox.border + TabBox.padding) { _ in TabBarView(group: group) }, style: style(indent: inner, before: TabBox.padding + max(0, TabBox.gap - 8), spacing: 12), marker: marker)
            tabContent(group)
            out.box(TabBox(group: group), key: .tabBox, padding: TabBox.padding, gap: TabBox.gap, from: start)
        case .row(let row) where MediaRowView.isMedia(row):
            // Pictures and videos side by side, as a block with the figure margins.
            attachmentParagraph(BlockAttachment(insets: indent) { width in MediaRowView(row: row, width: width) }, style: style(indent: indent, before: Self.figureMargin - 8, spacing: Self.figureMargin), marker: marker)
        case .row(let row) where TextRowView.isText(row):
            // Columns of paragraphs side by side, as the web's lists of links; the paragraph before leaves 8.
            attachmentParagraph(BlockAttachment(insets: indent) { width in TextRowView(row: row, width: width) }, style: style(indent: indent, before: 4, spacing: 12), marker: marker)
        case .row(let row):
            // ponytail: columns mixing text and media read one after another.
            for column in row.columns { blocks(column.blocks, indent: indent) }
        case .divider:
            rule(indent: indent, before: Self.figureMargin - 8)
        case .unsupported(let name):
            paragraph([Run("[unsupported: \(name)]")], font: body, color: .secondaryLabel, style: style(indent: indent, spacing: 8), marker: marker)
        }
    }

    private static let figureMargin: CGFloat = 20
    /// Between topics in a list: the web's 1.6em less what a line's own leading gives.
    private static let topicSpacing: CGFloat = 22

    /// A rule: an empty paragraph as thin as its line, with the line drawn through it by the
    /// document; what follows adds its own space before itself.
    private func rule(indent: CGFloat, before: CGFloat) {
        let style = style(indent: indent, before: before, spacing: 8).mutableCopy() as! NSMutableParagraphStyle
        style.lineHeightMultiple = 1
        out.append(NSAttributedString(string: "\n", attributes: [.font: PlatformFont.systemFont(ofSize: Rule.thickness), .paragraphStyle: style, .rule: Rule(indent: indent)]))
    }

    /// The caption under a picture, centered like the picture.
    private func caption(_ media: Media, indent: CGFloat) {
        guard !media.caption.isEmpty else { return }
        let style = style(indent: indent, spacing: Self.figureMargin).mutableCopy() as! NSMutableParagraphStyle
        style.alignment = .center
        paragraph(media.caption, font: .preferredFont(forTextStyle: .footnote), color: .secondaryLabel, style: style)
    }

    /// A paragraph that is one attachment, with the marker hanging before it as for text. The
    /// line is exactly the attachment: a line height multiple would add a share of the
    /// attachment's height as empty space above it.
    private func attachmentParagraph(_ attachment: NSTextAttachment, style: NSParagraphStyle, marker: String?) {
        let style = (marker.map { hanging(style, marker: $0) } ?? style).mutableCopy() as! NSMutableParagraphStyle
        style.lineHeightMultiple = 1
        if let marker { out.append(self.marker(marker, font: body, style: style)) }
        let text = NSMutableAttributedString(attachment: attachment)
        text.addAttributes([.font: body, .paragraphStyle: style], range: NSRange(location: 0, length: text.length))
        out.append(text)
        out.append(NSAttributedString(string: "\n", attributes: [.font: body, .paragraphStyle: style]))
    }

    /// Marks the aside written since `start` with its box: the text keeps clear of the box's
    /// trailing edge, and the last paragraph carries the bottom padding and the gap below.
    private func mark(_ callout: Callout, from start: Int) {
        out.box(callout, key: .callout, padding: Callout.padding, gap: Callout.gap, from: start)
    }

    /// The showing tab's content, at the box's inner indent and marked with its group; a tab
    /// with nothing in it is still a paragraph, so there is a stretch of text to swap. A tab
    /// that is one code listing shows it bare: the group's box is the listing's.
    mutating func tabContent(_ group: TabGroup) {
        let start = out.length
        let inner = group.indent + TabBox.border + TabBox.padding
        let blocks = group.tabs.indices.contains(group.selected) ? group.tabs[group.selected].blocks : []
        if blocks.isEmpty {
            paragraph([], font: body, style: style(indent: inner, spacing: 0))
        } else if blocks.count == 1, case .code(let code) = blocks[0] {
            listing(code, style: style(indent: inner, spacing: 10), marker: nil)
        } else {
            self.blocks(blocks, indent: inner)
        }
        out.addAttribute(.tabContent, value: group, range: NSRange(location: start, length: out.length - start))
        out.box(TabBox(group: group), key: .tabBox, padding: TabBox.padding, gap: TabBox.gap, from: start)
    }

    private mutating func markerLine(_ marker: String, _ block: Block, indent: CGFloat) {
        paragraph([], font: body, style: style(indent: indent, spacing: 0), marker: marker)
        self.block(block, indent: indent, marker: nil)
    }

    // MARK: Paragraphs

    private func style(indent: CGFloat = 0, before: CGFloat = 0, spacing: CGFloat) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = 1.15
        style.paragraphSpacingBefore = before
        style.paragraphSpacing = spacing
        style.firstLineHeadIndent = indent
        style.headIndent = indent
        return style
    }

    /// One paragraph of runs. A marker ("•", "3.") hangs in the indent before the first line.
    /// `badges` follow the runs they are keyed by; `badge` follows the whole paragraph.
    private func paragraph(_ runs: [Run], font: PlatformFont, weight: PlatformFont.Weight = .regular, color: PlatformColor = .label, style: NSParagraphStyle, marker: String? = nil, badge: Badge? = nil, badges: [Int: Badge] = [:]) {
        let style = marker.map { hanging(style, marker: $0) } ?? style
        if let marker { out.append(self.marker(marker, font: font, style: style)) }
        func append(badge: Badge) {
            out.append(NSAttributedString(string: " ", attributes: [.font: font, .paragraphStyle: style]))
            out.append(NSAttributedString(attachment: badge.attachment(beside: font)))
        }
        for (index, run) in runs.enumerated() {
            var attributes: [NSAttributedString.Key: Any] = [.paragraphStyle: style, .foregroundColor: color]
            var runFont = weight == .regular ? font : .systemFont(ofSize: font.pointSize, weight: weight)
            if run.style.contains(.code) { runFont = .monospacedSystemFont(ofSize: font.pointSize, weight: weight) }
            if run.style.contains(.strong) { runFont = runFont.withWeight(.semibold) }
            if run.style.contains(.emphasis) { runFont = runFont.italic }
            if run.style.contains(.strikethrough) { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
            if run.style.contains(.superscript) || run.style.contains(.subscript) {
                runFont = runFont.withSize(runFont.pointSize * 0.75)
                attributes[.baselineOffset] = run.style.contains(.superscript) ? runFont.pointSize * 0.45 : -runFont.pointSize * 0.2
            }
            if let link = run.link, let url = PageLink.url(for: link) {
                attributes[.link] = url
                attributes[.foregroundColor] = PlatformColor.link
            }
            attributes[.font] = runFont
            out.append(NSAttributedString(string: run.text, attributes: attributes))
            if let badge = badges[index] { append(badge: badge) }
        }
        if let badge { append(badge: badge) }
        out.append(NSAttributedString(string: "\n", attributes: [.font: font, .paragraphStyle: style]))
    }

    /// A code listing, highlighted as on the web, as one paragraph with line separators, not
    /// one per line: TextKit keeps every layout fragment of a document only up to 2000 of them,
    /// and a long listing must not eat that.
    private func listing(_ code: Code, style: NSParagraphStyle, marker: String?) {
        let style = marker.map { hanging(style, marker: $0) } ?? style
        if let marker { out.append(self.marker(marker, font: mono, style: style)) }
        for token in Highlighter.tokens(for: code.lines.joined(separator: "\n"), language: code.language) {
            var font = mono
            if SyntaxTheme.isBold(token.scopes) { font = font.withWeight(.semibold) }
            if SyntaxTheme.isItalic(token.scopes) { font = font.italic }
            let color = SyntaxTheme.color(for: token.scopes) ?? .label
            let text = token.text.replacingOccurrences(of: "\n", with: "\u{2028}")
            out.append(NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: style]))
        }
        out.append(NSAttributedString(string: "\n", attributes: [.font: mono, .paragraphStyle: style]))
    }

    /// A symbol's title as the web's decorated title: its declaration tokens in monospace, the
    /// name in the link color and the rest secondary, all one link; struck through when deprecated.
    private func decoratedTitle(_ item: Links.Item, style: NSParagraphStyle, badge: Badge?) {
        for token in item.fragments {
            let named = token.kind == "identifier" || token.kind == "externalParam"
            var attributes: [NSAttributedString.Key: Any] = [.font: mono, .paragraphStyle: style, .foregroundColor: named ? PlatformColor.link : PlatformColor.secondaryLabel]
            if let link = item.link, let url = PageLink.url(for: link) { attributes[.link] = url }
            if item.isDeprecated { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
            out.append(NSAttributedString(string: token.text, attributes: attributes))
        }
        if let badge {
            out.append(NSAttributedString(string: " ", attributes: [.font: body, .paragraphStyle: style]))
            out.append(NSAttributedString(attachment: badge.attachment(beside: body)))
        }
        out.append(NSAttributedString(string: "\n", attributes: [.font: body, .paragraphStyle: style]))
    }

    /// The marker and the tab to the paragraph's indent.
    private func marker(_ marker: String, font: PlatformFont, style: NSParagraphStyle) -> NSAttributedString {
        NSAttributedString(string: marker + "\t", attributes: [.font: font, .foregroundColor: PlatformColor.secondaryLabel, .paragraphStyle: style])
    }

    private func hanging(_ style: NSParagraphStyle, marker: String) -> NSParagraphStyle {
        let hanging = style.mutableCopy() as! NSMutableParagraphStyle
        hanging.firstLineHeadIndent = max(0, style.headIndent - 20)
        hanging.tabStops = [NSTextTab(textAlignment: .left, location: style.headIndent)]
        return hanging
    }

    private func append(tokens: [Token], style: NSParagraphStyle, marker: String?) {
        let style = marker.map { hanging(style, marker: $0) } ?? style
        if let marker { out.append(self.marker(marker, font: mono, style: style)) }
        for token in tokens {
            var attributes: [NSAttributedString.Key: Any] = [.font: mono, .paragraphStyle: style, .foregroundColor: PlatformColor.label]
            switch token.kind {
            case "keyword", "attribute": attributes[.foregroundColor] = PlatformColor.keyword
            case "externalParam", "label": attributes[.foregroundColor] = PlatformColor.secondaryLabel
            default: break
            }
            if let link = token.link, let url = PageLink.url(for: link) {
                attributes[.link] = url
                attributes[.foregroundColor] = PlatformColor.link
            }
            out.append(NSAttributedString(string: token.text, attributes: attributes))
        }
        out.append(NSAttributedString(string: "\n", attributes: [.font: mono, .paragraphStyle: style]))
    }
}

private extension NSMutableAttributedString {
    /// Marks what was written since `start` with a box: the text keeps clear of the box's
    /// trailing edge by `inset` (the padding, unless said otherwise), and the last paragraph
    /// carries the bottom padding and the gap below.
    func box(_ value: Any, key: NSAttributedString.Key, padding: CGFloat, inset: CGFloat? = nil, gap: CGFloat, from start: Int) {
        let range = NSRange(location: start, length: length - start)
        guard range.length > 0 else { return }
        addAttribute(key, value: value, range: range)
        // Paragraph by paragraph: alike paragraphs share one attribute run, and the last one's
        // spacing must not reach the others.
        let last = (string as NSString).paragraphRange(for: NSRange(location: length - 1, length: 0))
        var index = range.location
        while index < NSMaxRange(range) {
            let paragraph = (string as NSString).paragraphRange(for: NSRange(location: index, length: 0))
            index = NSMaxRange(paragraph)
            enumerateAttribute(.paragraphStyle, in: paragraph) { value, styleRange, _ in
                guard let style = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle else { return }
                style.tailIndent = -(inset ?? padding)
                if paragraph == last { style.paragraphSpacing = padding + gap }
                addAttribute(.paragraphStyle, value: style, range: styleRange)
            }
        }
    }
}

extension [Block] {
    /// The text of the blocks, for the places that can only hold a line.
    var plainText: String {
        map { block -> String in
            switch block {
            case .paragraph(let runs): runs.plainText
            case .heading(_, let text, _): text
            case .code(let code): code.lines.joined(separator: " ")
            case .declaration(let tokens): tokens.plainText
            case .list(let list): list.items.map(\.plainText).joined(separator: " ")
            case .terms(let terms): terms.map { $0.term.plainText + " " + $0.definition.plainText }.joined(separator: " ")
            case .table(let table): table.rows.map { $0.map(\.blocks.plainText).joined(separator: " ") }.joined(separator: " ")
            case .aside(let aside): aside.blocks.plainText
            case .image(let media), .video(let media, _): media.alt ?? ""
            case .links(let links): links.items.map(\.title).joined(separator: " ")
            case .tabs(let tabs): tabs.map(\.blocks.plainText).joined(separator: " ")
            case .row(let row): row.columns.map(\.blocks.plainText).joined(separator: " ")
            case .small(let runs): runs.plainText
            case .divider, .unsupported: ""
            }
        }.joined(separator: " ")
    }
}

extension PlatformColor {
    #if canImport(AppKit)
    static var label: NSColor { .labelColor }
    static var secondaryLabel: NSColor { .secondaryLabelColor }
    static var link: NSColor { .linkColor }
    #endif
    static var keyword: PlatformColor { .systemPurple }
}

extension PlatformFont {
    var italic: PlatformFont {
        #if canImport(AppKit)
        NSFontManager.shared.convert(self, toHaveTrait: .italicFontMask)
        #else
        fontDescriptor.withSymbolicTraits(fontDescriptor.symbolicTraits.union(.traitItalic)).map { PlatformFont(descriptor: $0, size: pointSize) } ?? self
        #endif
    }

    func withWeight(_ weight: Weight) -> PlatformFont {
        #if canImport(AppKit)
        let isMono = fontDescriptor.symbolicTraits.contains(.monoSpace)
        #else
        let isMono = fontDescriptor.symbolicTraits.contains(.traitMonoSpace)
        #endif
        return isMono ? .monospacedSystemFont(ofSize: pointSize, weight: weight) : .systemFont(ofSize: pointSize, weight: weight)
    }
}

/// How a link is carried inside the attributed string: a URL in a private scheme wrapping the
/// page model's reference string, so `doc://` identifiers with characters URL cannot represent
/// survive the trip through TextKit and back.
enum PageLink {
    static let scheme = "docb-link"

    static func url(for reference: String) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "ref"
        components.queryItems = [URLQueryItem(name: "r", value: reference)]
        return components.url
    }

    static func reference(from url: URL) -> String? {
        guard url.scheme == scheme, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        return components.queryItems?.first { $0.name == "r" }?.value
    }
}

/// The line of text at the top of the viewport and how far the viewport is into it, taken
/// before a width change and read back after it, in text container coordinates.
struct ViewportAnchor {
    var location: any NSTextLocation
    var offset: CGFloat

    init?(_ layout: NSTextLayoutManager, viewportTop y: CGFloat) {
        guard let fragment = layout.textLayoutFragment(for: CGPoint(x: 0, y: y)) else { return nil }
        let localY = y - fragment.layoutFragmentFrame.minY
        guard let line = fragment.textLineFragments.first(where: { $0.typographicBounds.maxY > localY }) ?? fragment.textLineFragments.last,
              let location = layout.location(fragment.rangeInElement.location, offsetBy: line.characterRange.location) else { return nil }
        self.location = location
        offset = localY - line.typographicBounds.minY
    }

    /// Where the viewport top belongs after relayout.
    func viewportTop(in layout: NSTextLayoutManager) -> CGFloat? {
        guard let fragment = layout.textLayoutFragment(for: location) else { return nil }
        let index = layout.offset(from: fragment.rangeInElement.location, to: location)
        guard let line = fragment.textLineFragments.first(where: { NSMaxRange($0.characterRange) > index }) ?? fragment.textLineFragments.last else { return nil }
        return fragment.layoutFragmentFrame.minY + line.typographicBounds.minY + offset
    }
}
