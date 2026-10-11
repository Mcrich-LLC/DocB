// A tab navigator in the page: its tabs and which one is showing. The bar is a hosted view
// and the showing tab's content is written into the text after it; switching swaps that
// stretch of text. The document draws a box around both.

import DocBPage
import SwiftUI

@MainActor @Observable
final class TabGroup {
    let tabs: [DocBPage.Tab]
    /// The indent of what holds the group; the box starts there.
    let indent: CGFloat
    /// The page's badge, which the content's topics do not repeat.
    let pageBadge: Badge?
    var selected = 0

    /// Whether the showing tab is one code listing, shown bare in the group's box.
    var showsListingAlone: Bool {
        guard tabs.indices.contains(selected), tabs[selected].blocks.count == 1, case .code = tabs[selected].blocks[0] else { return false }
        return true
    }

    init(tabs: [DocBPage.Tab], indent: CGFloat, pageBadge: Badge?) {
        self.tabs = tabs
        self.indent = indent
        self.pageBadge = pageBadge
    }
}

extension EnvironmentValues {
    /// Shows a tab of a group; the document swaps the content.
    @Entry var selectTab: (TabGroup, Int) -> Void = { _, _ in }
}

/// The bar as the web's tab navigator draws it: the titles in a row, the showing one in the
/// text color with a line under it, the others secondary. The line under the bar, across the
/// whole box, is the box's to draw.
struct TabBarView: View {
    let group: TabGroup
    @Environment(\.selectTab) private var selectTab
    private var bodySize: CGFloat { PlatformFont.preferredFont(forTextStyle: .body).pointSize }

    var body: some View {
        HStack(spacing: 24) {
                ForEach(group.tabs.indices, id: \.self) { index in
                    let showing = index == group.selected
                    Button {
                        selectTab(group, index)
                    } label: {
                        Text(group.tabs[index].title)
                            .font(.system(size: bodySize, weight: .medium))
                            .foregroundStyle(showing ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                            .padding(.bottom, 8)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(.tint).frame(height: 2).opacity(showing ? 1 : 0)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(showing ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
