// A table as the web draws it: a grid of cells with 1-point lines between them and none
// around, headers semibold, 10 points of padding. Hosted as a block of its own in the page.
// Column widths are the grid's to decide from the cells' text.

import DocBPage
import SwiftUI

struct TableView: View {
    let table: DocBPage.Table
    let width: CGFloat

    static let padding: CGFloat = 10

    private var bodySize: CGFloat { PlatformFont.preferredFont(forTextStyle: .body).pointSize }

    /// Cells laid out into positions: a cell spanning columns takes them in its row, and a cell
    /// spanning rows leaves empty cells under it, since the grid cannot merge downward.
    /// ponytail: a row span shows as one cell with empties below, not one tall cell.
    var placed: [[Placed]] {
        var rows: [[Placed]] = []
        var covered: Set<Int> = []
        for (rowIndex, row) in table.rows.enumerated() {
            var out: [Placed] = []
            var column = 0
            var cells = row.makeIterator()
            var next = cells.next()
            while next != nil || covered.contains(rowIndex << 16 | column) {
                if covered.contains(rowIndex << 16 | column) {
                    out.append(Placed(cell: nil, column: column, span: 1, isHeader: isHeader(row: rowIndex, column: column)))
                    column += 1
                    continue
                }
                guard let cell = next else { break }
                for r in 1..<max(1, cell.rowSpan) {
                    for c in 0..<max(1, cell.columnSpan) { covered.insert((rowIndex + r) << 16 | (column + c)) }
                }
                out.append(Placed(cell: cell, column: column, span: max(1, cell.columnSpan), isHeader: isHeader(row: rowIndex, column: column)))
                column += max(1, cell.columnSpan)
                next = cells.next()
            }
            rows.append(out)
        }
        return rows
    }

    private func isHeader(row: Int, column: Int) -> Bool {
        switch table.header {
        case .row: row == 0
        case .column: column == 0
        case .both: row == 0 || column == 0
        case .none: false
        }
    }

    var body: some View {
        let rows = placed
        let columns = rows.map { $0.reduce(0) { $0 + $1.span } }.max() ?? 0
        Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
            ForEach(rows.indices, id: \.self) { rowIndex in
                GridRow {
                    ForEach(rows[rowIndex].indices, id: \.self) { index in
                        let placed = rows[rowIndex][index]
                        cell(placed, last: (row: rowIndex == rows.count - 1, column: placed.column + placed.span == columns))
                            .gridCellColumns(placed.span)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cell(_ placed: Placed, last: (row: Bool, column: Bool)) -> some View {
        let line = Color(PlatformColor.dynamic(light: PlatformColor(hex: 0xF0F0F0), dark: PlatformColor(hex: 0x424242)))
        return VStack(alignment: alignment(for: placed.column), spacing: 8) {
            if let cell = placed.cell {
                ForEach(cell.blocks.indices, id: \.self) { index in
                    block(cell.blocks[index], header: placed.isHeader)
                }
            }
        }
        .multilineTextAlignment(textAlignment(for: placed.column))
        .padding(Self.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlignment(for: placed.column))
        .overlay(alignment: .bottom) { if !last.row { line.frame(height: 1) } }
        .overlay(alignment: .trailing) { if !last.column { line.frame(width: 1) } }
    }

    @ViewBuilder private func block(_ block: Block, header: Bool) -> some View {
        switch block {
        case .paragraph(let runs), .small(let runs):
            Text(runs.attributed(size: bodySize)).fontWeight(header ? .semibold : .regular).textSelection(.enabled)
        case .code(let code):
            Text(code.lines.joined(separator: "\n")).font(.system(size: bodySize, design: .monospaced)).textSelection(.enabled)
        default:
            Text([block].plainText).fontWeight(header ? .semibold : .regular).textSelection(.enabled)
        }
    }

    private func alignment(for column: Int) -> HorizontalAlignment {
        switch table.alignments.indices.contains(column) ? table.alignments[column] : .unset {
        case .center: .center
        case .right: .trailing
        case .left, .unset: .leading
        }
    }

    private func textAlignment(for column: Int) -> TextAlignment {
        switch table.alignments.indices.contains(column) ? table.alignments[column] : .unset {
        case .center: .center
        case .right: .trailing
        case .left, .unset: .leading
        }
    }

    private func frameAlignment(for column: Int) -> Alignment {
        switch table.alignments.indices.contains(column) ? table.alignments[column] : .unset {
        case .center: .top
        case .right: .topTrailing
        case .left, .unset: .topLeading
        }
    }

    struct Placed {
        let cell: DocBPage.Table.Cell?
        let column: Int
        let span: Int
        let isHeader: Bool
    }
}
