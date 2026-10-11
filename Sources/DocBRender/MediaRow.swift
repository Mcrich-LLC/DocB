// A row of columns of pictures and videos, as DocC's `@Row` of `@Column`s holds them side by
// side: each column as wide as its share of the row, its media centered with captions under
// them. Too narrow for the columns, as on a phone, they stack, as the card grid's do.

import DocBPage
import SwiftUI

struct MediaRowView: View {
    let row: Row
    /// The width the row is laid out in.
    let width: CGFloat
    static let gap: CGFloat = 20
    /// Narrower than this, the columns stack.
    static let stackBelow: CGFloat = CardGridView.oneColumnBelow

    /// Whether every column holds only pictures and videos, so the row can be one of these.
    static func isMedia(_ row: Row) -> Bool {
        row.columns.allSatisfy { column in
            !column.blocks.isEmpty && column.blocks.allSatisfy {
                switch $0 {
                case .image, .video: true
                default: false
                }
            }
        }
    }

    var body: some View {
        if width < Self.stackBelow {
            VStack(spacing: Self.gap) {
                ForEach(row.columns.indices, id: \.self) { index in column(row.columns[index]) }
            }
        } else {
            let shares = row.columns.reduce(0) { $0 + $1.size }
            let unit = (width - Self.gap * CGFloat(row.columns.count - 1)) / CGFloat(max(1, shares))
            HStack(alignment: .top, spacing: Self.gap) {
                ForEach(row.columns.indices, id: \.self) { index in
                    column(row.columns[index]).frame(width: max(1, unit * CGFloat(row.columns[index].size)))
                }
            }
        }
    }

    private func column(_ column: Row.Column) -> some View {
        VStack(spacing: 8) {
            ForEach(column.blocks.indices, id: \.self) { index in
                switch column.blocks[index] {
                case .image(let media):
                    ImageBlockView(media: media)
                    caption(media)
                case .video(let media, let poster):
                    VideoBlockView(media: media, poster: poster)
                    caption(media)
                default:
                    EmptyView()
                }
            }
        }
    }

    @ViewBuilder private func caption(_ media: Media) -> some View {
        if !media.caption.isEmpty {
            Text(media.caption.plainText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
        }
    }
}
