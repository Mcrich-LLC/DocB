//
//  ContentView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/5/24.
//

import SwiftUI
import HighlightSwift
import SwiftData

/// Root SwiftUI container that wires navigation, deep-link handling, and shared environment state.
///
/// This view keeps a long-lived `NavigationViewModel` in `@State` to preserve navigation history across redraws.
public struct ContentView: View {
    public init(url: URL? = nil) {
        self.url = url
    }
    
    /// Optional startup URL used for initial deep-link routing.
    let url: URL?
    
    @Environment(DocumentationViewModel.self) var documentationViewModel
    @Environment(AppSettings.self) var appSettings
    /// Local navigation coordinator preserved for this root scene.
    @State var navigationViewModel = NavigationViewModel()
    /// Preserved search state so it outlives sidebar transitions.
    @State var searchText = ""
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.modelContext) var modelContext
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
        .background(Color(platformColor: .systemBackground))
        .environment(navigationViewModel)
        .onAppear(perform: {
            navigationViewModel.horizontalSizeClass = horizontalSizeClass
            if navigationViewModel.isUsingSplitView {
                navigationViewModel.toggleHomepageInBeginingOfHistory()
            }
        })
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
        .onOpenURL { url in
            navigationViewModel.handleURL(url, documentationViewModel: documentationViewModel)
        }
    }
    
    /// Normalizes inbound URLs and routes supported DocC links in-app, forwarding unsupported links to the system.
    ///
    /// Links containing `videos`, `tutorials`, or `design` are intentionally opened in the system browser.
    var urlActionHandler: OpenURLAction { OpenURLAction { url in
        guard !url.absoluteString.contains("videos"),
              !url.absoluteString.contains("tutorials"),
              !url.absoluteString.contains("design")
        else {
            guard let url = URL(string: url.absoluteString
                .replacingOccurrences(of: "com.Mcrich.Apple-Documentation://", with: "https://")
                .replacingOccurrences(of: "com.apple.documentation", with: "developer.apple.com")) else {
                return .systemAction
            }
            
            return .systemAction(url)
        }
        
        if "\(url.scheme ?? "")://" == Constants.deeplinkScheme {
            
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
                    .replacingOccurrences(of: "https://", with: Constants.deeplinkScheme)
                    .replacingOccurrences(of: "http://", with: Constants.deeplinkScheme)) {
            
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
                    .replacingOccurrences(of: "doc://", with: Constants.deeplinkScheme)) {
            
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
                TechView(searchText: $searchText, docCSites: docCSites)
            } innerView: {
                if navigationViewModel.isShowingAllBookmarkCollections {
                    SidebarNavigationView(isShowingInnerView: $navigationViewModel.isShowingBookmarkCollection, unwrapping: navigationViewModel.bookmarkCollection) {
                        BookmarkCollectionsView()
                    } innerView: { collection in
                        BookmarkCollectionNavigationView(collection: collection)
                    }
                } else if let selectedTechnology = navigationViewModel.technology, navigationViewModel.isShowingTechnology {
                    TechnologyRootView(frameworkSection: selectedTechnology)
                }
            }
        }
    }
    
    /// Split-view navigation presentation used on larger form factors.
    @ViewBuilder
    var navigationSplitView: some View {
        NavigationSplitView(columnVisibility: $navigationViewModel.splitViewColumnVisibility) {
            SidebarView(searchText: $searchText, docCSites: docCSites)
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
            TechView(searchText: $searchText, docCSites: docCSites)
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
    @Environment(\.openWindow) private var openWindow
    @Environment(\.modelContext) private var modelContext
    
    // Add Documentation Alert
    /// Controls presentation of add-source UI on non-macOS platforms.
    @State var showAddDocumentationAlert = false
    /// Pending URL string used by add-source alerts/flows.
    @State var addDocumentationUrl: String = ""
    
    /// A boolean that describes if CoreData is currently syncing with CloudKit
    @State private var isCoreDataSyncing = false
    
    /// Determines visibility of a DocC interface-language item for the current search text.
    func isVisibleForSearch(_ interfaceLanguage: DocCIndex.InterfaceLanguage, site: DocCSiteDTO, group: DocCIndex.InterfaceLanguage) -> Bool {
        guard let frameworkSection = group.frameworkSection(for: interfaceLanguage, site: site) else {
            return false
        }
        
        return isVisibleForSearch(frameworkSection)
    }
    
    /// Determines whether a custom DocC site has at least one visible framework for search.
    func isVisibleForSearch(_ site: DocCSiteDTO) -> Bool {
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
    
    @ViewBuilder
    private var syncingView: some View {
        if isCoreDataSyncing {
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
            .animation(.default, value: isCoreDataSyncing)
        }
    }
    
    var body: some View {
        let preparedData = PreparedTechnologyData(
            searchText: searchText,
            docCSites: docCSites,
            technologies: documentationViewModel.technologies,
            isVisibleForSearch: isVisibleForSearch
        )
        
        List {
            #if os(macOS) || os(visionOS)
            syncingView
            #else
            if #unavailable(iOS 26), !isLoading {
                syncingView
            }
            #endif
            
            if preparedData.isEmpty && searchText.isEmpty {
                ContentUnavailableView {
                    Label("No Docs Have Been Added", systemSymbol: .questionmarkFolderFill)
                }
                .listRowSeparator(.hidden)
            } else {
                if !searchText.isEmpty {
                    searchList(preparedData)
                } else if preparedData.hasSearchResults {
                    technologiesList(preparedData)
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
        .isCoreDataSyncing($isCoreDataSyncing)
        .searchable(text: $searchText)
        .overlay(content: {
            if isLoading {
                ProgressView("Loading")
            }
        })
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
            if #available(iOS 26, *), isCoreDataSyncing, !isLoading {
                ToolbarItem(placement: .largeSubtitle) {
                    HStack {
                        Text("Syncing")
                        ProgressView()
                    }
                    .foregroundStyle(.secondary)
                    .padding([.top, .leading], 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.default, value: isCoreDataSyncing)
                }
            }
            #endif
        }
        .sheet(isPresented: $showAddDocumentationAlert, content: {
            AddTechnologySheetView()
        })
        .alert(for: $errorAlert)
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
    private func searchList(_ preparedData: PreparedTechnologyData) -> some View {
        ForEach(preparedData.searchableDocCSites) { site in
            Section(site.overrideName ?? site.groups.first?.title ?? "Unknown") {
                ForEach(site.index.interfaceLanguages.keys.sorted(), id: \.self) { interfaceLanguage in
                    ForEach(site.index.interfaceLanguages[interfaceLanguage] ?? []) { language in
                        InterfaceLanguageDTOSearchListing(searchText: searchText, interfaceLanguage: language, site: site)
                    }
                }
            }
        }
        ForEach(preparedData.nonDocCTechnologies) { technology in
            technologyView(for: technology)
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
                                do {
                                    try documentationViewModel.deleteTechnology(.docC(technology), modelContext: modelContext)
                                } catch {
                                    self.errorAlert = error
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
                                do {
                                    try documentationViewModel.deleteTechnology(.docC(technology), modelContext: modelContext)
                                } catch {
                                    self.errorAlert = error
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

/// Precomputed sidebar data that avoids repeating DTO conversion and filtering across list branches.
@MainActor
private struct PreparedTechnologyData {
    /// Persisted DocC sites matching the current search text.
    let searchableDocCSites: [DocCSiteDTO]
    /// Custom DocC sites used for sidebar rendering.
    let docCSites: [DocCSiteDTO]
    /// Custom DocC sites that have at least one visible framework.
    let visibleDocCSites: [DocCSiteDTO]
    /// Custom DocC sites with a single display group.
    let simpleDocCSites: [DocCSiteDTO]
    /// Custom DocC sites that need grouped sections.
    let groupedDocCSites: [DocCSiteDTO]
    /// Non-DocC technology entries.
    let nonDocCTechnologies: [TechnologyTypes]
    /// Indicates whether the current search can show at least one row.
    let hasSearchResults: Bool
    /// Indicates whether any source data is available.
    let isEmpty: Bool
    
    /// Builds prepared sidebar data for the current search and technology state.
    ///
    /// - Parameters:
    ///   - searchText: Current sidebar search query.
    ///   - docCSites: Persisted DocC site models.
    ///   - technologies: Loaded technology sources.
    ///   - isVisibleForSearch: Predicate used for framework filtering.
    init(
        searchText: String,
        docCSites: [DocCSite],
        technologies: [TechnologyTypes],
        isVisibleForSearch: (AppleTechnologies.FrameworkSection) -> Bool
    ) {
        let docCSiteDTOs = Self.mergedDocCSites(persistedSites: docCSites.asDTOs, loadedSites: technologies.docCSites)
        let visibleDocCSites = docCSiteDTOs.filter { site in
            site.allFrameworkSections.contains(where: isVisibleForSearch)
        }
        
        self.searchableDocCSites = searchText.isEmpty ? docCSiteDTOs : docCSiteDTOs.filter { site in
            site.groups.contains { interfaceLanguage in
                Self.matchesSearch(interfaceLanguage, searchText: searchText)
            }
        }
        self.docCSites = docCSiteDTOs
        self.visibleDocCSites = visibleDocCSites
        
        var simpleDocCSites: [DocCSiteDTO] = []
        var groupedDocCSites: [DocCSiteDTO] = []
        for site in docCSiteDTOs {
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
        self.isEmpty = docCSiteDTOs.isEmpty && nonDocCTechnologies.isEmpty
        
        guard !searchText.isEmpty else {
            self.hasSearchResults = true
            return
        }
        
        let mappedTech = technologies.flatMap { tech in
            switch tech {
            case .apple(let technologies):
                return (technologies.groups ?? []).flatMap(\.technologies)
            case .docC(let site):
                return site.groups.flatMap { $0.allFrameworkSections(for: site) }
            }
        }
        
        self.hasSearchResults = mappedTech.contains(where: isVisibleForSearch)
    }
    
    /// Merges persisted source records with loaded in-memory sources, preferring loaded indexes.
    ///
    /// - Parameters:
    ///   - persistedSites: Sites reconstructed from SwiftData.
    ///   - loadedSites: Fully loaded in-memory sites.
    /// - Returns: A stable list of merged DocC sites.
    private static func mergedDocCSites(persistedSites: [DocCSiteDTO], loadedSites: [DocCSiteDTO]) -> [DocCSiteDTO] {
        var sitesByURL: [URL: DocCSiteDTO] = [:]
        
        for site in persistedSites {
            sitesByURL[site.url] = site
        }
        for site in loadedSites {
            sitesByURL[site.url] = site
        }
        
        return sitesByURL.values.sorted { lhs, rhs in
            lhs.timestamp < rhs.timestamp
        }
    }
    
    /// Recursively tests an in-memory DocC index node against the current search.
    ///
    /// - Parameters:
    ///   - interfaceLanguage: Index node to inspect.
    ///   - searchText: Search query to match.
    /// - Returns: `true` if this node or a descendant should appear in search.
    private static func matchesSearch(_ interfaceLanguage: DocCIndex.InterfaceLanguage, searchText: String) -> Bool {
        if interfaceLanguage.title.lowercased().contains(searchText.lowercased()) && interfaceLanguage.type.lowercased() != "module" {
            return true
        }
        
        return interfaceLanguage.children?.contains { child in
            matchesSearch(child, searchText: searchText)
        } == true
    }
}

/// Recursive search-result renderer for persisted DocC interface-language nodes.
private struct InterfaceLanguageSearchListing: View {
    /// Current user-entered search text.
    let searchText: String
    /// Interface-language node being rendered recursively.
    let interfaceLanguage: DocCSite.InterfaceLanguageModel
    
    @Environment(DocumentationViewModel.self) var documentationViewModel
    
    /// Synthetic reference used for navigation when a node maps to a known path/type.
    var reference: Reference? {
        guard let path = interfaceLanguage.path, let type = interfaceLanguage.type else {
            return nil
        }
        
        guard let siteModel = try? interfaceLanguage.getSet()?.index?.site,
              let site = documentationViewModel.technologies.docCSites.first(where: { $0.id == siteModel.id }) else {
            return nil
        }
        
        return Reference(title: interfaceLanguage.title, identifier: "\(Constants.deeplinkScheme)nav\(path)", type: type, docCSite: site)
    }
    
    /// Renders symbol-like text with code styling, otherwise plain text.
    @ViewBuilder
    func text(_ text: String) -> some View {
        let role = Role(rawValue: interfaceLanguage.type ?? "") ?? .codeListing
        
        if [Role.codeListing, .pseudoSymbol, .restRequestSymbol, .collection, .collectionGroup, .symbol].contains(role) {
            CodeText(text)
                .highlightLanguage(.swift)
                .codeTextColors(.theme(.xcode))
        } else {
            Text(text)
        }
    }
    
    var body: some View {
        if let title = interfaceLanguage.title, title.lowercased().contains(searchText.lowercased()) {
            if let reference {
                ReferenceNavigationLinkButton(reference: reference) {
                    text(title)
                }
                .alwaysShowClosestTechnologyGroup()
            } else if let path = interfaceLanguage.path, let url = URL(string: "\(Constants.deeplinkScheme)nav\(path)") {
                MacOSAgnosticLink(destination: url) {
                    text(title)
                }
            }
        }
        
        ForEach(interfaceLanguage.children ?? []) { child in
            InterfaceLanguageSearchListing(searchText: searchText, interfaceLanguage: child)
        }
    }
}

/// Recursive search-result renderer for in-memory DocC interface-language nodes.
private struct InterfaceLanguageDTOSearchListing: View {
    /// Current user-entered search text.
    let searchText: String
    /// Interface-language node being rendered recursively.
    let interfaceLanguage: DocCIndex.InterfaceLanguage
    /// Custom DocC site that owns the index node.
    let site: DocCSiteDTO
    
    /// Synthetic reference used for navigation when a node maps to a known path/type.
    var reference: Reference? {
        guard let path = interfaceLanguage.path else {
            return nil
        }
        
        return Reference(
            title: interfaceLanguage.title,
            identifier: "\(Constants.deeplinkScheme)nav\(path)",
            type: interfaceLanguage.type,
            docCSite: site
        )
    }
    
    /// Renders symbol-like text with code styling, otherwise plain text.
    @ViewBuilder
    func text(_ text: String) -> some View {
        let role = Role(rawValue: interfaceLanguage.type) ?? .codeListing
        
        if [Role.codeListing, .pseudoSymbol, .restRequestSymbol, .collection, .collectionGroup, .symbol].contains(role) {
            CodeText(text)
                .highlightLanguage(.swift)
                .codeTextColors(.theme(.xcode))
        } else {
            Text(text)
        }
    }
    
    var body: some View {
        if interfaceLanguage.title.lowercased().contains(searchText.lowercased()) {
            if let reference {
                ReferenceNavigationLinkButton(reference: reference) {
                    text(interfaceLanguage.title)
                }
                .alwaysShowClosestTechnologyGroup()
            } else if let path = interfaceLanguage.path, let url = URL(string: "\(Constants.deeplinkScheme)nav\(path)") {
                MacOSAgnosticLink(destination: url) {
                    text(interfaceLanguage.title)
                }
            }
        }
        
        ForEach(interfaceLanguage.children ?? []) { child in
            InterfaceLanguageDTOSearchListing(searchText: searchText, interfaceLanguage: child, site: site)
        }
    }
}

/// Sidebar section renderer for custom DocC technology sources.
private struct DocCTechView: View {
    /// Custom DocC site descriptor being rendered.
    let technology: DocCSiteDTO
    /// Predicate used to filter visible interface-language children.
    let isVisibleForSearch: (_ interfaceLanguage: DocCIndex.InterfaceLanguage, _ site: DocCSiteDTO, _ group: DocCIndex.InterfaceLanguage) -> Bool
    @Environment(DocumentationViewModel.self) var documentationViewModel
    @Environment(\.modelContext) var modelContext
    
    var body: some View {
        ForEach(technology.groups) { group in
            let filtered = group.children?.filter { isVisibleForSearch($0, technology, group) } ?? []
            if !filtered.isEmpty, var frameworkSection = group.frameworkSection(for: group, site: technology) {
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
    @Environment(\.modelContext) var modelContext
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
                    do {
                        try documentationViewModel.deleteTechnology(.apple(technology), modelContext: modelContext)
                    } catch {
                        self.errorAlert = error
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
                    LegalNoticesView(legalNotices: legalNotices)
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
