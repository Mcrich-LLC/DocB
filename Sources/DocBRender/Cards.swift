// Link grids as developer.apple.com draws them: swift-docc-render's TopicsLinkCardGrid, two
// columns of cards (three, compact) with a cover picture, the title, the abstract, and a
// link line worded by the page's role. Rows share a height, so the cards line up.

import DocBPage
import SwiftUI

struct CardGridView: View {
    let items: [Links.Item]
    let compact: Bool
    /// The width the grid is laid out in.
    let width: CGFloat
    static let gap: CGFloat = 20
    /// Narrower than this, the cards go one to a row, as the web's do on a phone.
    static let oneColumnBelow: CGFloat = 520

    private var columns: Int { width < Self.oneColumnBelow ? 1 : compact ? 3 : 2 }

    var body: some View {
        Grid(horizontalSpacing: Self.gap, verticalSpacing: Self.gap) {
            ForEach(Array(stride(from: 0, to: items.count, by: columns)), id: \.self) { start in
                GridRow {
                    ForEach(start..<min(start + columns, items.count), id: \.self) { index in
                        CardView(item: items[index], compact: compact)
                    }
                }
            }
        }
    }
}

private struct CardView: View {
    let item: Links.Item
    let compact: Bool
    @Environment(\.openPageLink) private var openPageLink
    @Environment(PageImages.self) private var images

    private static let padding: CGFloat = 13
    private static let radius: CGFloat = 15
    private var bodySize: CGFloat { PlatformFont.preferredFont(forTextStyle: .body).pointSize }

    /// The link line, worded by the role as the web words it.
    private var linkText: String {
        switch item.role {
        case "sampleCode": "View sample code"
        case "article": "Read article"
        case "collection": "View API collection"
        case "symbol": "View symbol"
        case "overview": "Start tutorial"
        default: "Learn more"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cover
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(size: (bodySize * 21 / 17).rounded(), weight: .semibold))
                    .textSelection(.enabled)
                if !compact {
                    Text(item.abstract.plainText)
                        .font(.system(size: bodySize))
                        .textSelection(.enabled)
                    // The link line alone opens the page; the text above is there to be read and
                    // copied. It sits at the bottom, in the same place across a row of cards.
                    Spacer(minLength: 0)
                    Button {
                        if let link = item.link { openPageLink(link) }
                    } label: {
                        HStack(spacing: 4) {
                            Text(linkText)
                            Image(systemName: "chevron.right").font(.system(size: bodySize * 0.7, weight: .semibold))
                        }
                        .font(.system(size: bodySize))
                        .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                    .disabled(item.link == nil)
                    .padding(.top, 4)
                    #if os(macOS)
                    .pointerStyle(.link)
                    #endif
                }
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(Self.padding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: Self.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Self.radius, style: .continuous).strokeBorder(.separator))
        .clipShape(RoundedRectangle(cornerRadius: Self.radius, style: .continuous))
    }

    /// A 16:9 picture filling its box, or the topic's icon where there is none. Its height
    /// follows the width alone; the card's spare height goes to the text column below.
    private var cover: some View {
        Color.clear
            .aspectRatio(16 / 9, contentMode: .fit)
            .fixedSize(horizontal: false, vertical: true)
            .overlay {
                if let image = images.image(for: item.image) {
                    image.swiftUIImage.resizable().scaledToFill()
                } else {
                    Image(systemName: TopicIcon.symbolName(for: item.role ?? "article"))
                        .font(.system(size: 44))
                        .foregroundStyle(.tertiary)
                }
            }
            .clipped()
    }
}
