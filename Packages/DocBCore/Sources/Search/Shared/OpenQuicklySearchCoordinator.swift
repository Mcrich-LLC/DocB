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
    /// Whether the palette is waiting for saved documentation sources before indexing.
    public private(set) var isWaitingForSearchSources = false
    /// Whether the palette is loading source snapshots for a search-index rebuild.
    public private(set) var isLoadingSearchIndexSnapshot = false

    /// Whether the palette should show search-index loading or rebuild progress.
    public var isPreparingSearchIndex: Bool {
        isWaitingForSearchSources || isLoadingSearchIndexSnapshot || searchStore.isRebuildingIndex
    }

    /// User-facing title for the current search-index preparation phase.
    public var searchIndexStatusTitle: String {
        if searchStore.isRebuildingIndex {
            return searchStore.indexBuildTitle
        }

        if isLoadingSearchIndexSnapshot {
            return "Loading Index"
        }

        if isWaitingForSearchSources {
            return "Loading Documentation"
        }

        return searchStore.indexBuildTitle
    }

    /// Current search-index progress, or `nil` while progress is indeterminate.
    public var searchIndexProgress: Double? {
        searchStore.isRebuildingIndex ? searchStore.indexBuildProgress : warmedIndexBuildProgress
    }
    
    private weak var activeNavigationViewModel: NavigationViewModel?
    private var preloadedRowIDs: Set<SidebarSearchResultRow.ID> = []
    private var indexedSourceFingerprint: String?
    private var warmedSourceFingerprint: String?
    private var warmedIndexFingerprint: String?
    private var warmedIndex: SidebarSearchIndex?
    private var shouldInstallWarmedIndex = false
    private var loadingSnapshotFingerprint: String?
    private var warmedIndexBuildProgress: Double?
    private var hasDeferredIndexRebuild = false
    private var presentationIndexRebuildTask: Task<Void, Never>?
    private var indexWarmTask: Task<Void, Never>?
    private var indexWarmRequestID = UUID()

    /// Whether this device has enough memory for retained background search prewarming.
    public var canPrewarmSearchIndexInBackground: Bool {
        SearchPrewarmPolicy.canPrewarmSearchIndexInBackground()
    }
    
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
        guard !documentationViewModel.isPreparingSearchSources else {
            hasDeferredIndexRebuild = true
            isWaitingForSearchSources = true
            return
        }

        isWaitingForSearchSources = false
        hasDeferredIndexRebuild = false
        let sourceFingerprint = documentationViewModel.searchContentFingerprint
        guard sourceFingerprint != indexedSourceFingerprint else {
            if loadingSnapshotFingerprint != sourceFingerprint {
                clearSnapshotLoadingState(for: sourceFingerprint)
            }
            return
        }

        guard !sourceFingerprint.isEmpty || indexedSourceFingerprint != nil else {
            clearSnapshotLoadingState(for: sourceFingerprint)
            return
        }

        if sourceFingerprint.isEmpty {
            clearWarmedIndexState()
            indexedSourceFingerprint = sourceFingerprint
            searchStore.installIndex(.empty, searchDebounce: .milliseconds(0))
            return
        }

        indexedSourceFingerprint = sourceFingerprint
        warmCachedIndexIfNeeded(
            documentationViewModel: documentationViewModel,
            installWhenReady: true,
            priority: .userInitiated
        )
    }

    /// Starts warming the search index in the background when the current source snapshot is not indexed yet.
    ///
    /// - Parameter documentationViewModel: Documentation source model to snapshot for indexing.
    public func warmSearchIndexIfNeeded(documentationViewModel: DocumentationViewModel) {
        guard canPrewarmSearchIndexInBackground else {
            return
        }

        warmCachedIndexIfNeeded(documentationViewModel: documentationViewModel)
    }

    /// Schedules an index rebuild after the palette has had a chance to present.
    ///
    /// This keeps first presentation responsive when the initial rebuild needs to load the persisted Apple index or
    /// construct a fresh flattened search cache.
    ///
    /// - Parameter documentationViewModel: Documentation source model to snapshot for indexing.
    public func rebuildIndexAfterPresentation(documentationViewModel: DocumentationViewModel) {
        presentationIndexRebuildTask?.cancel()
        presentationIndexRebuildTask = Task { @MainActor in
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }

            rebuildIndex(documentationViewModel: documentationViewModel)
            presentationIndexRebuildTask = nil
        }
    }

    /// Builds and retains a cached search index in the background, optionally installing it once ready.
    ///
    /// - Parameters:
    ///   - documentationViewModel: Documentation source model to snapshot for indexing.
    ///   - installWhenReady: Whether the warmed index should be installed into palette state.
    ///   - priority: Priority for snapshot loading and index construction.
    private func warmCachedIndexIfNeeded(
        documentationViewModel: DocumentationViewModel,
        installWhenReady: Bool = false,
        priority: TaskPriority = .utility
    ) {
        guard !documentationViewModel.isPreparingSearchSources else {
            return
        }

        let sourceFingerprint = documentationViewModel.searchContentFingerprint
        guard !sourceFingerprint.isEmpty else {
            return
        }

        if let warmedIndex, warmedIndexFingerprint == sourceFingerprint {
            guard installWhenReady else { return }

            installWarmedIndex(warmedIndex, sourceFingerprint: sourceFingerprint)
            return
        }

        if sourceFingerprint == warmedSourceFingerprint,
           let indexWarmTask,
           !indexWarmTask.isCancelled {
            shouldInstallWarmedIndex = shouldInstallWarmedIndex || installWhenReady
            if installWhenReady {
                indexedSourceFingerprint = sourceFingerprint
                isLoadingSearchIndexSnapshot = true
                loadingSnapshotFingerprint = sourceFingerprint
            }

            guard priority == .userInitiated else { return }

            indexWarmTask.cancel()
            self.indexWarmTask = nil
        } else if sourceFingerprint != warmedSourceFingerprint || installWhenReady {
            indexWarmTask?.cancel()
        } else {
            return
        }

        warmedSourceFingerprint = sourceFingerprint
        shouldInstallWarmedIndex = installWhenReady
        if warmedIndexFingerprint != sourceFingerprint {
            warmedIndexFingerprint = nil
            warmedIndex = nil
        }

        if installWhenReady {
            indexedSourceFingerprint = sourceFingerprint
            isLoadingSearchIndexSnapshot = true
            loadingSnapshotFingerprint = sourceFingerprint
        }

        let requestID = UUID()
        indexWarmRequestID = requestID
        indexWarmTask = Task(priority: priority) {
            if !installWhenReady {
                try? await Task.sleep(for: .milliseconds(1_250))
                guard !Task.isCancelled else { return }
            }

            if let cachedIndex = await SidebarSearchIndexCache.shared.index(for: sourceFingerprint) {
                await MainActor.run {
                    guard self.warmedSourceFingerprint == sourceFingerprint,
                          self.indexWarmRequestID == requestID
                    else {
                        return
                    }

                    self.finishWarmingIndex(
                        cachedIndex,
                        sourceFingerprint: sourceFingerprint,
                        requestID: requestID
                    )
                }
                return
            }

            let technologies = await documentationViewModel.searchTechnologySnapshot()
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard self.warmedSourceFingerprint == sourceFingerprint,
                      self.indexWarmRequestID == requestID
                else {
                    return
                }

                self.warmedIndexBuildProgress = installWhenReady ? 0 : nil
                self.loadingSnapshotFingerprint = installWhenReady ? sourceFingerprint : self.loadingSnapshotFingerprint
            }

            let progress: @Sendable (Double) -> Void = { value in
                Task { @MainActor in
                    guard self.warmedSourceFingerprint == sourceFingerprint,
                          self.indexWarmRequestID == requestID,
                          self.loadingSnapshotFingerprint == sourceFingerprint,
                          self.warmedIndexBuildProgress != nil
                    else {
                        return
                    }

                    self.warmedIndexBuildProgress = min(max(value, 0), 1)
                }
            }

            let index = await Task.detached(priority: priority) {
                SidebarSearchIndex(
                    technologies: technologies,
                    progress: installWhenReady ? progress : nil
                )
            }.value
            guard !Task.isCancelled else { return }

            if !installWhenReady {
                await Task.detached(priority: priority) {
                    index.prepareStreamingAppleSymbolSearch()
                }.value
                guard !Task.isCancelled else { return }
            }

            await SidebarSearchIndexCache.shared.store(index, for: sourceFingerprint)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard self.warmedSourceFingerprint == sourceFingerprint,
                      self.indexWarmRequestID == requestID
                else {
                    return
                }

                self.finishWarmingIndex(
                    index,
                    sourceFingerprint: sourceFingerprint,
                    requestID: requestID
                )
            }
        }
    }

    /// Performs a deferred rebuild once documentation sources have finished their initial restore.
    ///
    /// - Parameter documentationViewModel: Documentation source model to snapshot for indexing.
    public func rebuildDeferredIndexIfNeeded(documentationViewModel: DocumentationViewModel) {
        guard hasDeferredIndexRebuild || indexedSourceFingerprint == nil else {
            isWaitingForSearchSources = false
            return
        }

        rebuildIndex(documentationViewModel: documentationViewModel)
    }

    /// Restores a cached search index after sources finish loading without rebuilding on a cache miss.
    ///
    /// - Parameter documentationViewModel: Documentation source model that supplies the current fingerprint.
    public func restoreCachedIndexIfAvailable(documentationViewModel: DocumentationViewModel) {
        guard !documentationViewModel.isPreparingSearchSources else {
            return
        }

        let sourceFingerprint = documentationViewModel.searchContentFingerprint
        guard !sourceFingerprint.isEmpty, sourceFingerprint != indexedSourceFingerprint else {
            return
        }

        let currentQuery = query
        Task(priority: .utility) {
            guard let cachedIndex = await SidebarSearchIndexCache.shared.index(for: sourceFingerprint) else {
                return
            }

            await MainActor.run {
                guard sourceFingerprint != self.indexedSourceFingerprint else {
                    return
                }

                self.indexedSourceFingerprint = sourceFingerprint
                self.searchStore.updateSearchText(currentQuery)
                self.searchStore.installIndex(cachedIndex)
            }
        }
    }

    /// Releases retained search index memory while preserving disk caches.
    public func releaseSearchIndexForMemoryPressure() {
        presentationIndexRebuildTask?.cancel()
        presentationIndexRebuildTask = nil
        indexWarmTask?.cancel()
        indexWarmTask = nil
        indexWarmRequestID = UUID()
        indexedSourceFingerprint = nil
        clearWarmedIndexState()
        loadingSnapshotFingerprint = nil
        warmedIndexBuildProgress = nil
        isWaitingForSearchSources = false
        isLoadingSearchIndexSnapshot = false
        searchStore.releaseIndex()
    }

    /// Installs a warmed index into palette search state.
    ///
    /// - Parameters:
    ///   - index: Warmed index to install.
    ///   - sourceFingerprint: Fingerprint associated with the warmed index.
    private func installWarmedIndex(_ index: SidebarSearchIndex, sourceFingerprint: String) {
        indexedSourceFingerprint = sourceFingerprint
        clearSnapshotLoadingState(for: sourceFingerprint)
        warmedIndexBuildProgress = nil
        searchStore.updateSearchText(query, debounce: .milliseconds(0))
        searchStore.installIndex(index, searchDebounce: .milliseconds(0))
    }

    /// Records a warmed index and installs it if a presentation requested it.
    ///
    /// - Parameters:
    ///   - index: Warmed index snapshot.
    ///   - sourceFingerprint: Fingerprint associated with the warmed index.
    ///   - requestID: Request identity for rejecting stale warm completions.
    private func finishWarmingIndex(_ index: SidebarSearchIndex, sourceFingerprint: String, requestID: UUID) {
        guard indexWarmRequestID == requestID else { return }

        warmedIndex = index
        warmedIndexFingerprint = sourceFingerprint
        indexWarmTask = nil
        warmedIndexBuildProgress = nil
        guard shouldInstallWarmedIndex else {
            return
        }

        installWarmedIndex(index, sourceFingerprint: sourceFingerprint)
    }

    /// Clears retained warmed-index state without touching the installed palette index.
    private func clearWarmedIndexState() {
        warmedSourceFingerprint = nil
        warmedIndexFingerprint = nil
        warmedIndex = nil
        shouldInstallWarmedIndex = false
    }

    /// Clears snapshot-loading state for the matching source fingerprint.
    ///
    /// - Parameter sourceFingerprint: Fingerprint for the rebuild request that is no longer loading snapshots.
    private func clearSnapshotLoadingState(for sourceFingerprint: String) {
        guard loadingSnapshotFingerprint == sourceFingerprint else {
            return
        }

        loadingSnapshotFingerprint = nil
        isLoadingSearchIndexSnapshot = false
    }

    /// Updates the query while preserving the currently selected row when possible.
    ///
    /// - Parameters:
    ///   - query: The raw query entered by the user.
    ///   - debounce: Delay before non-empty queries are evaluated.
    public func updateQuery(_ query: String, debounce: Duration = .milliseconds(80)) {
        self.query = query
        preloadedRowIDs.removeAll()
        selectedRowID = nil
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
        } completion: {
            Self.revealSidebarIfNeeded(in: navigationViewModel)
        }
        
        if navigationViewModel.isUsingSplitView {
            navigationViewModel.setReference(technology.frameworkReference)
        }
    }
    
    private func navigateToReference(
        _ reference: Reference,
        site: DocCSource?,
        navigationViewModel: NavigationViewModel,
        documentationViewModel: DocumentationViewModel,
        openURL: OpenURLAction
    ) {
        if let url = reference.externalURL, reference.isExternalReference {
            openURL(url)
            return
        }
        
        if let site {
            selectClosestDocCTechnology(for: reference, site: site, navigationViewModel: navigationViewModel)
        } else if let appleTechnologies = documentationViewModel.technologySnapshot().appleTechnologies.first {
            selectAppleTechnology(for: reference, technologies: appleTechnologies, navigationViewModel: navigationViewModel)
        }
        
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
        
        let identifier = "doc://com.apple.documentation/documentation/\(moduleString)"
        let normalizedIdentifier = identifier.lowercased()
        guard let technologyGroup = groups.first(where: { group in
            group.technologies.contains(where: { $0.destination.identifier.lowercased() == normalizedIdentifier })
        }),
              let technology = technologyGroup.technologies.first(where: { $0.destination.identifier.lowercased() == normalizedIdentifier })
        else {
            return
        }
        
        navigationViewModel.technologyHistoryUpdatingIsEnabled = true
        withAnimation(.snappy) {
            navigationViewModel.setTechnology(technology)
        } completion: {
            Self.revealSidebarIfNeeded(in: navigationViewModel)
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
                navigationViewModel.technologyHistoryUpdatingIsEnabled = true
                withAnimation(.snappy) {
                    navigationViewModel.setTechnology(site.frameworkSection(for: group))
                } completion: {
                    Self.revealSidebarIfNeeded(in: navigationViewModel)
                }
                return
            }
            
            if let technologyGroup = group.allChildren.first(where: { candidate in
                (candidate.children ?? []).contains(where: { child in
                    child.path?.lowercased() == identifier.lowercased()
                })
            }) {
                navigationViewModel.technologyHistoryUpdatingIsEnabled = true
                withAnimation(.snappy) {
                    navigationViewModel.setTechnology(site.frameworkSection(for: technologyGroup))
                } completion: {
                    Self.revealSidebarIfNeeded(in: navigationViewModel)
                }
                return
            }
        }
    }

    private static func revealSidebarIfNeeded(in navigationViewModel: NavigationViewModel) {
        guard navigationViewModel.isUsingSplitView else {
            return
        }

        navigationViewModel.splitViewColumnVisibility = .all
    }
}
