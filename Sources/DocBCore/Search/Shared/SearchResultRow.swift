import SwiftUI
import DocCKit
import SFSafeSymbols

/// Shared scrolling list for Search Documentation results.
public struct SearchResultList: View {
    private let results: SidebarSearchResults
    private let selectedRowID: SidebarSearchResultRow.ID?
    private let height: CGFloat
    private let rowMetrics: SearchResultRowMetrics
    private let listMetrics: SearchResultListMetrics
    private let select: (SidebarSearchResultRow) -> Void
    private let openSelectedResult: () -> Void

    @Environment(OpenQuicklySearchCoordinator.self) private var coordinator
    @Environment(DocumentationViewModel.self) private var documentationViewModel

    /// Creates a scrolling Search Documentation results list.
    ///
    /// - Parameters:
    ///   - results: Grouped search results to render.
    ///   - selectedRowID: Identifier for the currently selected row.
    ///   - height: Fixed visible list height.
    ///   - rowMetrics: Platform-specific row styling metrics.
    ///   - listMetrics: Platform-specific list styling metrics.
    ///   - select: Called before opening a tapped row.
    ///   - openSelectedResult: Called when the selected row should be activated.
    public init(
        results: SidebarSearchResults,
        selectedRowID: SidebarSearchResultRow.ID?,
        height: CGFloat,
        rowMetrics: SearchResultRowMetrics,
        listMetrics: SearchResultListMetrics,
        select: @escaping (SidebarSearchResultRow) -> Void,
        openSelectedResult: @escaping () -> Void
    ) {
        self.results = results
        self.selectedRowID = selectedRowID
        self.height = height
        self.rowMetrics = rowMetrics
        self.listMetrics = listMetrics
        self.select = select
        self.openSelectedResult = openSelectedResult
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                    ForEach(results.sections) { section in
                        Text(section.title)
                            .font(listMetrics.sectionHeaderFont)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, listMetrics.sectionHorizontalPadding)
                            .padding(.top, listMetrics.sectionTopPadding)
                            .padding(.bottom, listMetrics.sectionBottomPadding)

                        ForEach(section.rows) { row in
                            SearchResultRow(row: row, isSelected: selectedRowID == row.id, metrics: rowMetrics) {
                                select(row)
                                openSelectedResult()
                            }
                            .id(row.id)
                            .onAppear {
                                coordinator.preloadVisibleResult(row, documentationViewModel: documentationViewModel)
                            }
                            .padding(.horizontal, listMetrics.rowHorizontalPadding)
                            .padding(.vertical, listMetrics.rowVerticalPadding)
                        }
                    }

                    if results.isTruncated {
                        Text("Showing the first \(SidebarSearchIndex.defaultResultLimit) of \(results.totalMatches) matches. Refine your search to narrow the results.")
                            .font(listMetrics.footerFont)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, listMetrics.footerHorizontalPadding)
                            .padding(.vertical, listMetrics.footerVerticalPadding)
                    }

                    Color.clear
                        .frame(height: listMetrics.bottomInset)
                }
            }
            .background(.clear)
            .scrollIndicators(listMetrics.showsScrollIndicators ? .automatic : .hidden)
            .frame(height: height)
            .onChange(of: selectedRowID) { _, newValue in
                guard let newValue else { return }

                proxy.scrollTo(newValue, anchor: .center)
            }
        }
    }
}

/// Shared Search Documentation result row icon, subtitle, and accessibility behavior.
public struct SearchResultRow: View {
    private let row: SidebarSearchResultRow
    private let isSelected: Bool
    private let metrics: SearchResultRowMetrics
    private let action: () -> Void
    @State private var resolvedSymbolKind: SidebarSearchSymbolKind?
    @Environment(DocumentationViewModel.self) private var documentationViewModel

    /// Creates a shared Search Documentation result row.
    ///
    /// - Parameters:
    ///   - row: Search result to display.
    ///   - isSelected: Whether this row is the current keyboard selection.
    ///   - metrics: Platform-specific row styling metrics.
    ///   - action: Action to perform when the row is selected.
    public init(
        row: SidebarSearchResultRow,
        isSelected: Bool,
        metrics: SearchResultRowMetrics,
        action: @escaping () -> Void
    ) {
        self.row = row
        self.isSelected = isSelected
        self.metrics = metrics
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: metrics.spacing) {
                SearchResultSymbolBadge(row: row, symbolKind: resolvedSymbolKind, isSelected: isSelected, size: metrics.iconSize)
                    .font(metrics.iconFont)

                VStack(alignment: .leading, spacing: metrics.textSpacing) {
                    Text(row.title)
                        .font(metrics.titleFont)
                        .foregroundStyle(isSelected ? .white : .primary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(metrics.subtitleFont)
                        .foregroundStyle(isSelected ? .white.opacity(0.82) : .secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: metrics.spacing)
            }
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.vertical, metrics.verticalPadding)
            .frame(height: metrics.height)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
                        .fill(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens this documentation result.")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .task(id: row.id) {
            await resolveSymbolKind()
        }
    }

    private var subtitle: String {
        switch row {
        case .homepage:
            "DocB"
        case .reference(let result):
            SearchResultSymbolBadge.title(for: resolvedSymbolKind ?? result.symbolKind, fallback: result.type)
        case .technology(let result):
            result.framework.docCSite?.overrideName ?? "Technology"
        }
    }

    private var accessibilityLabel: String {
        "\(row.title), \(subtitle)"
    }

    @MainActor
    private func resolveSymbolKind() async {
        guard case .reference(let result) = row else {
            resolvedSymbolKind = nil
            return
        }

        let reference = result.reference(deepLinkScheme: DocCDeepLinkScheme.mainBundle ?? DocCDeepLinkScheme(Constants.deeplinkScheme))

        do {
            let article = try await documentationViewModel.fetchArticle(for: reference.identifier, site: result.site)
            resolvedSymbolKind = SidebarSearchSymbolKind(roleHeading: article.metadata.roleHeading)
        } catch {
            resolvedSymbolKind = nil
        }
    }
}

/// Xcode documentation-style badge for search result rows.
public struct SearchResultSymbolBadge: View {
    private let row: SidebarSearchResultRow
    private let symbolKind: SidebarSearchSymbolKind?
    private let isSelected: Bool
    private let size: CGFloat

    /// Creates a role badge for a search result row.
    ///
    /// - Parameters:
    ///   - row: Search result to represent.
    ///   - symbolKind: Optional resolved symbol kind from full article metadata.
    ///   - isSelected: Whether the owning row is selected.
    ///   - size: Square badge size.
    public init(
        row: SidebarSearchResultRow,
        symbolKind: SidebarSearchSymbolKind? = nil,
        isSelected: Bool = false,
        size: CGFloat = 22
    ) {
        self.row = row
        self.symbolKind = symbolKind
        self.isSelected = isSelected
        self.size = size
    }

    public var body: some View {
        let appearance = appearance(for: row)

        ZStack {
            RoundedRectangle(cornerRadius: max(4, size * 0.18), style: .continuous)
                .fill(appearance.background)

            if let symbol = appearance.symbol {
                Image(systemSymbol: symbol)
                    .font(.system(size: size * 0.58, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : appearance.foreground)
            } else {
                Text(appearance.text)
                    .font(.system(size: size * 0.46, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? .white : appearance.foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// Returns a human-readable role title for subtitles and accessibility.
    ///
    /// - Parameters:
    ///   - role: Decoded DocC role.
    ///   - fallback: Raw role string used when `role` is unavailable.
    /// - Returns: A display title for the role.
    public static func title(for symbolKind: SidebarSearchSymbolKind, fallback: String) -> String {
        switch symbolKind {
        case .article:
            "Article"
        case .classSymbol:
            "Class"
        case .collection:
            "Collection"
        case .collectionGroup:
            "Collection Group"
        case .framework:
            "Framework"
        case .enumeration:
            "Enumeration"
        case .enumerationCase:
            "Enumeration Case"
        case .function:
            "Function"
        case .initializer:
            "Initializer"
        case .macro:
            "Macro"
        case .method:
            "Method"
        case .property:
            "Property"
        case .protocolSymbol:
            "Protocol"
        case .structure:
            "Structure"
        case .typeAlias:
            "Type Alias"
        case .variable:
            "Variable"
        case .unknown:
            fallback.isEmpty ? "Documentation" : fallback.capitalized
        }
    }

    private func appearance(for row: SidebarSearchResultRow) -> BadgeAppearance {
        switch row {
        case .homepage:
            BadgeAppearance(text: "", symbol: .houseFill, foreground: .white, background: .blue)
        case .reference(let result):
            appearance(for: symbolKind ?? result.symbolKind)
        case .technology:
            BadgeAppearance(text: "Pr", symbol: nil, foreground: .white, background: .purple)
        }
    }

    private func appearance(for symbolKind: SidebarSearchSymbolKind) -> BadgeAppearance {
        switch symbolKind {
        case .article:
            BadgeAppearance(text: "", symbol: .textDocument, foreground: .white, background: .blue)
        case .classSymbol:
            BadgeAppearance(text: "C", symbol: nil, foreground: .white, background: .purple)
        case .collection:
            BadgeAppearance(text: "", symbol: .listBullet, foreground: .white, background: .secondary)
        case .collectionGroup:
            BadgeAppearance(text: "", symbol: .listBullet, foreground: .white, background: .indigo)
        case .enumeration:
            BadgeAppearance(text: "E", symbol: nil, foreground: .white, background: .orange)
        case .enumerationCase:
            BadgeAppearance(text: "K", symbol: nil, foreground: .white, background: .green)
        case .framework:
            BadgeAppearance(text: "Pr", symbol: nil, foreground: .white, background: .purple)
        case .function:
            BadgeAppearance(text: "f", symbol: nil, foreground: .white, background: .green)
        case .initializer, .method:
            BadgeAppearance(text: "M", symbol: nil, foreground: .white, background: .blue)
        case .macro:
            BadgeAppearance(text: "#", symbol: nil, foreground: .white, background: .green)
        case .property:
            BadgeAppearance(text: "P", symbol: nil, foreground: .white, background: .cyan)
        case .protocolSymbol:
            BadgeAppearance(text: "Pr", symbol: nil, foreground: .white, background: .purple)
        case .structure:
            BadgeAppearance(text: "S", symbol: nil, foreground: .white, background: .purple)
        case .typeAlias:
            BadgeAppearance(text: "T", symbol: nil, foreground: .white, background: .orange)
        case .variable:
            BadgeAppearance(text: "V", symbol: nil, foreground: .white, background: .green)
        case .unknown:
            BadgeAppearance(text: "", symbol: .textDocument, foreground: .white, background: .secondary)
        }
    }

    private struct BadgeAppearance {
        let text: String
        let symbol: SFSymbol?
        let foreground: Color
        let background: Color
    }
}

/// Platform-specific visual metrics for a search result row.
public struct SearchResultRowMetrics {
    let height: CGFloat
    let cornerRadius: CGFloat
    let spacing: CGFloat
    let textSpacing: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let iconSize: CGFloat
    let iconFont: Font
    let titleFont: Font
    let subtitleFont: Font

    /// Creates visual metrics for a search result row.
    ///
    /// - Parameters:
    ///   - height: Fixed row height.
    ///   - cornerRadius: Corner radius for the selected row background.
    ///   - spacing: Horizontal spacing between the icon and text.
    ///   - textSpacing: Vertical spacing between title and subtitle.
    ///   - horizontalPadding: Horizontal padding inside the row.
    ///   - verticalPadding: Vertical padding inside the row.
    ///   - iconSize: Fixed icon frame size.
    ///   - iconFont: Font used by the SF Symbol icon.
    ///   - titleFont: Font used by the result title.
    ///   - subtitleFont: Font used by the result subtitle.
    public init(
        height: CGFloat,
        cornerRadius: CGFloat,
        spacing: CGFloat,
        textSpacing: CGFloat,
        horizontalPadding: CGFloat,
        verticalPadding: CGFloat,
        iconSize: CGFloat,
        iconFont: Font,
        titleFont: Font,
        subtitleFont: Font
    ) {
        self.height = height
        self.cornerRadius = cornerRadius
        self.spacing = spacing
        self.textSpacing = textSpacing
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.iconSize = iconSize
        self.iconFont = iconFont
        self.titleFont = titleFont
        self.subtitleFont = subtitleFont
    }
}

/// Platform-specific visual metrics for a search results list.
public struct SearchResultListMetrics {
    let sectionHeaderFont: Font
    let sectionHorizontalPadding: CGFloat
    let sectionTopPadding: CGFloat
    let sectionBottomPadding: CGFloat
    let rowHorizontalPadding: CGFloat
    let rowVerticalPadding: CGFloat
    let footerFont: Font
    let footerHorizontalPadding: CGFloat
    let footerVerticalPadding: CGFloat
    let bottomInset: CGFloat
    let showsScrollIndicators: Bool

    /// Creates visual metrics for a search results list.
    ///
    /// - Parameters:
    ///   - sectionHeaderFont: Font for section names.
    ///   - sectionHorizontalPadding: Horizontal padding applied to section names.
    ///   - sectionTopPadding: Top padding applied to section names.
    ///   - sectionBottomPadding: Bottom padding applied to section names.
    ///   - rowHorizontalPadding: Horizontal padding around each row.
    ///   - rowVerticalPadding: Vertical padding around each row.
    ///   - footerFont: Font for truncation footer text.
    ///   - footerHorizontalPadding: Horizontal footer padding.
    ///   - footerVerticalPadding: Vertical footer padding.
    ///   - bottomInset: Empty space after the last row.
    ///   - showsScrollIndicators: Whether the list should show scroll indicators.
    public init(
        sectionHeaderFont: Font,
        sectionHorizontalPadding: CGFloat,
        sectionTopPadding: CGFloat,
        sectionBottomPadding: CGFloat,
        rowHorizontalPadding: CGFloat,
        rowVerticalPadding: CGFloat,
        footerFont: Font,
        footerHorizontalPadding: CGFloat = 0,
        footerVerticalPadding: CGFloat,
        bottomInset: CGFloat,
        showsScrollIndicators: Bool
    ) {
        self.sectionHeaderFont = sectionHeaderFont
        self.sectionHorizontalPadding = sectionHorizontalPadding
        self.sectionTopPadding = sectionTopPadding
        self.sectionBottomPadding = sectionBottomPadding
        self.rowHorizontalPadding = rowHorizontalPadding
        self.rowVerticalPadding = rowVerticalPadding
        self.footerFont = footerFont
        self.footerHorizontalPadding = footerHorizontalPadding
        self.footerVerticalPadding = footerVerticalPadding
        self.bottomInset = bottomInset
        self.showsScrollIndicators = showsScrollIndicators
    }
}

extension SidebarSearchResults {
    var flattenedRows: [SidebarSearchResultRow] {
        sections.flatMap(\.rows)
    }
}
