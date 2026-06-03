import SwiftUI
import DocCKit
import FactoryKit
import Observation

/// Coordinates Search Documentation palette state and navigation.
@MainActor
@Observable
public final class OpenQuicklySearchCoordinator {
    @ObservationIgnored @Injected(\.documentationViewModel) private var documentationViewModel
    @ObservationIgnored @Injected(\.sidebarSearchIndexCache) private var searchIndexCache

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

        if let searchIndexPreparationPhase {
            return searchIndexPreparationPhase.title
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
        if searchStore.isRebuildingIndex {
            return searchStore.indexBuildProgress ?? SearchIndexInstallProgress.cacheLookup
        }

        if let warmedIndexBuildProgress {
            return warmedIndexBuildProgress
        }

        if isLoadingSearchIndexSnapshot {
            return SearchIndexInstallProgress.presentation
        }

        if isWaitingForSearchSources {
            return SearchIndexInstallProgress.waitingForSources
        }

        return nil
    }
    
    private weak var activeNavigationViewModel: NavigationViewModel?
    private var preloadedRowIDs: Set<SidebarSearchResultRow.ID> = []
    private var indexedSourceFingerprint: String?
    private var warmedSourceFingerprint: String?
    private var warmedIndexFingerprint: String?
    private var warmedIndex: SidebarSearchIndex?
    private var shouldInstallWarmedIndex = false
    private var pendingIndexInstallFingerprint: String?
    private var loadingSnapshotFingerprint: String?
    private var warmedIndexBuildProgress: Double?
    private var searchIndexPreparationPhase: SearchIndexPreparationPhase?
    private var hasDeferredIndexRebuild = false
    private var presentationIndexRebuildTask: Task<Void, Never>?
    private var presentationIndexRebuildFingerprint: String?
    private var indexWarmTask: Task<Void, Never>?
    private var indexWarmRequestID = UUID()
    private var hasLocalIndexCacheFiles = false
    private var hasInstalledSearchIndex: Bool {
        indexedSourceFingerprint != nil && searchStore.hasInstalledIndex
    }

    /// Whether this device has enough memory for retaining a warmed search index in memory.
    public var canRetainWarmedSearchIndexInBackground: Bool {
        SearchPrewarmPolicy.canRetainWarmedSearchIndexInBackground()
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
    
    /// Installs the already prepared search index for the current documentation source snapshot.
    public func rebuildIndex() {
        guard !documentationViewModel.isPreparingSearchSources else {
            hasDeferredIndexRebuild = true
            isWaitingForSearchSources = true
            searchIndexPreparationPhase = .loadingDocumentation
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

        guard loadingSnapshotFingerprint != sourceFingerprint || !shouldInstallWarmedIndex || indexWarmTask == nil else {
            isLoadingSearchIndexSnapshot = true
            searchIndexPreparationPhase = searchIndexPreparationPhase ?? cacheLookupPhase(for: sourceFingerprint)
            return
        }

        if sourceFingerprint.isEmpty {
            clearWarmedIndexState()
            pendingIndexInstallFingerprint = nil
            searchIndexPreparationPhase = nil
            indexedSourceFingerprint = sourceFingerprint
            searchStore.installIndex(.empty, searchDebounce: .milliseconds(0))
            return
        }

        if !installPreparedIndex(for: sourceFingerprint) {
            pendingIndexInstallFingerprint = sourceFingerprint
        }
    }

    /// Starts preparing the local search-index cache in the background when the current source snapshot is not indexed yet.
    public func warmSearchIndexIfNeeded() {
        warmCachedIndexIfNeeded()
    }

    /// Connects the search palette to the coordinator-owned index preparation state.
    ///
    /// The cache lookup and indexing work are started by the app-level background warm job, not palette presentation.
    public func prepareSearchIndexForPalette() {
        let sourceFingerprint = documentationViewModel.searchContentFingerprint
        markSearchIndexPreparationIfNeeded()

        if presentationIndexRebuildFingerprint == sourceFingerprint,
           presentationIndexRebuildTask?.isCancelled == false {
            return
        }

        presentationIndexRebuildTask?.cancel()
        presentationIndexRebuildFingerprint = sourceFingerprint
        presentationIndexRebuildTask = Task { @MainActor in
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }

            rebuildIndex()
            presentationIndexRebuildTask = nil
            presentationIndexRebuildFingerprint = nil
        }
    }

    /// Builds and retains a cached search index in the background, optionally installing it once ready.
    ///
    /// - Parameters:
    ///   - installWhenReady: Whether the warmed index should be installed into palette state.
    ///   - priority: Priority for snapshot loading and index construction.
    private func warmCachedIndexIfNeeded(
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

            searchIndexPreparationPhase = preparationPhase(for: sourceFingerprint, fallback: .loadingLocalIndex)
            warmedIndexBuildProgress = SearchIndexInstallProgress.installingCachedIndex
            installWarmedIndex(warmedIndex, sourceFingerprint: sourceFingerprint)
            return
        }

        if sourceFingerprint == warmedSourceFingerprint,
           let indexWarmTask,
           !indexWarmTask.isCancelled {
            shouldInstallWarmedIndex = shouldInstallWarmedIndex
                || installWhenReady
                || pendingIndexInstallFingerprint == sourceFingerprint
            if shouldInstallWarmedIndex {
                isLoadingSearchIndexSnapshot = true
                loadingSnapshotFingerprint = sourceFingerprint
                searchIndexPreparationPhase = searchIndexPreparationPhase ?? cacheLookupPhase(for: sourceFingerprint)
                warmedIndexBuildProgress = max(
                    warmedIndexBuildProgress ?? 0,
                    SearchIndexInstallProgress.cacheLookup
                )
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
        shouldInstallWarmedIndex = installWhenReady || pendingIndexInstallFingerprint == sourceFingerprint
        if warmedIndexFingerprint != sourceFingerprint {
            warmedIndexFingerprint = nil
            warmedIndex = nil
        }

        if shouldInstallWarmedIndex {
            isLoadingSearchIndexSnapshot = true
            loadingSnapshotFingerprint = sourceFingerprint
            searchIndexPreparationPhase = cacheLookupPhase(for: sourceFingerprint)
            warmedIndexBuildProgress = SearchIndexInstallProgress.cacheLookup
        }

        let requestID = UUID()
        indexWarmRequestID = requestID
        let searchIndexCache = searchIndexCache
        indexWarmTask = Task(priority: priority) {
            if !installWhenReady {
                try? await Task.sleep(for: .milliseconds(1_250))
                guard !Task.isCancelled else { return }
            }

            let hasCacheFiles = await searchIndexCache.containsAnyIndexFiles()
            await MainActor.run {
                guard self.warmedSourceFingerprint == sourceFingerprint,
                      self.indexWarmRequestID == requestID
                else {
                    return
                }

                self.hasLocalIndexCacheFiles = hasCacheFiles
                guard installWhenReady || self.shouldInstallWarmedIndex else { return }

                self.searchIndexPreparationPhase = self.cacheLookupPhase(for: sourceFingerprint)
            }
            guard !Task.isCancelled else { return }

            if let cachedIndex = await searchIndexCache.index(for: sourceFingerprint) {
                await MainActor.run {
                    guard self.warmedSourceFingerprint == sourceFingerprint,
                          self.indexWarmRequestID == requestID
                    else {
                        return
                    }

                    let shouldInstall = installWhenReady || self.shouldInstallWarmedIndex
                    self.searchIndexPreparationPhase = shouldInstall
                        ? self.preparationPhase(for: sourceFingerprint, fallback: .loadingLocalIndex)
                        : nil
                    self.warmedIndexBuildProgress = shouldInstall
                        ? SearchIndexInstallProgress.installingCachedIndex
                        : nil
                    self.finishWarmingIndex(
                        cachedIndex,
                        sourceFingerprint: sourceFingerprint,
                        requestID: requestID
                    )
                }
                return
            }

            await MainActor.run {
                guard self.warmedSourceFingerprint == sourceFingerprint,
                      self.indexWarmRequestID == requestID
                else {
                    return
                }

                let shouldInstall = installWhenReady || self.shouldInstallWarmedIndex
                self.searchIndexPreparationPhase = shouldInstall
                    ? self.preparationPhase(for: sourceFingerprint, fallback: .indexingDocumentation)
                    : nil
                self.warmedIndexBuildProgress = shouldInstall
                    ? SearchIndexInstallProgress.loadingSourceSnapshot
                    : nil
            }

            let technologies = await documentationViewModel.searchTechnologySnapshot()
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard self.warmedSourceFingerprint == sourceFingerprint,
                      self.indexWarmRequestID == requestID
                else {
                    return
                }

                let shouldInstall = installWhenReady || self.shouldInstallWarmedIndex
                self.searchIndexPreparationPhase = shouldInstall
                    ? self.preparationPhase(for: sourceFingerprint, fallback: .indexingDocumentation)
                    : nil
                self.warmedIndexBuildProgress = shouldInstall
                    ? SearchIndexInstallProgress.buildingIndexStart
                    : nil
                self.loadingSnapshotFingerprint = shouldInstall ? sourceFingerprint : self.loadingSnapshotFingerprint
            }

            let progress: @Sendable (Double) -> Void = { value in
                Task { @MainActor in
                    guard self.warmedSourceFingerprint == sourceFingerprint,
                          self.indexWarmRequestID == requestID,
                          self.loadingSnapshotFingerprint == sourceFingerprint,
                          self.warmedIndexBuildProgress != nil,
                          self.shouldInstallWarmedIndex || installWhenReady
                    else {
                        return
                    }

                    self.warmedIndexBuildProgress = SearchIndexInstallProgress.buildingIndexStart
                        + (SearchIndexInstallProgress.buildingIndexRange * min(max(value, 0), 1))
                }
            }

            let index = await Task.detached(priority: priority) {
                SidebarSearchIndex(
                    technologies: technologies,
                    progress: progress
                )
            }.value
            guard !Task.isCancelled else { return }

            if !installWhenReady {
                await Task.detached(priority: priority) {
                    index.prepareStreamingAppleSymbolSearch()
                }.value
                guard !Task.isCancelled else { return }
            }

            await searchIndexCache.store(index, for: sourceFingerprint)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard self.warmedSourceFingerprint == sourceFingerprint,
                      self.indexWarmRequestID == requestID
                else {
                    return
                }

                let shouldInstall = installWhenReady || self.shouldInstallWarmedIndex
                self.warmedIndexBuildProgress = shouldInstall
                    ? SearchIndexInstallProgress.installingBuiltIndex
                    : nil
                self.searchIndexPreparationPhase = shouldInstall
                    ? self.preparationPhase(for: sourceFingerprint, fallback: .indexingDocumentation)
                    : nil
                self.finishWarmingIndex(
                    index,
                    sourceFingerprint: sourceFingerprint,
                    requestID: requestID
                )
            }
        }
    }

    /// Performs a deferred rebuild once documentation sources have finished their initial restore.
    public func rebuildDeferredIndexIfNeeded() {
        guard hasDeferredIndexRebuild || indexedSourceFingerprint == nil else {
            isWaitingForSearchSources = false
            return
        }

        rebuildIndex()
    }

    /// Restores a cached search index after sources finish loading without rebuilding on a cache miss.
    public func restoreCachedIndexIfAvailable() {
        guard !documentationViewModel.isPreparingSearchSources else {
            return
        }

        let sourceFingerprint = documentationViewModel.searchContentFingerprint
        guard !sourceFingerprint.isEmpty, sourceFingerprint != indexedSourceFingerprint else {
            return
        }

        let currentQuery = query
        let searchIndexCache = searchIndexCache
        Task(priority: .utility) {
            guard let cachedIndex = await searchIndexCache.index(for: sourceFingerprint) else {
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
        presentationIndexRebuildFingerprint = nil
        indexWarmTask?.cancel()
        indexWarmTask = nil
        indexWarmRequestID = UUID()
        indexedSourceFingerprint = nil
        clearWarmedIndexState()
        pendingIndexInstallFingerprint = nil
        loadingSnapshotFingerprint = nil
        warmedIndexBuildProgress = nil
        isWaitingForSearchSources = false
        isLoadingSearchIndexSnapshot = false
        searchIndexPreparationPhase = nil
        searchStore.releaseIndex()
    }

    /// Installs a warmed index into palette search state.
    ///
    /// - Parameters:
    ///   - index: Warmed index to install.
    ///   - sourceFingerprint: Fingerprint associated with the warmed index.
    private func installWarmedIndex(_ index: SidebarSearchIndex, sourceFingerprint: String) {
        let preservesExistingResults = searchStore.hasInstalledIndex
        indexedSourceFingerprint = sourceFingerprint
        pendingIndexInstallFingerprint = nil
        clearSnapshotLoadingState(for: sourceFingerprint)
        warmedIndexBuildProgress = nil
        searchIndexPreparationPhase = nil
        searchStore.updateSearchText(query, debounce: .milliseconds(0), preserveExistingResults: preservesExistingResults)
        searchStore.installIndex(
            index,
            searchDebounce: .milliseconds(0),
            preserveExistingResults: preservesExistingResults
        )
    }

    /// Installs or subscribes to an index already prepared by the app-level background warm job.
    ///
    /// - Parameter sourceFingerprint: Source fingerprint required by the palette.
    /// - Returns: `true` when an index was installed or an existing warm job will install it when ready.
    @discardableResult
    private func installPreparedIndex(for sourceFingerprint: String) -> Bool {
        if let warmedIndex, warmedIndexFingerprint == sourceFingerprint {
            searchIndexPreparationPhase = preparationPhase(for: sourceFingerprint, fallback: .loadingLocalIndex)
            warmedIndexBuildProgress = SearchIndexInstallProgress.installingCachedIndex
            installWarmedIndex(warmedIndex, sourceFingerprint: sourceFingerprint)
            return true
        }

        guard warmedSourceFingerprint == sourceFingerprint,
              let indexWarmTask,
              !indexWarmTask.isCancelled
        else {
            return false
        }

        shouldInstallWarmedIndex = true
        pendingIndexInstallFingerprint = nil
        isLoadingSearchIndexSnapshot = true
        loadingSnapshotFingerprint = sourceFingerprint
        searchIndexPreparationPhase = searchIndexPreparationPhase ?? cacheLookupPhase(for: sourceFingerprint)
        warmedIndexBuildProgress = max(
            warmedIndexBuildProgress ?? 0,
            SearchIndexInstallProgress.cacheLookup
        )
        return true
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
        guard shouldInstallWarmedIndex || canRetainWarmedSearchIndexInBackground else {
            clearWarmedIndexState()
            return
        }

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
        searchIndexPreparationPhase = nil
    }

    /// Marks the palette as preparing an index before the delayed rebuild starts.
    private func markSearchIndexPreparationIfNeeded() {
        let sourceFingerprint = documentationViewModel.searchContentFingerprint
        guard indexedSourceFingerprint != sourceFingerprint else {
            return
        }

        if documentationViewModel.isPreparingSearchSources {
            isWaitingForSearchSources = true
            searchIndexPreparationPhase = .loadingDocumentation
            return
        }

        guard !sourceFingerprint.isEmpty else {
            return
        }

        guard warmedIndexFingerprint == sourceFingerprint
            || (warmedSourceFingerprint == sourceFingerprint && indexWarmTask?.isCancelled == false)
        else {
            pendingIndexInstallFingerprint = sourceFingerprint
            return
        }

        let wasAlreadyPreparingThisFingerprint = loadingSnapshotFingerprint == sourceFingerprint
        isLoadingSearchIndexSnapshot = true
        loadingSnapshotFingerprint = sourceFingerprint
        if !wasAlreadyPreparingThisFingerprint || searchIndexPreparationPhase == nil {
            searchIndexPreparationPhase = warmedIndexFingerprint == sourceFingerprint
                ? preparationPhase(for: sourceFingerprint, fallback: .loadingLocalIndex)
                : cacheLookupPhase(for: sourceFingerprint)
        }
        warmedIndexBuildProgress = max(
            warmedIndexBuildProgress ?? SearchIndexInstallProgress.presentation,
            SearchIndexInstallProgress.presentation
        )
    }

    private func preparationPhase(
        for sourceFingerprint: String,
        fallback: SearchIndexPreparationPhase
    ) -> SearchIndexPreparationPhase {
        hasInstalledSearchIndex && indexedSourceFingerprint != sourceFingerprint
            ? .updatingIndex
            : fallback
    }

    private func cacheLookupPhase(for sourceFingerprint: String) -> SearchIndexPreparationPhase {
        preparationPhase(
            for: sourceFingerprint,
            fallback: hasLocalIndexCacheFiles ? .loadingLocalIndex : .indexingDocumentation
        )
    }

    /// Updates the query while preserving the currently selected row when possible.
    ///
    /// - Parameters:
    ///   - query: The raw query entered by the user.
    ///   - debounce: Delay before non-empty queries are evaluated.
    public func updateQuery(_ query: String, debounce: Duration = .milliseconds(80)) {
        guard self.query != query || searchStore.rawSearchText != query else {
            return
        }

        self.query = query
        preloadedRowIDs.removeAll()
        selectedRowID = nil
        searchStore.updateSearchText(query, debounce: debounce)
    }

    /// Starts loading content for a visible result row before the user activates it.
    ///
    /// - Parameter row: Result row that has become visible in the palette.
    public func preloadVisibleResult(_ row: SidebarSearchResultRow) {
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
    ///   - openURL: System URL opener for external destinations.
    /// - Returns: `true` when a result was activated.
    @discardableResult
    public func openSelectedResult(openURL: OpenURLAction) -> Bool {
        guard let selectedRowID,
              let row = searchStore.results.flattenedRows.first(where: { $0.id == selectedRowID })
        else {
            return false
        }
        
        guard activeNavigationViewModel != nil else {
            openResultWithoutActiveWindow?(row)
            return openResultWithoutActiveWindow != nil
        }

        return open(row, openURL: openURL)
    }
    
    /// Opens a search result in the active main window.
    ///
    /// - Parameters:
    ///   - row: Existing search result row payload to activate.
    ///   - openURL: System URL opener for external destinations.
    /// - Returns: `true` when a result was activated.
    @discardableResult
    public func open(_ row: SidebarSearchResultRow, openURL: OpenURLAction) -> Bool {
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

/// Determinate progress checkpoints for installing the Search Documentation index into the palette.
private enum SearchIndexInstallProgress {
    static let waitingForSources = 0.03
    static let presentation = 0.06
    static let cacheLookup = 0.12
    static let loadingSourceSnapshot = 0.24
    static let buildingIndexStart = 0.32
    static let buildingIndexRange = 0.58
    static let installingBuiltIndex = 0.95
    static let installingCachedIndex = 0.85
}

/// User-visible phases for the Search Documentation index preparation status.
private enum SearchIndexPreparationPhase {
    case loadingDocumentation
    case loadingLocalIndex
    case indexingDocumentation
    case updatingIndex

    var title: String {
        switch self {
        case .loadingDocumentation:
            "Loading Documentation"
        case .loadingLocalIndex:
            "Loading Index"
        case .indexingDocumentation:
            "Indexing Documentation"
        case .updatingIndex:
            "Updating Index"
        }
    }
}
