import SwiftUI
import DocCKit
import Observation

/// Coordinates macOS Open Quickly search state and navigation.
@MainActor
@Observable
public final class OpenQuicklySearchCoordinator {
    /// Current palette query.
    public var query = ""
    /// Identifier of the currently highlighted result row.
    public var selectedRowID: SidebarSearchResultRow.ID?
    /// Existing asynchronous search store reused by the palette.
    public let searchStore = SidebarSearchStore()
    
    private weak var activeNavigationViewModel: NavigationViewModel?
    
    /// Creates an empty Open Quickly coordinator.
    public init() {}
    
    /// Registers the active main-window navigation model used for result activation.
    ///
    /// - Parameter navigationViewModel: The navigation model for the active document window.
    public func registerActiveNavigationViewModel(_ navigationViewModel: NavigationViewModel) {
        activeNavigationViewModel = navigationViewModel
    }
    
    /// Rebuilds the search index from the current documentation source snapshot.
    ///
    /// - Parameter documentationViewModel: Documentation source model to snapshot for indexing.
    public func rebuildIndex(documentationViewModel: DocumentationViewModel) {
        searchStore.rebuildIndex(technologies: documentationViewModel.technologySnapshot(), searchText: query)
    }
    
    /// Updates the query while preserving the currently selected row when possible.
    ///
    /// - Parameters:
    ///   - query: The raw query entered by the user.
    ///   - debounce: Delay before non-empty queries are evaluated.
    public func updateQuery(_ query: String, debounce: Duration = .milliseconds(80)) {
        self.query = query
        searchStore.updateSearchText(query, debounce: debounce)
    }
    
    /// Ensures that a visible result row is selected.
    public func selectDefaultResultIfNeeded() {
        let rows = searchStore.results.flattenedRows
        guard !rows.isEmpty else {
            selectedRowID = nil
            return
        }
        
        if let selectedRowID, rows.contains(where: { $0.id == selectedRowID }) {
            return
        }
        
        selectedRowID = rows.first?.id
    }
    
    /// Moves the selected row up or down in the visible result set.
    ///
    /// - Parameter direction: Move command direction received from SwiftUI.
    public func moveSelection(_ direction: MoveCommandDirection) {
        let rows = searchStore.results.flattenedRows
        guard !rows.isEmpty else {
            selectedRowID = nil
            return
        }
        
        let currentIndex = selectedRowID.flatMap { id in rows.firstIndex(where: { $0.id == id }) } ?? rows.startIndex
        
        switch direction {
        case .up:
            selectedRowID = rows[max(rows.startIndex, currentIndex - 1)].id
        case .down:
            selectedRowID = rows[min(rows.index(before: rows.endIndex), currentIndex + 1)].id
        default:
            break
        }
    }
    
    /// Opens the currently selected row when one is available.
    ///
    /// - Parameters:
    ///   - documentationViewModel: Documentation model used to resolve article/framework links.
    ///   - openURL: System URL opener for external destinations.
    /// - Returns: `true` when a result was activated.
    @discardableResult
    public func openSelectedResult(documentationViewModel: DocumentationViewModel, openURL: OpenURLAction) -> Bool {
        guard let selectedRowID,
              let row = searchStore.results.flattenedRows.first(where: { $0.id == selectedRowID })
        else {
            return false
        }
        
        return open(row, documentationViewModel: documentationViewModel, openURL: openURL)
    }
    
    /// Opens a search result in the active main window.
    ///
    /// - Parameters:
    ///   - row: Existing search result row payload to activate.
    ///   - documentationViewModel: Documentation model used to resolve article/framework links.
    ///   - openURL: System URL opener for external destinations.
    /// - Returns: `true` when a result was activated.
    @discardableResult
    public func open(_ row: SidebarSearchResultRow, documentationViewModel: DocumentationViewModel, openURL: OpenURLAction) -> Bool {
        guard let activeNavigationViewModel else {
            return false
        }
        
        switch row {
        case .homepage:
            activeNavigationViewModel.showHomepage()
            return true
        case .reference(let result):
            navigateToReference(
                result.reference(deepLinkScheme: activeNavigationViewModel.deepLinkScheme),
                site: result.site,
                navigationViewModel: activeNavigationViewModel,
                documentationViewModel: documentationViewModel,
                openURL: openURL
            )
            return true
        case .technology(let result):
            if result.framework.destination.identifier.lowercased().contains("/documentation") {
                navigateToTechnology(result.framework, navigationViewModel: activeNavigationViewModel)
                return true
            } else if let url = URL(string: result.framework.destination.identifier) {
                openURL(url)
                return true
            }
        }
        
        return false
    }
    
    private func navigateToTechnology(_ technology: AppleTechnologies.FrameworkSection, navigationViewModel: NavigationViewModel) {
        navigationViewModel.technologyHistoryUpdatingIsEnabled = true
        
        withAnimation(.snappy) {
            navigationViewModel.setTechnology(technology)
        }
        
        if navigationViewModel.isUsingSplitView {
            navigationViewModel.setReference(technology.frameworkReference)
        }
    }
    
    private func navigateToReference(
        _ reference: Reference,
        site: DocCSource,
        navigationViewModel: NavigationViewModel,
        documentationViewModel: DocumentationViewModel,
        openURL: OpenURLAction
    ) {
        if let url = reference.externalURL, reference.isExternalReference {
            openURL(url)
            return
        }
        
        for technology in documentationViewModel.technologies {
            switch technology {
            case .apple(let technologies):
                selectAppleTechnology(for: reference, technologies: technologies, navigationViewModel: navigationViewModel)
            case .docC(let site):
                selectClosestDocCTechnology(for: reference, site: site, navigationViewModel: navigationViewModel)
            }
        }
        selectClosestDocCTechnology(for: reference, site: site, navigationViewModel: navigationViewModel)
        
        navigationViewModel.setReference(reference)
    }
    
    private func selectAppleTechnology(
        for reference: Reference,
        technologies: AppleTechnologies,
        navigationViewModel: NavigationViewModel
    ) {
        guard let url = URL(string: reference.identifier),
              let moduleString = Array(url.pathComponents.dropFirst(2)).first,
              let groups = technologies.groups
        else {
            return
        }
        
        let identifier = "\(url.scheme ?? "doc")://\(url.host() ?? "com.apple.Documentation")/documentation/\(moduleString)"
        guard let technologyGroup = groups.first(where: { group in
            group.technologies.contains(where: { $0.destination.identifier == identifier })
        }),
              let technology = technologyGroup.technologies.first(where: { $0.destination.identifier == identifier })
        else {
            return
        }
        
        withAnimation(.snappy) {
            navigationViewModel.setTechnology(technology)
        }
    }
    
    private func selectClosestDocCTechnology(
        for reference: Reference,
        site: DocCSource,
        navigationViewModel: NavigationViewModel
    ) {
        guard let url = URL(string: reference.identifier) else {
            return
        }
        
        let identifier = url.path()
        let groups: [DocCIndex.InterfaceLanguage] = site.index.interfaceLanguages.flatMap(\.value)
        
        for group in groups {
            if group.path?.lowercased() == identifier.lowercased() {
                withAnimation(.snappy) {
                    navigationViewModel.setTechnology(site.frameworkSection(for: group))
                }
                return
            }
            
            if let technologyGroup = group.allChildren.first(where: { candidate in
                (candidate.children ?? []).contains(where: { child in
                    child.path?.lowercased() == identifier.lowercased()
                })
            }) {
                withAnimation(.snappy) {
                    navigationViewModel.setTechnology(site.frameworkSection(for: technologyGroup))
                }
                return
            }
        }
    }
}

/// macOS Open Quickly search palette.
public struct OpenQuicklySearchPalette: View {
    /// Creates the Open Quickly palette view.
    public init() {}
    
    @Environment(OpenQuicklySearchCoordinator.self) private var coordinator
    @Environment(DocumentationViewModel.self) private var documentationViewModel
    @Environment(\.customEnabledDismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @FocusState private var isSearchFocused: Bool
    
    public var body: some View {
        @Bindable var coordinator = coordinator
        
        VStack(spacing: 0) {
            searchHeader(query: $coordinator.query)
            Divider()
            resultsContent
        }
        .frame(width: 660, height: 500)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.separator.opacity(0.38), lineWidth: 1)
        }
        .onAppear {
            isSearchFocused = true
            coordinator.rebuildIndex(documentationViewModel: documentationViewModel)
            coordinator.updateQuery(coordinator.query)
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
        .onMoveCommand(perform: coordinator.moveSelection)
        .onSubmit(openSelectedResult)
        .onKeyPress(.upArrow) {
            coordinator.moveSelection(.up)
            return .handled
        }
        .onKeyPress(.downArrow) {
            coordinator.moveSelection(.down)
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
        .onExitCommand {
            dismiss()
        }
        .accessibilityElement(children: .contain)
    }
    
    private var resultsContent: some View {
        Group {
            if SidebarSearchIndex.normalize(coordinator.query).isEmpty {
                ContentUnavailableView(
                    "Search Documentation",
                    systemImage: "magnifyingglass",
                    description: Text("Type to open a technology or symbol.")
                )
            } else if coordinator.searchStore.results.isEmpty {
                if coordinator.searchStore.isSearching || coordinator.searchStore.isRebuildingIndex {
                    ProgressView("Searching")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView.search(text: coordinator.query)
                }
            } else {
                resultList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var resultList: some View {
        ScrollViewReader { proxy in
            List(selection: Binding(
                get: { coordinator.selectedRowID },
                set: { coordinator.selectedRowID = $0 }
            )) {
                ForEach(coordinator.searchStore.results.sections) { section in
                    Section(section.title) {
                        ForEach(section.rows) { row in
                            OpenQuicklyResultRow(row: row, isSelected: coordinator.selectedRowID == row.id) {
                                coordinator.selectedRowID = row.id
                                openSelectedResult()
                            }
                            .tag(row.id)
                            .id(row.id)
                        }
                    }
                }
                
                if coordinator.searchStore.results.isTruncated {
                    Section {} footer: {
                        Text("Showing the first \(SidebarSearchIndex.defaultResultLimit) of \(coordinator.searchStore.results.totalMatches) matches. Refine your search to narrow the results.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(.clear)
            .onChange(of: coordinator.selectedRowID) { _, newValue in
                guard let newValue else { return }
                
                withAnimation(.snappy) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }
    
    private func searchHeader(query: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(.secondary)
            
            TextField("Search documentation", text: query)
                .textFieldStyle(.plain)
                .font(.system(size: 28, weight: .regular))
                .focused($isSearchFocused)
                .onSubmit(openSelectedResult)
                .accessibilityLabel("Open Quickly")
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
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private func openSelectedResult() {
        guard coordinator.openSelectedResult(documentationViewModel: documentationViewModel, openURL: openURL) else {
            return
        }
        
        dismiss()
    }
}

private struct OpenQuicklyResultRow: View {
    let row: SidebarSearchResultRow
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                icon
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .frame(width: 28, height: 28)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(row.title)
                        .font(.headline)
                        .foregroundStyle(isSelected ? .white : .primary)
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(isSelected ? .white.opacity(0.82) : .secondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 12)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens this documentation result.")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
    
    private var icon: Image {
        switch row {
        case .homepage:
            Image(systemName: "house")
        case .reference(let result):
            switch Role(rawValue: result.type) {
            case .symbol, .pseudoSymbol, .restRequestSymbol:
                Image(systemName: "curlybraces")
            case .collection, .collectionGroup:
                Image(systemName: "square.stack")
            default:
                Image(systemName: "doc.text")
            }
        case .technology:
            Image(systemName: "shippingbox")
        }
    }
    
    private var subtitle: String {
        switch row {
        case .homepage:
            "DocB"
        case .reference(let result):
            result.type.capitalized
        case .technology(let result):
            result.framework.docCSite?.overrideName ?? "Technology"
        }
    }
    
    private var accessibilityLabel: String {
        "\(row.title), \(subtitle)"
    }
}

private extension SidebarSearchResults {
    var flattenedRows: [SidebarSearchResultRow] {
        sections.flatMap(\.rows)
    }
}
