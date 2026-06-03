//
//  ContentView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/5/24.
//

import SwiftUI
import HighlightSwift
import SwiftData
import DocCKit

/// Root SwiftUI container that wires navigation, deep-link handling, and shared environment state.
///
/// This view keeps a long-lived `NavigationViewModel` in `@State` to preserve navigation history across redraws.
public struct ContentView: View {
    /// Creates the main documentation browsing view.
    ///
    /// - Parameters:
    ///   - url: Optional startup URL used for initial deep-link routing.
    ///   - isSearchPalettePresented: Binding that controls the iPadOS Search Documentation overlay.
    public init(url: URL? = nil, isSearchPalettePresented: Binding<Bool> = .constant(false)) {
        self.url = url
        self._isSearchPalettePresented = isSearchPalettePresented
    }
    
    /// Optional startup URL used for initial deep-link routing.
    let url: URL?
    /// Controls the iPadOS Search Documentation overlay.
    @Binding var isSearchPalettePresented: Bool
    
    @Environment(DocumentationViewModel.self) var documentationViewModel
    @Environment(AppSettings.self) var appSettings
    @Environment(OpenQuicklySearchCoordinator.self) private var openQuicklySearchCoordinator
    @Environment(\.scenePhase) private var scenePhase
    /// Local navigation coordinator preserved for this root scene.
    @State var navigationViewModel = NavigationViewModel()
    /// Preserved search state so it outlives sidebar transitions.
    @State var searchText = ""
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.openWindow) var openWindow
    @Environment(\.supportsMultipleWindows) var supportsMultipleWindows
    /// Persisted DocC sites used for sidebar content and loading.
    @Query var docCSites: [DocCSite]
    
    /// Accent tint derived from the currently selected navigation path element.
    var navigationTint: Color? {
        guard let lastNavigationItem = navigationViewModel.path.last else { return nil }
        
        switch lastNavigationItem {
        case .reference(let ref):
            return ref.role?.accentColor
        case .technology:
            return nil
        case .homepage:
            return nil
        case .bookmarkCollections:
            return nil
        case .bookmark:
            return nil
        }
    }
    
    public var body: some View {
        Group {
            if navigationViewModel.isUsingSplitView {
                navigationSplitView
            } else {
                navigationStackView
            }
        }
        #if os(iOS)
        .overlay {
            searchPaletteOverlay
        }
        #endif
        .background(Color(platformColor: .systemBackground))
        .environment(navigationViewModel)
        .onAppear(perform: {
            navigationViewModel.horizontalSizeClass = horizontalSizeClass
            openQuicklySearchCoordinator.registerActiveNavigationViewModel(navigationViewModel)
            if navigationViewModel.isUsingSplitView {
                navigationViewModel.toggleHomepageInBeginingOfHistory()
            }
        })
        .onDisappear {
            openQuicklySearchCoordinator.unregisterActiveNavigationViewModel(navigationViewModel)
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            
            openQuicklySearchCoordinator.registerActiveNavigationViewModel(navigationViewModel)
        }
        .onChange(of: horizontalSizeClass, {
            navigationViewModel.horizontalSizeClass = horizontalSizeClass
        })
        .onChange(of: navigationViewModel.isUsingSplitView, navigationViewModel.handleIsUsingSplitViewChanged)
        .task {
            guard url == nil || url == URL(string: "doc://") else {
                await navigationViewModel.handleURL(url!, documentationViewModel: documentationViewModel)
                return
            }
        }
        .onChange(of: navigationViewModel.technology, initial: true, { _, newValue in
            self.navigationViewModel.isShowingTechnology = newValue != nil
        })
        .environment(\.openURL, urlActionHandler)
        .docCDeepLinkScheme(navigationViewModel.deepLinkScheme)
        .onOpenURL { url in
            navigationViewModel.handleURL(url, documentationViewModel: documentationViewModel)
        }
    }
    
    #if os(iOS)
    /// iPadOS overlay presentation for the Search Documentation palette.
    @ViewBuilder
    private var searchPaletteOverlay: some View {
        if isSearchPalettePresented {
            ZStack(alignment: .top) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isSearchPalettePresented = false
                    }
                    .accessibilityHidden(true)

                SearchPaletteOverlay()
                    .padding(.top, 84)
                    .customDismiss {
                        isSearchPalettePresented = false
                    }
            }
            .ignoresSafeArea()
        }
    }
    #endif

    /// Normalizes inbound URLs and routes supported DocC links in-app, forwarding unsupported links to the system.
    ///
    /// Links containing `videos`, `tutorials`, or `design` are intentionally opened in the system browser.
    var urlActionHandler: OpenURLAction { OpenURLAction { url in
        guard !url.absoluteString.contains("videos"),
              !url.absoluteString.contains("tutorials"),
              !url.absoluteString.contains("design")
        else {
            guard let url = URL(string: url.absoluteString
                .replacingOccurrences(of: navigationViewModel.deepLinkScheme.urlPrefix, with: "https://")
                .replacingOccurrences(of: "com.apple.documentation", with: "developer.apple.com")) else {
                return .systemAction
            }
            
            return .systemAction(url)
        }
        
        if "\(url.scheme ?? "")://" == navigationViewModel.deepLinkScheme.urlPrefix {
            
            switch appSettings.openInAppDeeplinksInNewWindow {
            case true:
                openWindow(value: url)
                return .handled
            case false:
                navigationViewModel.handleURL(url, documentationViewModel: documentationViewModel)
                return .handled
            }
        } else if url.absoluteString.contains("developer.apple.com/documentation"),
                  let url = URL(string: url.absoluteString
                    .replacingOccurrences(of: "https://", with: navigationViewModel.deepLinkScheme.urlPrefix)
                    .replacingOccurrences(of: "http://", with: navigationViewModel.deepLinkScheme.urlPrefix)) {
            
            switch appSettings.openInAppDeeplinksInNewWindow {
            case true:
                openWindow(value: url)
                return .handled
            case false:
                navigationViewModel.handleURL(url, documentationViewModel: documentationViewModel)
                return .handled
            }
        } else if url.scheme == "doc",
                  let url = URL(string: url.absoluteString
                    .replacingOccurrences(of: "doc://", with: navigationViewModel.deepLinkScheme.urlPrefix)) {
            
            switch appSettings.openInAppDeeplinksInNewWindow {
            case true:
                openWindow(value: url)
                return .handled
            case false:
                navigationViewModel.handleURL(url, documentationViewModel: documentationViewModel)
                return .handled
            }
        } else {
            return .systemAction
        }
    }}
    
    /// Minimum window/frame size guidance based on platform and split-view state.
    private var minWindowFrame: CGSize? {
        #if os(macOS) || targetEnvironment(macCatalyst) || os(visionOS)
        return CGSize(width: navigationViewModel.splitViewColumnVisibility == .detailOnly ? 350 : 700, height: 600)
        #else
        guard supportsMultipleWindows else {
            return nil
        }
        
        return CGSize(width: navigationViewModel.splitViewColumnVisibility == .detailOnly ? 350 : 500, height: 400)
        #endif
    }
    
    /// Sidebar container that switches between technologies and bookmark flows.
    struct SidebarView: View {
        @Environment(NavigationViewModel.self) var navigationViewModel
        @Environment(DocumentationViewModel.self) var documentationViewModel
        @Environment(AppSettings.self) private var appSettings
        @Environment(\.presentSearchPalette) private var presentSearchPalette
        /// Propagated search text for nested TechView.
        @Binding var searchText: String
        /// Passed DocC sites to avoid expensive query instantiation.
        var docCSites: [DocCSite]
        
        /// Binding that maps top-level sidebar presentation to the underlying navigation flags.
        var topLevelBinding: Binding<Bool> {
            Binding {
                navigationViewModel.isShowingTechnology || navigationViewModel.isShowingAllBookmarkCollections
            } set: { newValue in
                guard !newValue else { return }
                
                navigationViewModel.isShowingTechnology = false
                navigationViewModel.isShowingAllBookmarkCollections = false
            }
        }
        
        /// Renders the nested sidebar navigation hierarchy.
        var body: some View {
            @Bindable var navigationViewModel = navigationViewModel
            SidebarNavigationView(isShowingInnerView: topLevelBinding) {
                TechView(
                    searchText: $searchText,
                    docCSites: docCSites
                )
            } innerView: {
                if navigationViewModel.isShowingAllBookmarkCollections {
                    SidebarNavigationView(isShowingInnerView: $navigationViewModel.isShowingBookmarkCollection, unwrapping: navigationViewModel.bookmarkCollection) {
                        BookmarkCollectionsView()
                    } innerView: { collection in
                        BookmarkCollectionNavigationView(collection: collection)
                    }
                } else if let selectedTechnology = navigationViewModel.technology, navigationViewModel.isShowingTechnology {
                    TechnologyRootView(frameworkSection: selectedTechnology)
                        .id(documentationViewModel.preferedProgrammingLanguage)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: presentSearchPalette.callAsFunction) {
                        Label("Search Documentation", systemSymbol: .magnifyingglass)
                    }
                    #if os(macOS)
                    .keyboardShortcut(appSettings.searchKeyboardShortcut)
                    #else
                    .keyboardShortcut(.init("o"), modifiers: [.command, .shift])
                    #endif
                }
            }
        }
    }
    
    /// Split-view navigation presentation used on larger form factors.
    @ViewBuilder
    var navigationSplitView: some View {
        NavigationSplitView(columnVisibility: $navigationViewModel.splitViewColumnVisibility) {
            SidebarView(
                searchText: $searchText,
                docCSites: docCSites
            )
                .frame(minWidth: 290)
                .navigationSplitViewColumnWidth(min: 290, ideal: 380)
                .shadow(color: .init(platformColor: .separator), radius: 0, x: 0.5)
                .environment(\.horizontalSizeClass, horizontalSizeClass)
                .accentColor(Color.accentColor)
        } detail: {
            Group {
                if let reference = navigationViewModel.reference {
                    ArticleView(reference: reference)
                } else if let homepage = documentationViewModel.homepage {
                    HomepageView(homepage: homepage)
                } else {
                    Spacer()
                }
            }
            .toolbar(content: {
                if navigationViewModel.isUsingSplitView {
                    ToolbarItemGroup(placement: .navigation) {
                        Group {
                            Button("Backward", systemImage: "chevron.left") {
                                navigationViewModel.goBackward()
                            }
                            .disabled(!navigationViewModel.previousHistoryExists)
                            
                            Button("Forward", systemImage: "chevron.right") {
                                navigationViewModel.goForward()
                            }
                            .disabled(!navigationViewModel.futureHistoryExists)
                        }
                    }
                }
            })
            .frame(minWidth: 150, minHeight: 150)
            .accentColor(Color.accentColor)
        }
        .accentColor(navigationTint)
        .frame(minWidth: minWindowFrame?.width, minHeight: minWindowFrame?.height)
    }
    
    /// Stack-based navigation presentation used on compact layouts.
    @ViewBuilder
    var navigationStackView: some View {
        NavigationStack(path: $navigationViewModel.path) {
            TechView(
                searchText: $searchText,
                docCSites: docCSites
            )
            .shadow(color: .init(platformColor: .separator), radius: 0, x: 0.5)
            .navigationDestination(for: PathElement.self) { element in
                Group {
                    switch element {
                    case .homepage:
                        if let homepage = documentationViewModel.homepage {
                            HomepageView(homepage: homepage)
                        }
                    case .reference(let reference):
                        ArticleView(reference: reference)
                    case .technology(let technology):
                        TechnologyRootView(frameworkSection: technology)
                            .id(documentationViewModel.preferedProgrammingLanguage)
                    case .bookmarkCollections:
                        BookmarkCollectionsView()
                    case .bookmark(let collection):
                        BookmarkCollectionNavigationView(collection: collection)
                    }
                }
            }
        }
        .accentColor(navigationTint)
    }
}
    
/// Sidebar technology browser with search, add-source actions, and source grouping.
private struct TechView: View {
    /// Sidebar search query for technologies and symbols.
    @Binding var searchText: String
    /// Persisted custom DocC site list, passed from parent to avoid query hit during initialization.
    var docCSites: [DocCSite]
    
    /// Error state surfaced through shared alert helper.
    @State private var errorAlert: Error?
    @Environment(DocumentationViewModel.self) private var documentationViewModel
    @Environment(DocBCloudSyncEngine.self) private var docBCloudSyncEngine
    @Environment(\.openWindow) private var openWindow
    
    // Add Documentation Alert
    /// Controls presentation of add-source UI on non-macOS platforms.
    @State var showAddDocumentationAlert = false
    /// Pending URL string used by add-source alerts/flows.
    @State var addDocumentationUrl: String = ""
    
    /// A boolean that describes if DocB's explicit CloudKit sync engine is active.
    @State private var isCloudKitSyncing = false
    /// Cancellable search coordinator for the sidebar search field.
    @State private var sidebarSearchStore = SidebarSearchStore()
    /// Last documentation source fingerprint indexed by the sidebar search store.
    @State private var indexedSidebarSearchContentFingerprint: SidebarSearchContentFingerprint?
    
    /// Determines visibility of a DocC interface-language item for the current search text.
    func isVisibleForSearch(_ interfaceLanguage: DocCIndex.InterfaceLanguage, site: DocCSource, group: DocCIndex.InterfaceLanguage) -> Bool {
        guard let frameworkSection = group.frameworkSection(for: interfaceLanguage, site: site) else {
            return false
        }
        
        return isVisibleForSearch(frameworkSection)
    }
    
    /// Determines whether a custom DocC site has at least one visible framework for search.
    func isVisibleForSearch(_ site: DocCSource) -> Bool {
        return site.allFrameworkSections.contains(where: isVisibleForSearch)
    }
    
    /// Determines whether a framework section matches current search criteria.
    func isVisibleForSearch(_ technology: AppleTechnologies.FrameworkSection) -> Bool {
        guard !searchText.isEmpty else { return true }
        
        return technology.title.lowercased().contains(searchText.lowercased()) || technology.tags.contains(searchText)
    }
    
    /// Routes a technology source type to its corresponding sidebar section view.
    @ViewBuilder
    func technologyView(for technology: TechnologyTypes) -> some View {
        switch technology {
        case .apple(let technologies):
            AppleTechView(technology: technologies, isVisibleForSearch: isVisibleForSearch, searchText: searchText)
        case .docC(let site):
            DocCTechView(technology: site, isVisibleForSearch: isVisibleForSearch)
        }
    }
    
    /// A UI display tag to show when the data is loading
    private var isLoading: Bool {
        documentationViewModel.technologies.isEmpty && !docCSites.isEmpty
    }

    /// Current loading progress shown while saved documentation sources are restored.
    private var sourceLoadProgress: DocumentationSourceLoadProgress? {
        if let sourceLoadProgress = documentationViewModel.sourceLoadProgress {
            return sourceLoadProgress
        }

        guard documentationViewModel.isPreparingSearchSources || isLoading else {
            return nil
        }

        return DocumentationSourceLoadProgress(
            title: "Loading Documentation",
            detail: "Preparing saved sources",
            completedUnitCount: 0,
            totalUnitCount: 0
        )
    }
    
    @ViewBuilder
    private var syncingView: some View {
        if isCloudKitSyncing {
            HStack {
                Text("Syncing")
                ProgressView()
                #if os(macOS)
                    .scaleEffect(0.5)
                #endif
                    .frame(width: 15, height: 15)
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .padding()
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
            .animation(.default, value: isCloudKitSyncing)
        }
    }
    
    var body: some View {
        let isSearchActive = !SidebarSearchIndex.normalize(searchText).isEmpty
        
        List {
            #if os(macOS) || os(visionOS)
            syncingView
            #else
            if #unavailable(iOS 26), !isLoading {
                syncingView
            }
            #endif
            
            if isSearchActive {
                searchList(sidebarSearchStore.results)
            } else {
                let preparedData = PreparedTechnologyData(
                    technologies: documentationViewModel.technologies,
                    isVisibleForSearch: isVisibleForSearch
                )
                
                if preparedData.isEmpty {
                    ContentUnavailableView {
                        Label("No Docs Have Been Added", systemSymbol: .questionmarkFolderFill)
                    }
                    .listRowSeparator(.hidden)
                } else {
                    technologiesList(preparedData)
                }
            }
        }
        .isDocBCloudKitSyncing($isCloudKitSyncing)
        #if !os(macOS)
        .searchable(text: $searchText)
        #endif
        .onChange(of: searchText, initial: true) { _, newValue in
            sidebarSearchStore.updateSearchText(newValue)
            if !SidebarSearchIndex.normalize(newValue).isEmpty {
                refreshSidebarSearchIndex()
            }
        }
        .onChange(of: sidebarSearchContentFingerprint, initial: true) {
            indexedSidebarSearchContentFingerprint = nil
            if !SidebarSearchIndex.normalize(searchText).isEmpty {
                refreshSidebarSearchIndex()
            }
        }
        .onChange(of: documentationViewModel.isPreparingSearchSources) { _, isPreparingSearchSources in
            guard !isPreparingSearchSources else { return }

            if !SidebarSearchIndex.normalize(searchText).isEmpty {
                refreshSidebarSearchIndex()
            }
        }
        .overlay(content: {
            if let sourceLoadProgress {
                sourceLoadingOverlay(sourceLoadProgress)
            }
        })
        .refreshable {
            await docBCloudSyncEngine.fetchRemoteChanges()
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(Color(platformColor: .systemBackground))
        #if !os(macOS)
        .navigationTitle("DocB")
        #endif
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button(action: showAddDocumentationView) {
                    Image(systemSymbol: .plus)
                }
                AllBookmarkCollectionsNavigationLink {
                    Label("Open Bookmarks", systemSymbol: .folder)
                }
                .labelStyle(.iconOnly)
            }
            #if !(os(macOS) || os(visionOS))
            if #available(iOS 26, *), isCloudKitSyncing, !isLoading {
                ToolbarItem(placement: .largeSubtitle) {
                    HStack {
                        Text("Syncing")
                        ProgressView()
                    }
                    .foregroundStyle(.secondary)
                    .padding([.top, .leading], 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.default, value: isCloudKitSyncing)
                }
            }
            #endif
        }
        .sheet(isPresented: $showAddDocumentationAlert, content: {
            AddTechnologySheetView()
        })
        .alert(for: $errorAlert)
    }

    /// Renders launch progress for restoring saved documentation sources.
    ///
    /// - Parameter progress: Current documentation-source loading progress.
    @ViewBuilder
    private func sourceLoadingOverlay(_ progress: DocumentationSourceLoadProgress) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(progress.title)
                .font(.headline)

            if let fractionCompleted = progress.fractionCompleted {
                ProgressView(value: fractionCompleted)
            } else {
                ProgressView()
            }

            if !progress.detail.isEmpty {
                Text(progress.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .frame(maxWidth: 260, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(radius: 8, y: 2)
        .padding()
    }
    
    /// Cheap source fingerprint used to trigger sidebar search index rebuilds.
    private var sidebarSearchContentFingerprint: SidebarSearchContentFingerprint {
        SidebarSearchContentFingerprint(docCSites: docCSites, technologies: documentationViewModel.technologies)
    }
    
    /// Captures main-actor source snapshots and asks the search store to rebuild off-main.
    @MainActor
    private func refreshSidebarSearchIndex() {
        guard !documentationViewModel.isPreparingSearchSources else {
            return
        }

        let fingerprint = sidebarSearchContentFingerprint
        guard indexedSidebarSearchContentFingerprint != fingerprint else {
            return
        }

        indexedSidebarSearchContentFingerprint = fingerprint
        sidebarSearchStore.rebuildIndex(
            technologies: documentationViewModel.technologySnapshot(),
            searchText: searchText,
            sourceFingerprint: documentationViewModel.searchContentFingerprint
        )
    }
    
    /// Presents add-source UI using platform-appropriate window/sheet behavior.
    private func showAddDocumentationView() {
        #if os(macOS)
        openWindow(id: WindowTypes.addSites)
        #else
        showAddDocumentationAlert.toggle()
        #endif
    }
    
    /// Search-result list for both DocC and Apple technologies.
    @ViewBuilder
    private func searchList(_ results: SidebarSearchResults) -> some View {
        if sidebarSearchStore.isRebuildingIndex {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(sidebarSearchStore.indexBuildTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ProgressView(value: sidebarSearchStore.indexBuildProgress ?? 0)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }

        if results.isEmpty {
            if sidebarSearchStore.isSearching {
                Section {
                    ProgressView("Searching")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            } else {
                ContentUnavailableView.search(text: searchText)
            }
        } else {
            ForEach(results.sections) { section in
                Section(section.title) {
                    ForEach(section.rows) { row in
                        SidebarSearchResultRowView(row: row)
                    }
                }
            }
            
            if results.isTruncated {
                Section {} footer: {
                    Text("Showing the first \(SidebarSearchIndex.defaultResultLimit) matches. Refine your search to narrow the results.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom)
                }
            }
        }
    }
    
    /// Default technology listing grouped by custom and Apple sources.
    @ViewBuilder
    private func technologiesList(_ preparedData: PreparedTechnologyData) -> some View {
        if !preparedData.docCSites.isEmpty && !documentationViewModel.technologies.isEmpty, !preparedData.visibleDocCSites.isEmpty {
            Section {
                ForEach(preparedData.simpleDocCSites) { technology in
                    DocCTechView(technology: technology, isVisibleForSearch: isVisibleForSearch)
                        .contextMenu {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                Task {
                                    do {
                                        try await documentationViewModel.deleteTechnology(.docC(technology))
                                    } catch {
                                        self.errorAlert = error
                                    }
                                }
                            }
                        }
                }
            }
            ForEach(preparedData.groupedDocCSites) { technology in
                Section {
                    DocCTechView(technology: technology, isVisibleForSearch: isVisibleForSearch)
                } header: {
                    Text(technology.overrideName ?? technology.groups.first?.title ?? "Unknown")
                        .contextMenu {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                Task {
                                    do {
                                        try await documentationViewModel.deleteTechnology(.docC(technology))
                                    } catch {
                                        self.errorAlert = error
                                    }
                                }
                            }
                        }
                }
            }
        }
        ForEach(preparedData.nonDocCTechnologies) { technology in
            technologyView(for: technology)
        }
    }
}

/// Precomputed sidebar data that avoids repeating source conversion and filtering across list branches.
@MainActor
private struct PreparedTechnologyData {
    /// Custom DocC sites used for sidebar rendering.
    let docCSites: [DocCSource]
    /// Custom DocC sites that have at least one visible framework.
    let visibleDocCSites: [DocCSource]
    /// Custom DocC sites with a single display group.
    let simpleDocCSites: [DocCSource]
    /// Custom DocC sites that need grouped sections.
    let groupedDocCSites: [DocCSource]
    /// Non-DocC technology entries.
    let nonDocCTechnologies: [TechnologyTypes]
    /// Indicates whether any source data is available.
    let isEmpty: Bool
    
    /// Builds prepared sidebar data for the current search and technology state.
    ///
    /// - Parameters:
    ///   - docCSites: Persisted DocC site models.
    ///   - technologies: Loaded technology sources.
    ///   - isVisibleForSearch: Predicate used for framework filtering.
    init(
        technologies: [TechnologyTypes],
        isVisibleForSearch: (AppleTechnologies.FrameworkSection) -> Bool
    ) {
        let docCSourceValues = technologies.docCSites.sorted { lhs, rhs in
            lhs.timestamp < rhs.timestamp
        }
        let visibleDocCSites = docCSourceValues.filter { site in
            site.allFrameworkSections.contains(where: isVisibleForSearch)
        }
        self.docCSites = docCSourceValues
        self.visibleDocCSites = visibleDocCSites
        
        var simpleDocCSites: [DocCSource] = []
        var groupedDocCSites: [DocCSource] = []
        for site in docCSourceValues {
            let nonSampleCodeGroups = site.nonSampleCodeGroups
            let isSimpleSite = nonSampleCodeGroups.count <= 1
                && (site.overrideName == nil || site.overrideName == nonSampleCodeGroups.first?.title)
            
            if isSimpleSite {
                simpleDocCSites.append(site)
            } else {
                groupedDocCSites.append(site)
            }
        }
        self.simpleDocCSites = simpleDocCSites
        self.groupedDocCSites = groupedDocCSites
        self.nonDocCTechnologies = technologies.filter { !$0.isDocC }
        self.isEmpty = docCSourceValues.isEmpty && nonDocCTechnologies.isEmpty
    }
}

/// Cheap Equatable source signature used to trigger async sidebar search index rebuilds.
private struct SidebarSearchContentFingerprint: Equatable {
    /// Persisted source identities.
    private let persistedSites: [PersistedSiteFingerprint]
    /// Runtime technology identities and loaded DocC index identities.
    private let technologies: [TechnologyFingerprint]
    
    /// Creates a fingerprint from current sidebar source data.
    ///
    /// - Parameters:
    ///   - docCSites: Persisted DocC site models.
    ///   - technologies: Runtime technology values.
    init(docCSites: [DocCSite], technologies: [TechnologyTypes]) {
        self.persistedSites = docCSites.map { PersistedSiteFingerprint(site: $0) }
        self.technologies = technologies.map { TechnologyFingerprint(technology: $0) }
    }
    
    /// Fingerprint for a persisted DocC site.
    private struct PersistedSiteFingerprint: Equatable {
        /// Stable source identifier.
        let id: UUID
        /// Source URL.
        let url: URL?
        /// Optional display override.
        let overrideName: String?
        
        /// Creates a persisted-site fingerprint.
        ///
        /// - Parameter site: Persisted DocC site model.
        init(site: DocCSite) {
            self.id = site.id
            self.url = site.url
            self.overrideName = site.overrideName
        }
    }
    
    /// Fingerprint for a runtime technology value.
    private struct TechnologyFingerprint: Equatable {
        /// Stable technology identifier.
        let id: UUID
        /// Loaded DocC index identity for custom sources.
        let docCIndexID: UUID?
        /// Stable Apple framework grouping signature.
        let appleGroupSignature: String?
        
        /// Creates a runtime technology fingerprint.
        ///
        /// - Parameter technology: Runtime technology value.
        init(technology: TechnologyTypes) {
            switch technology {
            case .apple(let appleTechnologies):
                self.id = appleTechnologies.index?.id ?? UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
                self.docCIndexID = appleTechnologies.index?.id
                self.appleGroupSignature = appleTechnologies.groups?.map { group in
                    let frameworkIdentifiers = group.technologies
                        .map(\.destination.identifier)
                        .joined(separator: ",")
                    return "\(group.name):\(frameworkIdentifiers)"
                }
                .joined(separator: ";")
            case .docC(let site):
                self.id = site.id
                self.docCIndexID = site.index.id
                self.appleGroupSignature = nil
            }
        }
    }
}

/// Flat search-result row renderer for precomputed sidebar matches.
private struct SidebarSearchResultRowView: View {
    /// Precomputed search row payload.
    let row: SidebarSearchResultRow
    @State private var resolvedSymbolKind: SidebarSearchSymbolKind?
    @Environment(DocumentationViewModel.self) private var documentationViewModel
    @Environment(\.docCDeepLinkScheme) private var deepLinkScheme
    
    /// Renders symbol-like text with code styling, otherwise plain text.
    @ViewBuilder
    private func text(_ text: String, type: String) -> some View {
        let role = Role(rawValue: type) ?? .codeListing
        
        if [Role.codeListing, .pseudoSymbol, .restRequestSymbol, .collection, .collectionGroup, .symbol].contains(role) {
            CodeText(text)
                .highlightLanguage(.swift)
                .codeTextColors(.theme(.xcode))
        } else {
            Text(text)
        }
    }
    
    var body: some View {
        Group {
            switch row {
            case .homepage(_, let title):
                HomepageNavigationLinkButton {
                    HStack(spacing: 10) {
                        SearchResultSymbolBadge(row: row, symbolKind: resolvedSymbolKind, size: 22)
                        
                        Text(title)
                        Spacer()
                    }
                }
                .foregroundStyle(Color.primary)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            case .reference(let result):
                ReferenceNavigationLinkButton(reference: result.reference(deepLinkScheme: deepLinkScheme)) {
                    HStack(spacing: 10) {
                        SearchResultSymbolBadge(row: row, symbolKind: resolvedSymbolKind, size: 22)
                        
                        text(result.title, type: result.type)
                    }
                }
                .alwaysShowClosestTechnologyGroup()
                .foregroundStyle(Color.primary)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            case .technology(let result):
                if result.framework.destination.identifier.lowercased().contains("/documentation") {
                    TechnologyNavigationLinkButton(technology: result.framework) {
                        SearchResultTechnologyLabel(result: result, row: row)
                    }
                    .foregroundStyle(Color.primary)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else if let url = URL(string: result.framework.destination.identifier) {
                    MacOSAgnosticLink(destination: url) {
                        SearchResultTechnologyLabel(result: result, row: row)
                    }
                    .foregroundStyle(Color.primary)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
        .task(id: row.id) {
            await resolveSymbolKind()
        }
    }

    @MainActor
    private func resolveSymbolKind() async {
        guard case .reference(let result) = row,
              SearchSymbolResolver.shouldRefine(result.symbolKind)
        else {
            resolvedSymbolKind = nil
            return
        }

        resolvedSymbolKind = await SearchSymbolResolver.refinedSymbolKind(for: result, documentationViewModel: documentationViewModel)
    }
}

/// Label for Apple technology search rows.
private struct SearchResultTechnologyLabel: View {
    /// Technology result payload.
    let result: SidebarSearchTechnologyResult
    /// Search row used for the leading role badge.
    let row: SidebarSearchResultRow
    @Environment(NavigationViewModel.self) var navigationViewModel
    
    var body: some View {
        HStack(spacing: 10) {
            SearchResultSymbolBadge(row: row, size: 22)

            Text(result.title)
            
            if result.badgeReference?.beta == true {
                ArticleBadge(badge: .beta)
            }
            
            if result.badgeReference?.deprecated == true {
                ArticleBadge(badge: .deprecated)
            }
            
            if !navigationViewModel.isUsingSplitView {
                Spacer()
                ChevronView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Sidebar section renderer for custom DocC technology sources.
private struct DocCTechView: View {
    /// Custom DocC site descriptor being rendered.
    let technology: DocCSource
    /// Predicate used to filter visible interface-language children.
    let isVisibleForSearch: (_ interfaceLanguage: DocCIndex.InterfaceLanguage, _ site: DocCSource, _ group: DocCIndex.InterfaceLanguage) -> Bool
    @Environment(DocumentationViewModel.self) var documentationViewModel
    
    var body: some View {
        ForEach(technology.groups) { group in
            let filtered = group.children?.filter { isVisibleForSearch($0, technology, group) } ?? []
            if !filtered.isEmpty, let frameworkSection = group.frameworkSection(for: group, site: technology) {
                TechnologyNavigationLinkButton(technology: frameworkSection) {
                    ListItemLabel(framework: frameworkSection, references: [:])
                }
                .foregroundStyle(Color.primary)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
    }
}

/// Sidebar section renderer for Apple-hosted technology groups.
private struct AppleTechView: View {
    /// Apple technology payload containing groups/references.
    let technology: AppleTechnologies
    /// Visibility filter used by current search context.
    let isVisibleForSearch: (_ technology: AppleTechnologies.FrameworkSection) -> Bool
    /// Current search query.
    let searchText: String
    @Environment(NavigationViewModel.self) var navigationViewModel
    @Environment(DocumentationViewModel.self) var documentationViewModel
    /// Error state for alert presentation.
    @State var errorAlert: Error?
    
    var body: some View {
        internalBody
            .alert(for: $errorAlert)
    }
    
    /// Main Apple technologies listing body, including discover and framework groups.
    @ViewBuilder
    var internalBody: some View {
        let visibleGroups = visibleTechnologyGroups
        
        if searchText.isEmpty || "discover".contains(searchText.lowercased()) {
            Section("Apple Documentation") {
                HomepageNavigationLinkButton {
                    HStack {
                        Text("Discover")
                        
                        if !navigationViewModel.isUsingSplitView {
                            Spacer()
                            ChevronView()
                        }
                    }
                }
                .foregroundStyle(Color.primary)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
                .contextMenu {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        Task {
                            do {
                                try await documentationViewModel.deleteTechnology(.apple(technology))
                            } catch {
                                self.errorAlert = error
                            }
                        }
                    }
                }
            }
        
        if !visibleGroups.isEmpty {
            ForEach(visibleGroups) { group in
                Section(group.name) {
                    ForEach(group.frameworks) { framework in
                        if framework.destination.isActive {
                            Group {
                                if framework.destination.identifier.lowercased().contains("/documentation") {
                                    TechnologyNavigationLinkButton(technology: framework) {
                                        ListItemLabel(framework: framework, references: technology.references)
                                    }
                                } else if let url = URL(string: framework.destination.identifier) {
                                    MacOSAgnosticLink(destination: url) {
                                        ListItemLabel(framework: framework, references: technology.references)
                                    }
                                }
                            }
                            .foregroundStyle(Color.primary)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                }
            }
            Section {} footer: {
                if let legalNotices = technology.legalNotices {
                    DocCLegalNoticesView(legalNotices: legalNotices)
                        .padding(.bottom)
                }
            }
        }
    }
    
    /// Technology groups filtered once for the current search state.
    private var visibleTechnologyGroups: [VisibleAppleTechnologyGroup] {
        (technology.groups ?? []).compactMap { group in
            let frameworks = group.technologies.filter(isVisibleForSearch)
            guard !frameworks.isEmpty else { return nil }
            
            return VisibleAppleTechnologyGroup(id: group.id, name: group.name, frameworks: frameworks)
        }
    }
}

/// Filtered Apple technology group used by the sidebar list.
private struct VisibleAppleTechnologyGroup: Identifiable {
    /// Stable group identifier.
    let id: UUID
    /// Group display name.
    let name: String
    /// Framework rows visible for the current search text.
    let frameworks: [AppleTechnologies.FrameworkSection]
}

/// Standard list row label showing title, icon, and optional selection affordances.
private struct ListItemLabel: View {
    /// Framework metadata rendered in this row label.
    let framework: AppleTechnologies.FrameworkSection
    /// Reference map used for beta/deprecation badges.
    let references: [String: Reference]
    
    @Environment(NavigationViewModel.self) var navigationViewModel
    
    var body: some View {
        HStack {
            Text(framework.title)
            
            if let reference = references[framework.destination.identifier] {
                if reference.beta == true {
                    ArticleBadge(badge: .beta)
                }
                
                if reference.deprecated == true {
                    ArticleBadge(badge: .deprecated)
                }
            }
            
            if !navigationViewModel.isUsingSplitView {
                Spacer()
                ChevronView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
