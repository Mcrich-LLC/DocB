import SwiftUI
import DocCKit
import Observation

/// Coordinates Search Documentation palette state and navigation.
@MainActor
@Observable
public final class OpenQuicklySearchCoordinator {
    /// Current palette query.
    public var query = ""
    /// Identifier of the currently highlighted result row.
    public var selectedRowID: SidebarSearchResultRow.ID?
    /// Existing asynchronous search store reused by the palette.
    public let searchStore = SidebarSearchStore()
    /// Handler invoked when a result is activated before any main window can receive navigation.
    public var openResultWithoutActiveWindow: (@MainActor @Sendable (SidebarSearchResultRow) -> Void)?
    
    private weak var activeNavigationViewModel: NavigationViewModel?
    private var preloadedRowIDs: Set<SidebarSearchResultRow.ID> = []
    
    /// Creates an empty Open Quickly coordinator.
    public init() {}
    
    /// Registers the active main-window navigation model used for result activation.
    ///
    /// - Parameter navigationViewModel: The navigation model for the active document window.
    public func registerActiveNavigationViewModel(_ navigationViewModel: NavigationViewModel) {
        activeNavigationViewModel = navigationViewModel
    }

    /// Clears the active navigation model when its owning window goes away.
    ///
    /// - Parameter navigationViewModel: The navigation model that is no longer active.
    public func unregisterActiveNavigationViewModel(_ navigationViewModel: NavigationViewModel) {
        guard activeNavigationViewModel === navigationViewModel else { return }

        activeNavigationViewModel = nil
    }

    /// Whether a main window navigation model is currently available for result activation.
    public var hasActiveNavigationViewModel: Bool {
        activeNavigationViewModel != nil
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
        preloadedRowIDs.removeAll()
        searchStore.updateSearchText(query, debounce: debounce)
    }

    /// Starts loading content for a visible result row before the user activates it.
    ///
    /// - Parameters:
    ///   - row: Result row that has become visible in the palette.
    ///   - documentationViewModel: Documentation source model used to fetch article or framework payloads.
    public func preloadVisibleResult(_ row: SidebarSearchResultRow, documentationViewModel: DocumentationViewModel) {
        guard preloadedRowIDs.insert(row.id).inserted else { return }

        switch row {
        case .homepage:
            return
        case .reference(let result):
            let reference = result.reference(deepLinkScheme: preloadDeepLinkScheme)
            guard reference.externalURL == nil || !reference.isExternalReference else {
                return
            }

            Task(priority: .utility) {
                _ = try? await documentationViewModel.fetchArticle(for: reference.identifier, site: reference.docCSite)
            }
        case .technology(let result):
            guard result.framework.destination.identifier.lowercased().contains("/documentation") else {
                return
            }

            Task(priority: .utility) {
                await documentationViewModel.fetchFramework(for: result.framework.destination.identifier, site: nil)
            }
        }
    }

    private var preloadDeepLinkScheme: DocCDeepLinkScheme {
        activeNavigationViewModel?.deepLinkScheme
            ?? DocCDeepLinkScheme.mainBundle
            ?? DocCDeepLinkScheme(Constants.deeplinkScheme)
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
    
    /// Moves the selected row by the requested offset in the visible result set.
    ///
    /// - Parameter offset: Signed row offset to apply to the current selection.
    public func moveSelection(by offset: Int) {
        let rows = searchStore.results.flattenedRows
        guard !rows.isEmpty else {
            selectedRowID = nil
            return
        }
        
        let currentIndex = selectedRowID.flatMap { id in rows.firstIndex(where: { $0.id == id }) } ?? rows.startIndex
        let nextIndex = min(max(rows.startIndex, currentIndex + offset), rows.index(before: rows.endIndex))
        selectedRowID = rows[nextIndex].id
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
        
        guard activeNavigationViewModel != nil else {
            openResultWithoutActiveWindow?(row)
            return openResultWithoutActiveWindow != nil
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
        
        #if canImport(AppKit)
        NSApplication.shared.activate()
        #endif
        
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
