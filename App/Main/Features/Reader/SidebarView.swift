// The navigator sidebar. At home it lists the library's sources; on a page it shows that
// source's tree, on macOS with a filter at the bottom. On macOS the tree is an NSTableView
// (see SidebarTable): fast, animated, and with Finder-style tooltips; on iOS it is a List.
// Titles truncate in the middle.

import ComposableArchitecture
import DocBRender
import DocBSources
import DocBStore
import SwiftUI

struct SidebarView: View {
    @Bindable var store: StoreOf<SidebarFeature>
    let route: Route
    let sources: [SourceRecord]
    let pickSource: (Source) -> Void
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if route == .home {
            SourcesSidebar(sources: sources, pick: pickSource)
        } else {
            treeSidebar
        }
    }

    private var treeSidebar: some View {
        VStack(spacing: 0) {
            #if os(macOS)
            SidebarTable(rows: store.rows) { row in
                store.send(.toggled(row.id), animation: .easeInOut(duration: 0.2))
            } open: { row in
                store.send(.rowTapped(row))
            } openInNewWindow: { row in
                openInNewWindow(row)
            }
            // The filter bar, as Xcode's navigators have it; home is in the toolbar.
            Divider()
            HStack(spacing: 8) {
                FilterField(text: $store.filter)
                if store.isLoading { ProgressView().controlSize(.small) }
            }
            .padding(8)
            #else
            // The list's own selection: the platform's highlight, and on visionOS its gaze
            // highlight, over the whole row. Rows are 32 points with no insets of their own, so
            // the highlight is the row, and the list keeps the Mac's 2 points above and below.
            List(store.rows, selection: Binding(get: { store.rows.first { $0.isSelected }?.id }, set: { id in
                if let row = store.rows.first(where: { $0.id == id }) { store.send(.rowTapped(row)) }
            })) { row in
                SidebarRow(row: row) {
                    store.send(.toggled(row.id), animation: .easeInOut(duration: 0.2))
                } openInNewWindow: {
                    openInNewWindow(row)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                .selectionDisabled(row.location == nil)
            }
            .contentMargins(.vertical, 12, for: .scrollContent)
            .listStyle(.sidebar)
            #endif
        }
    }

    private func openInNewWindow(_ row: SidebarFeature.State.Row) {
        // The reducer registers the window's reader before the window is asked for.
        let id = UUID()
        store.send(.openInNewWindowTapped(id: id, row))
        openWindow(value: ReaderWindow(id: id, location: row.location))
    }
}

private struct SourcesSidebar: View {
    let sources: [SourceRecord]
    let pick: (Source) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if sources.isEmpty {
                #if os(macOS)
                let hint = "Press ⌘L to add one."
                #else
                let hint = "Open the Library from the toolbar to add one."
                #endif
                ContentUnavailableView("No sources", systemImage: "books.vertical", description: Text(hint))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                #if os(macOS)
                SidebarTable(rows: sources.enumerated().map { SourceItem(id: Int64($0.offset), title: $0.element.source.title) }) { item in
                    pick(sources[Int(item.id)].source)
                }
                #else
                // The same rows as the tree: 32 points, the list's selection and gaze highlight.
                List(sources, id: \.source, selection: Binding<Source?>(get: { nil }, set: { if let source = $0 { pick(source) } })) { record in
                    HStack(spacing: 4) {
                        Color.clear.frame(width: 18, height: 1)
                        TopicIconView(type: "module", size: 18)
                        TruncatedLabel(record.source.title, font: .body)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary).padding(.trailing, 4)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 32)
                    .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                }
                .contentMargins(.vertical, 12, for: .scrollContent)
                .listStyle(.sidebar)
                #endif
            }
        }
    }
}

#if os(macOS)
extension SidebarFeature.State.Row: SidebarItem {
    var isOpenable: Bool { location != nil }
    var badge: Badge? { Badge(isBeta: isBeta, isDeprecated: isDeprecated) }
}

/// A source in the home sidebar, drawn like a module in the tree.
private struct SourceItem: SidebarItem {
    var id: Int64
    var title: String
    var depth: Int { 0 }
    var type: String { "module" }
    var hasChildren: Bool { false }
    var isExpanded: Bool { false }
    var isSelected: Bool { false }
    var isExternal: Bool { false }
    var isOpenable: Bool { true }
    var badge: Badge? { nil }
    var isModule: Bool { false }
    var separatorAbove: Bool { false }
}
#endif

#if !os(macOS)
private struct SidebarRow: View, @MainActor Equatable {
    let row: SidebarFeature.State.Row
    let toggle: () -> Void
    let openInNewWindow: () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.row == rhs.row }

    private var isGroup: Bool { row.type == "groupMarker" }

    var body: some View {
        HStack(spacing: 4) {
            if row.isModule {
                // Starts where the icons start, not where the chevrons do.
                Color.clear.frame(width: 18, height: 1)
                TruncatedLabel(row.title, font: .title3.weight(.semibold))
            } else {
                Color.clear.frame(width: CGFloat(row.depth) * 14, height: 1)
                if row.hasChildren {
                    // The whole 28-point square answers taps and the gaze, not the glyph alone.
                    Button(action: toggle) {
                        Image(systemName: "chevron.right")
                            .font(.caption2.bold())
                            .rotationEffect(.degrees(row.isExpanded ? 90 : 0))
                            .frame(width: 28, height: 28)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                } else {
                    Color.clear.frame(width: 18, height: 1)
                }
                if !isGroup {
                    TopicIconView(type: row.type, size: 18)
                }
                TruncatedLabel(row.title, font: isGroup ? .caption.bold() : .body, color: isGroup ? .secondary : .primary)
            }
            Spacer(minLength: 0)
            if row.isExternal, row.location != nil {
                Image(systemName: "arrow.up.forward")
                    .font(.caption2.bold())
                    .foregroundStyle(.tertiary)
                    .padding(.trailing, 4)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 32)
        .overlay(alignment: .top) {
            if row.separatorAbove { Divider() }
        }
        .contextMenu {
            if row.location != nil {
                Button("Open in New Window", action: openInNewWindow)
            }
        }
    }
}
#endif

/// A one-line title that truncates in the middle. On macOS it is an AppKit label so that,
/// like Finder, hovering a truncated title shows the whole of it laid over the label itself.
struct TruncatedLabel: View {
    let text: String
    var font: Font = .body
    var color: Color = .primary

    init(_ text: String, font: Font = .body, color: Color = .primary) {
        self.text = text
        self.font = font
        self.color = color
    }

    var body: some View {
        #if os(macOS)
        ExpandingLabel(text: text, font: font, color: color)
        #else
        Text(text).font(font).foregroundStyle(color).lineLimit(1).truncationMode(.middle)
        #endif
    }
}

#if os(macOS)
/// A label that leaves clicks to the SwiftUI row around it; a text field would keep them.
private final class PassthroughLabel: NSTextField {
    override func mouseDown(with event: NSEvent) { nextResponder?.mouseDown(with: event) }
    override func mouseDragged(with event: NSEvent) { nextResponder?.mouseDragged(with: event) }
    override func mouseUp(with event: NSEvent) { nextResponder?.mouseUp(with: event) }
    override func rightMouseDown(with event: NSEvent) { nextResponder?.rightMouseDown(with: event) }
    override func rightMouseUp(with event: NSEvent) { nextResponder?.rightMouseUp(with: event) }
}

private struct ExpandingLabel: NSViewRepresentable {
    let text: String
    let font: Font
    let color: Color

    func makeNSView(context: Context) -> NSTextField {
        let label = PassthroughLabel(labelWithString: "")
        label.lineBreakMode = .byTruncatingMiddle
        label.allowsExpansionToolTips = true
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return label
    }

    func updateNSView(_ label: NSTextField, context: Context) {
        label.stringValue = text
        label.font = nsFont
        label.textColor = NSColor(color)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView label: NSTextField, context: Context) -> CGSize? {
        let fitting = label.intrinsicContentSize
        return CGSize(width: min(fitting.width, proposal.width ?? fitting.width), height: fitting.height)
    }

    private var nsFont: NSFont {
        switch font {
        case .headline: .preferredFont(forTextStyle: .headline)
        case .caption.bold(): .boldSystemFont(ofSize: NSFont.preferredFont(forTextStyle: .caption1).pointSize)
        default: .preferredFont(forTextStyle: .body)
        }
    }
}
#endif
