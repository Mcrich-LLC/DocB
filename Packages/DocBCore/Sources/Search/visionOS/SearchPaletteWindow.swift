#if os(visionOS)
import SwiftUI
import SFSafeSymbols

/// Window-based visionOS Search Documentation palette.
public struct SearchPaletteWindow: View {
    private static let width: CGFloat = 680
    private static let maximumHeight: CGFloat = 560
    private static let cornerRadius: CGFloat = 28
    private static let searchHeaderHeight: CGFloat = 82
    private static let resultRowHeight: CGFloat = 74
    private static let sectionHeaderHeight: CGFloat = 44
    private static let idleContentHeight: CGFloat = 148
    private static let resultsBottomInset: CGFloat = 14
    private static let statusHeight: CGFloat = 188
    private static let footerHeight: CGFloat = 58

    @Environment(OpenQuicklySearchCoordinator.self) private var coordinator
    @Environment(DocumentationViewModel.self) private var documentationViewModel
    @Environment(\.customEnabledDismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @FocusState private var isSearchFocused: Bool

    /// Creates the visionOS Search Documentation palette window.
    public init() {}

    public var body: some View {
        @Bindable var coordinator = coordinator

        paletteContent
            .frame(width: Self.width, height: paletteHeight)
            .onAppear(perform: appear)
            .onDisappear {
                documentationViewModel.clearArticleCache()
            }
            .onChange(of: coordinator.query) { _, newValue in
                coordinator.updateQuery(newValue)
            }
            .onChange(of: coordinator.searchStore.isSearching) { _, isSearching in
                guard !isSearching else { return }

                coordinator.selectDefaultResultIfNeeded()
            }
            .onChange(of: coordinator.searchStore.isRebuildingIndex) { _, isRebuildingIndex in
                guard !isRebuildingIndex else { return }

                coordinator.selectDefaultResultIfNeeded()
            }
            .onSubmit(openSelectedResult)
            .onKeyPress(.upArrow) {
                coordinator.moveSelection(by: -1)
                return .handled
            }
            .onKeyPress(.downArrow) {
                coordinator.moveSelection(by: 1)
                return .handled
            }
            .onKeyPress(.return) {
                openSelectedResult()
                return .handled
            }
            .onKeyPress(.escape) {
                dismiss()
                return .handled
            }
            .accessibilityElement(children: .contain)
    }

    private var paletteContent: some View {
        VStack(spacing: 0) {
            searchHeader(query: Bindable(coordinator).query)

            Divider()

            if showsResultsContent {
                resultsContent
            } else {
                idleContent
            }
        }
        .background(Color.black.opacity(0.38))
    }

    private var idleContent: some View {
        VStack(spacing: 10) {
            Image(systemSymbol: .keyboard)
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(.white.opacity(0.42))

            Text("Start typing to search documentation")
                .font(.headline.weight(.medium))
                .foregroundStyle(.white.opacity(0.68))
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.idleContentHeight)
        .accessibilityElement(children: .combine)
    }

    private var resultsContent: some View {
        Group {
            if coordinator.searchStore.results.isEmpty {
                if coordinator.searchStore.isSearching || coordinator.searchStore.isRebuildingIndex {
                    ProgressView("Searching")
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, maxHeight: resultsHeight)
                } else {
                    ContentUnavailableView.search(text: coordinator.query)
                        .frame(maxWidth: .infinity, maxHeight: resultsHeight)
                }
            } else {
                resultList
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: resultsHeight)
    }

    private var resultList: some View {
        SearchResultList(
            results: coordinator.searchStore.results,
            selectedRowID: coordinator.selectedRowID,
            height: resultsHeight,
            rowMetrics: rowMetrics,
            listMetrics: listMetrics,
            select: { row in
                coordinator.selectedRowID = row.id
            },
            openSelectedResult: openSelectedResult
        )
    }

    private var rowMetrics: SearchResultRowMetrics {
        SearchResultRowMetrics(
            height: 66,
            cornerRadius: 16,
            spacing: 14,
            textSpacing: 3,
            horizontalPadding: 18,
            verticalPadding: 8,
            iconSize: 42,
            iconFont: .system(size: 24, weight: .regular),
            titleFont: .headline.weight(.semibold),
            subtitleFont: .subheadline
        )
    }

    private var listMetrics: SearchResultListMetrics {
        SearchResultListMetrics(
            sectionHeaderFont: .headline.weight(.semibold),
            sectionHorizontalPadding: 26,
            sectionTopPadding: 11,
            sectionBottomPadding: 6,
            rowHorizontalPadding: 14,
            rowVerticalPadding: 4,
            footerFont: .callout,
            footerHorizontalPadding: 24,
            footerVerticalPadding: 12,
            bottomInset: Self.resultsBottomInset,
            showsScrollIndicators: true
        )
    }

    private var showsResultsContent: Bool {
        !SidebarSearchIndex.normalize(coordinator.query).isEmpty
    }

    private var paletteHeight: CGFloat {
        Self.searchHeaderHeight + 1 + (showsResultsContent ? resultsHeight : Self.idleContentHeight)
    }

    private var resultsHeight: CGFloat {
        guard showsResultsContent else { return 0 }

        let maximumResultsHeight = Self.maximumHeight - Self.searchHeaderHeight - 1
        let results = coordinator.searchStore.results
        guard !results.isEmpty else { return min(Self.statusHeight, maximumResultsHeight) }

        let sectionCount = results.sections.count
        let footerHeight = results.isTruncated ? Self.footerHeight : 0
        let naturalResultsHeight = CGFloat(results.flattenedRows.count) * Self.resultRowHeight
            + CGFloat(sectionCount) * Self.sectionHeaderHeight
            + footerHeight
            + Self.resultsBottomInset

        return min(naturalResultsHeight, maximumResultsHeight)
    }

    private func searchHeader(query: Binding<String>) -> some View {
        HStack(spacing: 16) {
            Image(systemSymbol: .magnifyingglass)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(.white.opacity(0.76))

            TextField(text: query, prompt: Text("Search Documentation").foregroundStyle(.white.opacity(0.58))) {
                EmptyView()
            }
                .textFieldStyle(.plain)
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isSearchFocused)
                .onSubmit(openSelectedResult)
                .accessibilityLabel("Search Documentation")
                .accessibilityHint("Search documentation.")

            if !query.wrappedValue.isEmpty {
                Button {
                    query.wrappedValue = ""
                } label: {
                    Image(systemSymbol: .xmarkCircleFill)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .font(.system(size: 25, weight: .regular))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .accessibilityLabel("Clear Search")
            }
        }
        .padding(.horizontal, 24)
        .frame(height: Self.searchHeaderHeight)
    }

    private func appear() {
        focusSearchField()
        coordinator.rebuildIndex(documentationViewModel: documentationViewModel)
        coordinator.updateQuery(coordinator.query)
    }

    private func openSelectedResult() {
        guard coordinator.openSelectedResult(documentationViewModel: documentationViewModel, openURL: openURL) else {
            return
        }

        dismiss()
    }

    private func focusSearchField() {
        isSearchFocused = true
        Task { @MainActor in
            await Task.yield()
            isSearchFocused = true
        }
    }
}
#endif
