// A page as GitHub-flavored Markdown: the page model walked block by block, with the parts
// Markdown cannot hold as structure (table cell blocks, spans, tabs) flattened as plainly as
// possible. No wrapping and no terminal styling: those are the CLI's business.

import DocBPage
import Foundation

public enum Markdown {
    public static func render(_ page: Page) -> String {
        var parts: [String] = ["# " + escape(page.title)]
        var role: [String] = []
        if let heading = page.roleHeading { role.append(heading) }
        if page.isBeta { role.append("Beta") }
        if page.isDeprecated { role.append("Deprecated") }
        if !role.isEmpty { parts.append("*" + role.map { escape($0) }.joined(separator: " · ") + "*") }
        if !page.abstract.isEmpty { parts.append(inline(page.abstract)) }
        if !page.platforms.isEmpty {
            parts.append("**Availability:** " + page.platforms.map { platform in
                var text = platform.name
                if let introduced = platform.introduced {
                    text += " " + introduced
                    if let deprecated = platform.deprecated, !deprecated.isEmpty { text += "–" + deprecated } else { text += "+" }
                }
                if platform.deprecated == "" { text += " (Deprecated)" }
                if platform.isBeta { text += " (Beta)" }
                return escape(text)
            }.joined(separator: " · "))
        }
        parts.append(contentsOf: blocks(page.body, language: page.language, pageBadge: page.isDeprecated ? "Deprecated" : page.isBeta ? "Beta" : nil))
        return parts.joined(separator: "\n\n") + "\n"
    }

    // MARK: Blocks

    /// Each block as its own chunk; the caller joins them with blank lines. `pageBadge` is the
    /// label the whole page wears, which its topics do not repeat.
    static func blocks(_ blocks: [Block], language: String?, pageBadge: String? = nil) -> [String] {
        blocks.map { render($0, language: language, pageBadge: pageBadge) }
    }

    static func render(_ block: Block, language: String?, pageBadge: String? = nil) -> String {
        switch block {
        case .heading(let level, let text, _):
            return String(repeating: "#", count: max(1, min(6, level))) + " " + escape(text)
        case .paragraph(let runs):
            return inline(runs)
        case .small(let runs):
            return inline(runs)
        case .code(let code):
            return fenced(code.lines, language: code.language)
        case .declaration(let tokens):
            return fenced([tokens.plainText], language: language == "occ" ? "objc" : language)
        case .list(let list):
            return list.items.enumerated().map { index, item in
                let marker = list.isOrdered ? "\(list.start + index). " : "- "
                return prefixed(item.isEmpty ? [""] : self.blocks(item, language: language), first: marker, rest: String(repeating: " ", count: marker.count))
            }.joined(separator: list.items.contains { $0.count > 1 } ? "\n\n" : "\n")
        case .terms(let terms):
            return terms.map { term in
                let name = "**" + inline(term.term) + "**"
                if term.definition.count == 1, case .paragraph(let runs) = term.definition[0] {
                    return "- " + name + ": " + inline(runs)
                }
                return prefixed([name] + self.blocks(term.definition, language: language), first: "- ", rest: "  ")
            }.joined(separator: terms.contains { $0.definition.count > 1 } ? "\n\n" : "\n")
        case .table(let table):
            return self.table(table, language: language)
        case .aside(let aside):
            // A GitHub callout; a name that is not the kind's own label (say "Precondition")
            // has no place in the syntax and heads the content in bold instead.
            let callout = switch aside.kind {
            case .note, .experiment: "NOTE"
            case .tip: "TIP"
            case .important: "IMPORTANT"
            case .warning: "WARNING"
            case .deprecated: "CAUTION"
            }
            let name = aside.name == aside.kind.label ? [] : ["**" + escape(aside.name) + "**"]
            return "> [!" + callout + "]\n" + prefixed(name + self.blocks(aside.blocks, language: language), first: "> ", rest: "> ")
        case .image(let media):
            let image = "![" + escape(media.alt ?? "") + "](" + (media.defaultVariant?.url ?? "") + ")"
            return media.caption.isEmpty ? image : image + "\n\n*" + inline(media.caption) + "*"
        case .video(let media, _):
            let video = "[Video" + (media.alt.map { ": " + escape($0) } ?? "") + "](" + (media.defaultVariant?.url ?? "") + ")"
            return media.caption.isEmpty ? video : video + "\n\n*" + inline(media.caption) + "*"
        case .links(let links):
            return links.items.map { item in
                var line = "- " + (item.link.map { "[" + escape(item.title) + "](" + $0 + ")" } ?? escape(item.title))
                // Deprecated wins over Beta, and a badge the page wears is not repeated on its topics.
                if item.isDeprecated, pageBadge != "Deprecated" { line += " *Deprecated*" } else if item.isBeta, !item.isDeprecated, pageBadge != "Beta" { line += " *Beta*" }
                if !item.abstract.isEmpty { line += ": " + inline(item.abstract) }
                return line
            }.joined(separator: "\n")
        case .tabs(let tabs):
            return tabs.map { tab in (["**" + escape(tab.title) + "**"] + self.blocks(tab.blocks, language: language)).joined(separator: "\n\n") }
                .joined(separator: "\n\n")
        case .row(let row):
            // Columns one after another; a flat format has no side by side.
            return row.columns.map { self.blocks($0.blocks, language: language).joined(separator: "\n\n") }.joined(separator: "\n\n")
        case .divider:
            return "---"
        case .unsupported(let name):
            return "<!-- unsupported: \(name) -->"
        }
    }

    /// Chunks joined by blank lines, every line prefixed: `first` on the first, `rest` on the others.
    private static func prefixed(_ chunks: [String], first: String, rest: String) -> String {
        chunks.joined(separator: "\n\n").components(separatedBy: "\n").enumerated().map { index, line in
            let prefix = index == 0 ? first : rest
            return line.isEmpty ? prefix.trimmingCharacters(in: .whitespaces) : prefix + line
        }.joined(separator: "\n")
    }

    private static func fenced(_ lines: [String], language: String?) -> String {
        let longest = lines.map { $0.longestRun(of: "`") }.max() ?? 0
        let fence = String(repeating: "`", count: max(3, longest + 1))
        return fence + (language ?? "") + "\n" + lines.joined(separator: "\n") + "\n" + fence
    }

    // MARK: Tables

    private static func table(_ table: Table, language: String?) -> String {
        // Spans have no Markdown form: a spanning cell keeps its text and the cells it covers are empty.
        var grid: [Int: [Int: String]] = [:]
        for (rowIndex, row) in table.rows.enumerated() {
            var column = 0
            for cell in row {
                while grid[rowIndex]?[column] != nil { column += 1 }
                for r in 0..<max(1, cell.rowSpan) {
                    for c in 0..<max(1, cell.columnSpan) {
                        grid[rowIndex + r, default: [:]][column + c] = r == 0 && c == 0 ? cellText(cell.blocks, language: language) : ""
                    }
                }
                column += max(1, cell.columnSpan)
            }
        }
        let rowCount = (grid.keys.max() ?? -1) + 1
        let columnCount = grid.values.compactMap { $0.keys.max() }.max().map { $0 + 1 } ?? 0
        guard rowCount > 0, columnCount > 0 else { return "" }
        var rows = (0..<rowCount).map { r in (0..<columnCount).map { c in grid[r]?[c] ?? "" } }
        // GitHub needs a header row; a table without one gets an empty one.
        let hasHeader = table.header == .row || table.header == .both
        if !hasHeader { rows.insert(Array(repeating: "", count: columnCount), at: 0) }
        let alignments = (0..<columnCount).map { c -> String in
            switch c < table.alignments.count ? table.alignments[c] : .unset {
            case .left: ":--"
            case .center: ":-:"
            case .right: "--:"
            case .unset: "---"
            }
        }
        var lines = ["| " + rows[0].joined(separator: " | ") + " |", "| " + alignments.joined(separator: " | ") + " |"]
        lines += rows.dropFirst().map { "| " + $0.joined(separator: " | ") + " |" }
        return lines.joined(separator: "\n")
    }

    /// A cell's blocks on one line: paragraphs joined by breaks, lists as their items, code as spans.
    private static func cellText(_ blocks: [Block], language: String?) -> String {
        blocks.map { block -> String in
            switch block {
            case .paragraph(let runs), .small(let runs): inline(runs, inCell: true)
            case .heading(_, let text, _): "**" + escape(text, inCell: true) + "**"
            case .code(let code): code.lines.map { codeSpan($0, inCell: true) }.joined(separator: "<br>")
            case .declaration(let tokens): codeSpan(tokens.plainText, inCell: true)
            case .list(let list): list.items.map { cellText($0, language: language) }.joined(separator: "<br>")
            case .terms(let terms): terms.map { "**" + inline($0.term, inCell: true) + "**: " + cellText($0.definition, language: language) }.joined(separator: "<br>")
            case .aside(let aside): "**" + escape(aside.name, inCell: true) + "** " + cellText(aside.blocks, language: language)
            case .links(let links): links.items.map { item in item.link.map { "[" + escape(item.title, inCell: true) + "](" + $0 + ")" } ?? escape(item.title, inCell: true) }.joined(separator: "<br>")
            case .image(let media), .video(let media, _): escape(media.alt ?? "", inCell: true)
            case .tabs(let tabs): tabs.map { cellText($0.blocks, language: language) }.joined(separator: "<br>")
            case .row(let row): row.columns.map { cellText($0.blocks, language: language) }.joined(separator: "<br>")
            case .table, .divider, .unsupported: ""
            }
        }.filter { !$0.isEmpty }.joined(separator: "<br>")
    }

    // MARK: Inline

    static func inline(_ runs: [Run], inCell: Bool = false) -> String {
        var out = ""
        for run in runs {
            var text = run.style.contains(.code) ? codeSpan(run.text, inCell: inCell) : escape(run.text, inCell: inCell)
            if run.style.contains(.strong) { text = "**" + text + "**" }
            if run.style.contains(.emphasis) { text = "*" + text + "*" }
            if run.style.contains(.strikethrough) { text = "~~" + text + "~~" }
            if run.style.contains(.subscript) { text = "<sub>" + text + "</sub>" }
            if run.style.contains(.superscript) { text = "<sup>" + text + "</sup>" }
            if let link = run.link { text = "[" + text + "](" + link + ")" }
            out += text
        }
        // What would start a block at the head of a line must not. A backslash only escapes
        // punctuation, so an ordered marker is broken at its delimiter.
        if let first = out.first, "#>-+".contains(first) {
            out = "\\" + out
        } else if let delimiter = out.orderedMarkerDelimiter {
            out.insert("\\", at: delimiter)
        }
        return out
    }

    private static func codeSpan(_ text: String, inCell: Bool = false) -> String {
        let text = inCell ? text.replacingOccurrences(of: "|", with: "\\|") : text
        let fence = String(repeating: "`", count: text.longestRun(of: "`") + 1)
        let padded = text.hasPrefix("`") || text.hasSuffix("`") || (text.hasPrefix(" ") && text.hasSuffix(" ") && !text.allSatisfy { $0 == " " }) ? " " + text + " " : text
        return fence + padded + fence
    }

    /// Plain text with everything that would read as markup escaped.
    static func escape(_ text: String, inCell: Bool = false) -> String {
        var out = ""
        for character in text {
            switch character {
            case "\\", "`", "*", "_", "[", "]", "<", ">": out.append("\\"); out.append(character)
            case "|" where inCell: out.append("\\|")
            case "\n": out.append(inCell ? "<br>" : " ")
            default: out.append(character)
            }
        }
        return out
    }
}

private extension String {
    func longestRun(of character: Character) -> Int {
        var longest = 0
        var run = 0
        for c in self {
            run = c == character ? run + 1 : 0
            longest = max(longest, run)
        }
        return longest
    }

    /// The "." or ")" of a "1." or "12)" at the start, which would begin an ordered list.
    var orderedMarkerDelimiter: String.Index? {
        let digits = prefix { $0.isNumber }
        guard !digits.isEmpty, digits.count < 10, digits.endIndex < endIndex, ".)".contains(self[digits.endIndex]) else { return nil }
        return digits.endIndex
    }
}
