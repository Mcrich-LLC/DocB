#if os(macOS)
import SwiftUI
import AppKit

/// macOS Xcode-style Search Documentation palette.
public struct OpenQuicklySearchPalette: View {
    private static let width: CGFloat = 462
    private static let maximumHeight: CGFloat = 400
    private static let cornerRadius: CGFloat = 12
    private static let searchHeaderHeight: CGFloat = 50
    private static let resultRowHeight: CGFloat = 52
    private static let sectionHeaderHeight: CGFloat = 32
    private static let resultsBottomInset: CGFloat = 7
    private static let statusHeight: CGFloat = 132
    private static let footerHeight: CGFloat = 42

    /// Creates the macOS Search Documentation palette view.
    public init() {}

    @Environment(OpenQuicklySearchCoordinator.self) private var coordinator
    @Environment(DocumentationViewModel.self) private var documentationViewModel
    @Environment(\.customEnabledDismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @FocusState private var isSearchFocused: Bool

    public var body: some View {
        @Bindable var coordinator = coordinator

        paletteContent
            .frame(width: Self.width, height: paletteHeight)
            .background(OpenQuicklyWindowSizeReader())
            .onAppear(perform: appear)
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
            .onMoveCommand { direction in
                switch direction {
                case .up:
                    coordinator.moveSelection(by: -1)
                case .down:
                    coordinator.moveSelection(by: 1)
                default:
                    break
                }
            }
            .onExitCommand {
                dismiss()
            }
            .accessibilityElement(children: .contain)
    }

    private var paletteContent: some View {
        VStack(spacing: 0) {
            searchHeader(query: Bindable(coordinator).query)

            if showsResultsContent {
                Divider()
                resultsContent
            }
        }
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .stroke(.separator.opacity(0.42), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 32, y: 18)
    }

    private var resultsContent: some View {
        Group {
            if coordinator.searchStore.results.isEmpty {
                if coordinator.searchStore.isSearching || coordinator.searchStore.isRebuildingIndex {
                    ProgressView("Searching")
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
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                    ForEach(coordinator.searchStore.results.sections) { section in
                        Text(section.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 13)
                            .padding(.top, 7)
                            .padding(.bottom, 4)

                        ForEach(section.rows) { row in
                            SearchResultRow(row: row, isSelected: coordinator.selectedRowID == row.id, metrics: rowMetrics) {
                                coordinator.selectedRowID = row.id
                                openSelectedResult()
                            }
                            .id(row.id)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                        }
                    }

                    if coordinator.searchStore.results.isTruncated {
                        Text("Showing the first \(SidebarSearchIndex.defaultResultLimit) of \(coordinator.searchStore.results.totalMatches) matches. Refine your search to narrow the results.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    }

                    Color.clear
                        .frame(height: Self.resultsBottomInset)
                }
            }
            .background(.clear)
            .scrollIndicators(.hidden)
            .frame(height: resultsHeight)
            .onChange(of: coordinator.selectedRowID) { _, newValue in
                guard let newValue else { return }

                proxy.scrollTo(newValue, anchor: .center)
            }
        }
    }

    private var rowMetrics: SearchResultRowMetrics {
        SearchResultRowMetrics(
            height: 48,
            cornerRadius: 6,
            spacing: 12,
            textSpacing: 2,
            horizontalPadding: 10,
            verticalPadding: 5,
            iconSize: 32,
            iconFont: .system(size: 20, weight: .regular),
            titleFont: .subheadline.weight(.semibold),
            subtitleFont: .caption
        )
    }

    private var showsResultsContent: Bool {
        !SidebarSearchIndex.normalize(coordinator.query).isEmpty
    }

    private var paletteHeight: CGFloat {
        Self.searchHeaderHeight + (showsResultsContent ? 1 + resultsHeight : 0)
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
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(.secondary)

            TextField("Search Documentation", text: query)
                .textFieldStyle(.plain)
                .font(.system(size: 21, weight: .regular))
                .focused($isSearchFocused)
                .onSubmit(openSelectedResult)
                .accessibilityLabel("Search Documentation")
                .accessibilityHint("Search documentation.")

            if !query.wrappedValue.isEmpty {
                Button {
                    query.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear Search")
            }
        }
        .padding(.horizontal, 12)
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

private struct OpenQuicklyWindowSizeReader: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        DispatchQueue.main.async {
            resizeWindow(containing: view)
        }

        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            resizeWindow(containing: view)
        }
    }

    private func resizeWindow(containing view: NSView) {
        guard let window = view.window,
              let contentView = window.contentView else { return }

        let contentSize = contentView.fittingSize
        guard contentSize.width > 0, contentSize.height > 0 else { return }

        let currentFrame = window.frame
        let nextFrame = NSRect(
            x: currentFrame.minX,
            y: currentFrame.maxY - contentSize.height,
            width: contentSize.width,
            height: contentSize.height
        )

        guard abs(currentFrame.width - nextFrame.width) > 0.5
            || abs(currentFrame.height - nextFrame.height) > 0.5 else { return }

        window.setFrame(nextFrame, display: true)
    }
}
#endif
