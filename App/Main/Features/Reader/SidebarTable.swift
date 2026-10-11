// The sidebar's rows on macOS, for the navigator tree and the list of sources alike: a
// view-based NSTableView over flattened rows. The table reuses cells, so a 50,000-row tree
// scrolls like Finder; it animates rows sliding in and out when a node is opened or closed by
// hand and swaps them in place otherwise; its double action needs no single-click delay; and
// its cells' titles show in full over themselves on hover, like Finder. Selection is the
// caller's: clicks and arrow keys report up as opens, and the highlighted row follows the
// rows back down. Keyboard: arrows and page keys move and open, typing a title's start moves
// to it (type-select, spaces included) without opening, Return opens, Right and Left open and close.

#if os(macOS)
import AppKit
import DocBRender
import SwiftUI

/// What a row shows. `type` is the icon vocabulary; "groupMarker" is a heading with no icon.
protocol SidebarItem: Equatable, Identifiable where ID == Int64 {
    var depth: Int { get }
    var title: String { get }
    var type: String { get }
    var hasChildren: Bool { get }
    var isExpanded: Bool { get }
    var isSelected: Bool { get }
    var isExternal: Bool { get }
    /// Whether a click opens it; otherwise a click toggles it.
    var isOpenable: Bool { get }
    var badge: Badge? { get }
    /// A heading over the rows below it: bold, with no icon or chevron.
    var isModule: Bool { get }
    /// A line above, setting it off from what came before.
    var separatorAbove: Bool { get }
}

struct SidebarTable<Row: SidebarItem>: NSViewRepresentable {
    let rows: [Row]
    var toggle: (Row) -> Void = { _ in }
    let open: (Row) -> Void
    /// When nil, rows have no context menu.
    var openInNewWindow: ((Row) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let coordinator = context.coordinator
        let table = coordinator.table
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("title"))
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.headerView = nil
        table.style = .sourceList
        table.rowHeight = 22
        table.intercellSpacing = NSSize(width: 0, height: 2)
        table.backgroundColor = .clear
        table.focusRingType = .none   // the ring around a table that is not the scroll view's own document
        table.allowsEmptySelection = true
        table.allowsMultipleSelection = false
        table.dataSource = coordinator
        table.delegate = coordinator
        table.onKey = { [weak coordinator] key in coordinator?.key(key) ?? false }
        table.target = coordinator
        table.action = #selector(Coordinator.clicked)
        table.doubleAction = #selector(Coordinator.doubleClicked)
        if openInNewWindow != nil {
            let menu = NSMenu()
            menu.delegate = coordinator
            table.menu = menu
        }
        let scrollView = NSScrollView()
        scrollView.documentView = PaddedTable(table: table, padding: 2)
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        table.sizeLastColumnToFit()
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.toggle = toggle
        coordinator.open = open
        coordinator.openInNewWindow = openInNewWindow ?? { _ in }
        coordinator.apply(rows, animated: context.transaction.animation != nil)
    }

    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate {
        let table = SidebarTableView()
        private(set) var rows: [Row] = []
        var toggle: (Row) -> Void = { _ in }
        var open: (Row) -> Void = { _ in }
        var openInNewWindow: (Row) -> Void = { _ in }
        private var isSyncingSelection = false

        /// Shows new rows. A change by hand is one block of rows arriving or leaving after the
        /// node that was toggled, so the rows are compared from both ends and the block between
        /// slides; everything else is swapped in place, and a wholesale change is a reload.
        func apply(_ new: [Row], animated: Bool) {
            let old = rows
            guard new != old else { return }
            rows = new
            var prefix = 0
            while prefix < old.count, prefix < new.count, old[prefix].id == new[prefix].id { prefix += 1 }
            var suffix = 0
            while suffix < old.count - prefix, suffix < new.count - prefix, old[old.count - 1 - suffix].id == new[new.count - 1 - suffix].id { suffix += 1 }
            if old.isEmpty || prefix + suffix == 0 {
                table.reloadData()
            } else {
                table.beginUpdates()
                table.removeRows(at: IndexSet(integersIn: prefix..<(old.count - suffix)), withAnimation: animated ? [.slideUp, .effectFade] : [])
                table.insertRows(at: IndexSet(integersIn: prefix..<(new.count - suffix)), withAnimation: animated ? [.slideDown, .effectFade] : [])
                table.endUpdates()
                // Rows that stayed but changed: the toggled node's chevron, the selection.
                for index in 0..<prefix where old[index] != new[index] { reconfigure(index, animated: animated) }
                for offset in 0..<suffix where old[old.count - 1 - offset] != new[new.count - 1 - offset] { reconfigure(new.count - 1 - offset, animated: animated) }
            }
            syncSelection(scroll: old.firstIndex(where: \.isSelected).map { old[$0].id } != new.first(where: \.isSelected)?.id)
        }

        private func reconfigure(_ index: Int, animated: Bool) {
            (table.view(atColumn: 0, row: index, makeIfNecessary: false) as? SidebarCellView)?.configure(rows[index], animated: animated)
        }

        private func syncSelection(scroll: Bool) {
            isSyncingSelection = true
            defer { isSyncingSelection = false }
            if let index = rows.firstIndex(where: \.isSelected) {
                if table.selectedRow != index { table.selectRowIndexes([index], byExtendingSelection: false) }
                if scroll { table.scrollRowToVisible(index) }
            } else if table.selectedRow >= 0 {
                table.deselectAll(nil)
            }
        }

        // MARK: Data

        func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            let identifier = NSUserInterfaceItemIdentifier("row")
            let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? SidebarCellView ?? {
                let cell = SidebarCellView()
                cell.identifier = identifier
                cell.chevron.onClick = { [weak self, weak cell] in
                    guard let self, let cell else { return }
                    let index = table.row(for: cell)
                    if index >= 0 { toggle(rows[index]) }
                }
                return cell
            }()
            cell.configure(rows[row], animated: false)
            return cell
        }

        func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
            rows[row].isOpenable
        }

        // MARK: Actions

        /// A selection moved by a navigation key opens the row; one moved by type-select does
        /// not, or every letter typed would open a page. Clicks open through the action.
        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !isSyncingSelection, table.selectedRow >= 0, let event = NSApp.currentEvent, event.type == .keyDown,
                  let scalar = event.charactersIgnoringModifiers?.unicodeScalars.first, (0xF700...0xF8FF).contains(scalar.value) else { return }
            open(rows[table.selectedRow])
        }

        func tableView(_ tableView: NSTableView, typeSelectStringFor tableColumn: NSTableColumn?, row: Int) -> String? {
            rows[row].isOpenable ? rows[row].title : nil
        }

        /// Return opens the highlighted row; Right and Left open and close it.
        func key(_ key: SidebarTableView.Key) -> Bool {
            guard table.selectedRow >= 0 else { return false }
            let row = rows[table.selectedRow]
            switch key {
            case .activate:
                open(row)
            case .expand where row.hasChildren && !row.isExpanded, .collapse where row.hasChildren && row.isExpanded:
                toggle(row)
            default:
                return false
            }
            return true
        }

        @objc func clicked() {
            guard table.clickedRow >= 0 else { return }
            let row = rows[table.clickedRow]
            if !row.isOpenable { toggle(row) } else if !row.isSelected { open(row) }
        }

        @objc func doubleClicked() {
            guard table.clickedRow >= 0, rows[table.clickedRow].hasChildren else { return }
            toggle(rows[table.clickedRow])
        }

        func menuNeedsUpdate(_ menu: NSMenu) {
            menu.removeAllItems()
            guard table.clickedRow >= 0, rows[table.clickedRow].isOpenable else { return }
            menu.addItem(withTitle: "Open in New Window", action: #selector(openInNewWindowClicked), keyEquivalent: "").target = self
        }

        @objc private func openInNewWindowClicked() {
            guard table.clickedRow >= 0 else { return }
            openInNewWindow(rows[table.clickedRow])
        }
    }
}

/// An NSTableView that reports the keys it has no use for itself.
final class SidebarTableView: NSTableView {
    enum Key { case activate, expand, collapse }
    var onKey: (Key) -> Bool = { _ in false }

    override func keyDown(with event: NSEvent) {
        let key: Key? = switch event.charactersIgnoringModifiers?.unicodeScalars.first?.value {
        case 0x0D, 0x03: .activate         // return, enter; a space is part of a typed title
        case 0xF703: .expand               // right arrow
        case 0xF702: .collapse             // left arrow
        default: nil
        }
        if let key, onKey(key) { return }
        super.keyDown(with: event)
    }
}

/// The table with a little room above its first row and below its last, as part of the
/// scrolled content rather than an inset, so nothing is ever bare while scrolling.
private final class PaddedTable: NSView {
    private let table: NSTableView
    private let padding: CGFloat

    init(table: NSTableView, padding: CGFloat) {
        self.table = table
        self.padding = padding
        super.init(frame: .zero)
        addSubview(table)
        table.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(tableFrameChanged), name: NSView.frameDidChangeNotification, object: table)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }

    /// Follows the clip view's width; the table follows this width and sets its own height.
    override func resizeSubviews(withOldSize oldSize: NSSize) {
        table.frame = NSRect(x: 0, y: padding, width: bounds.width, height: table.frame.height)
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        autoresizingMask = [.width]
        if let clip = superview as? NSClipView { frame.size.width = clip.bounds.width }
        tableFrameChanged()
    }

    @objc private func tableFrameChanged() {
        let height = table.frame.height + 2 * padding
        if abs(frame.height - height) > 0.5 || table.frame.minY != padding {
            frame.size.height = height
            table.frame.origin = CGPoint(x: 0, y: padding)
        }
    }
}

/// One row: a chevron for nodes with children, the topic icon, a title that truncates in the
/// middle, and an arrow for links out to another source. Laid out by hand; a row is 22 points.
private final class SidebarCellView: NSTableCellView {
    let chevron = ChevronView()
    private let icon = NSImageView()
    private let title = NSTextField(labelWithString: "")
    private let titleCell = ExpansionCell()
    private let badge = NSImageView()
    private let external = NSImageView()
    private let separator = NSBox()
    private var depth = 0

    override init(frame: NSRect) {
        super.init(frame: frame)
        icon.imageScaling = .scaleProportionallyDown
        title.cell = titleCell
        title.lineBreakMode = .byTruncatingMiddle
        title.allowsExpansionToolTips = true
        title.cell?.truncatesLastVisibleLine = true
        title.isEditable = false
        title.isSelectable = false
        title.isBezeled = false
        title.drawsBackground = false
        external.image = NSImage(systemSymbolName: "arrow.up.forward", accessibilityDescription: "External")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 9, weight: .bold))
        external.contentTintColor = .tertiaryLabelColor
        badge.imageScaling = .scaleNone
        separator.boxType = .separator
        for view in [separator, chevron, icon, title, badge, external] { addSubview(view) }
        textField = title
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(_ row: some SidebarItem, animated: Bool) {
        let isGroup = row.type == "groupMarker"
        depth = row.depth
        separator.isHidden = !row.separatorAbove
        chevron.isHidden = !row.hasChildren
        icon.isHidden = isGroup || row.isModule
        icon.image = icon.isHidden ? nil : TopicIconView.nsImage(for: row.type)
        title.stringValue = row.title
        let body = NSFont.preferredFont(forTextStyle: .body)
        title.font = row.isModule ? .systemFont(ofSize: body.pointSize + 1, weight: .semibold) : isGroup ? .boldSystemFont(ofSize: NSFont.preferredFont(forTextStyle: .caption1).pointSize) : body
        title.textColor = isGroup ? .secondaryLabelColor : .labelColor
        titleCell.fullWidth = ceil(titleCell.cellSize(forBounds: NSRect(x: 0, y: 0, width: 100_000, height: 100)).width)
        external.isHidden = !(row.isExternal && row.isOpenable)
        badge.image = row.badge?.image(beside: NSFont.preferredFont(forTextStyle: .body).pointSize)
        badge.isHidden = badge.image == nil
        let rotation: CGFloat = row.isExpanded ? 90 : 0
        if chevron.rotation != rotation {
            if animated {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.2
                    chevron.animator().rotation = rotation
                }
            } else {
                chevron.rotation = rotation
            }
        }
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let height = bounds.height
        separator.frame = NSRect(x: 4, y: height - 1, width: bounds.width - 8, height: 1)
        var x = 4 + CGFloat(depth) * 14
        chevron.frame = NSRect(x: x, y: (height - 14) / 2, width: 14, height: 14)
        x += 18
        if !icon.isHidden {
            icon.frame = NSRect(x: x, y: (height - 16) / 2, width: 16, height: 16)
            x += 20
        }
        var trailing = bounds.width - 8
        if !external.isHidden {
            external.frame = NSRect(x: trailing - 12, y: (height - 12) / 2, width: 12, height: 12)
            trailing -= 16
        }
        let titleHeight = title.intrinsicContentSize.height
        var titleWidth = max(0, trailing - x)
        if let image = badge.image {
            // The badge follows the title, and the title gives way to it when there is no room.
            // Measured against no width at all: a truncating field's intrinsic size reports the
            // width it already has, so it would stay short once shortened.
            let badgeWidth = image.size.width + 5
            titleWidth = min(titleCell.fullWidth + 1, max(0, trailing - x - badgeWidth))
            badge.frame = NSRect(x: x + titleWidth + 5, y: (height - image.size.height) / 2, width: image.size.width, height: image.size.height)
        }
        title.frame = NSRect(x: x, y: (height - titleHeight) / 2, width: titleWidth, height: titleHeight)
    }
}

/// A label cell whose expansion tooltip costs nothing to ask about. AppKit resets every cursor
/// rect and tracking area in the window on each frame of any scroll, and for each visible
/// label with an expansion tooltip that meant measuring its text again; with forty rows on
/// screen that ate the page's frame budget and let a flick outrun its scroll cache. The text
/// is measured once when the row is configured.
final class ExpansionCell: NSTextFieldCell {
    var fullWidth: CGFloat = 0

    override func expansionFrame(withFrame cellFrame: NSRect, in view: NSView) -> NSRect {
        guard fullWidth > cellFrame.width + 0.5 else { return .zero }
        return NSRect(x: cellFrame.minX, y: cellFrame.minY, width: fullWidth + 4, height: cellFrame.height)
    }
}

/// A chevron that turns in place: the view never moves, the drawing rotates about the center
/// of its bounds, and `rotation` is animatable through the animator proxy like any AppKit key.
final class ChevronView: NSView {
    /// Degrees clockwise from pointing right.
    @objc dynamic var rotation: CGFloat = 0 { didSet { needsDisplay = true } }
    var onClick: () -> Void = {}
    private let image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Expand")?
        .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 9, weight: .bold).applying(.init(paletteColors: [.secondaryLabelColor])))

    override class func defaultAnimation(forKey key: NSAnimatablePropertyKey) -> Any? {
        key == "rotation" ? CABasicAnimation() : super.defaultAnimation(forKey: key)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let image, let context = NSGraphicsContext.current?.cgContext else { return }
        context.translateBy(x: bounds.midX, y: bounds.midY)
        context.rotate(by: -rotation * .pi / 180)
        image.draw(in: NSRect(x: -image.size.width / 2, y: -image.size.height / 2, width: image.size.width, height: image.size.height))
    }

    override func mouseDown(with event: NSEvent) { onClick() }
}
#endif
