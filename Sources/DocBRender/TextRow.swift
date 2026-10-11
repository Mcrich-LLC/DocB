// A row of columns of text, as DocC's `@Row` of `@Column`s holds lists of links side by side
// on the web: each column its share of the row, its paragraphs one under the other, links
// going where the page's do. Too narrow for the columns, they stack, as the media rows do.

import DocBPage
import SwiftUI

struct TextRowView: View {
    let row: Row
    /// The width the row is laid out in.
    let width: CGFloat
    @Environment(\.openPageLink) private var openPageLink

    /// Whether every column holds only paragraphs, so the row can be one of these.
    static func isText(_ row: Row) -> Bool {
        row.columns.allSatisfy { column in
            !column.blocks.isEmpty && column.blocks.allSatisfy { if case .paragraph = $0 { true } else { false } }
        }
    }

    var body: some View {
        Group {
            if width < MediaRowView.stackBelow {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(row.columns.indices, id: \.self) { index in column(row.columns[index]) }
                }
            } else {
                let shares = row.columns.reduce(0) { $0 + $1.size }
                let unit = (width - MediaRowView.gap * CGFloat(row.columns.count - 1)) / CGFloat(max(1, shares))
                HStack(alignment: .top, spacing: MediaRowView.gap) {
                    ForEach(row.columns.indices, id: \.self) { index in
                        column(row.columns[index]).frame(width: max(1, unit * CGFloat(row.columns[index].size)), alignment: .leading)
                    }
                }
            }
        }
        // Narrower than the block, stacked, the row keeps to the leading edge, not the middle.
        .frame(maxWidth: .infinity, alignment: .leading)
        // A link's URL is the page's own scheme; it goes to the page's host, not the system.
        .environment(\.openURL, OpenURLAction { url in
            guard let reference = PageLink.reference(from: url) else { return .systemAction }
            openPageLink(reference)
            return .handled
        })
    }

    private func column(_ column: Row.Column) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(column.blocks.indices, id: \.self) { index in
                if case .paragraph(let runs) = column.blocks[index] {
                    paragraph(runs)
                }
            }
        }
    }

    /// A paragraph that is one link, as the lists of links are, is a button with the link
    /// pointer, as a card's link line is, and only the button opens it: its text carries no
    /// link of its own, and is not selectable, so the pointer over it is the hand alone. Any
    /// other paragraph is selectable text with links in it.
    @ViewBuilder private func paragraph(_ runs: [Run]) -> some View {
        let size = PlatformFont.preferredFont(forTextStyle: .body).pointSize
        if runs.count == 1, let link = runs[0].link {
            Button {
                openPageLink(link)
            } label: {
                Text(runs.map { Run($0.text, $0.style) }.attributed(size: size))
                    .foregroundStyle(Color(PlatformColor.link))
                    .lineSpacing(2)
            }
            .buttonStyle(.plain)
            #if os(macOS)
            .pointerStyle(.link)
            #endif
        } else {
            Text(runs.attributed(size: size))
                .lineSpacing(2)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

extension [Run] {
    /// The runs as SwiftUI text: the page's fonts, and links the page's `openURL` handles.
    func attributed(size: CGFloat) -> AttributedString {
        var out = AttributedString()
        for run in self {
            var piece = AttributedString(run.text)
            var font: Font = run.style.contains(.code) ? .system(size: size, design: .monospaced) : .system(size: size)
            if run.style.contains(.strong) { font = font.weight(.semibold) }
            if run.style.contains(.emphasis) { font = font.italic() }
            piece.font = font
            if run.style.contains(.strikethrough) { piece.strikethroughStyle = .single }
            if let link = run.link, let url = PageLink.url(for: link) {
                piece.link = url
                piece.foregroundColor = Color(PlatformColor.link)
            }
            out += piece
        }
        return out
    }
}
