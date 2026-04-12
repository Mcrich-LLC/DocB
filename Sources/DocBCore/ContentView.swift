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
                let _ = print("navigationViewModel.isShowingAllBookmarkCollections: \(navigationViewModel.isShowingAllBookmarkCollections)")
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
        return !site.allFrameworkSections.filter(isVisibleForSearch).isEmpty
    }
    
    /// Determines whether a framework section matches current search criteria.
    func isVisibleForSearch(_ technology: AppleTechnologies.FrameworkSection) -> Bool {
        guard !searchText.isEmpty else { return true }
        
        return technology.title.lowercased().contains(searchText.lowercased()) || technology.tags.contains(searchText)
    }
    
    /// Indicates whether current search has any matching technology results.
    var searchHasResults: Bool {
        guard !searchText.isEmpty else { return true }
        
        let mappedTech = documentationViewModel.technologies.flatMap { tech in
            switch tech {
            case .apple(let technologies):
                return (technologies.groups ?? []).flatMap(\.technologies)
            case .docC(let site):
                return site.groups.flatMap({ $0.allFrameworkSections(for: site) })
            }
        }
        
        let filteredTech = mappedTech.filter({ isVisibleForSearch($0) })
        return !filteredTech.isEmpty
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
    
    var body: some View {
        List {
            if isCoreDataSyncing {
                ContentUnavailableView {
                    ProgressView("Syncing")
                }
            } else if docCSites.isEmpty && searchText.isEmpty {
                ContentUnavailableView {
                    Label("No Docs Have Been Added", systemSymbol: .questionmarkFolderFill)
                }
                .listRowSeparator(.hidden)
            } else if !searchText.isEmpty {
                searchList
            } else if searchHasResults {
                technologiesList
            } else {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .isCoreDataSyncing($isCoreDataSyncing)
        .searchable(text: $searchText)
        .overlay(content: {
            if documentationViewModel.technologies.isEmpty && !docCSites.isEmpty {
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
            Button(action: showAddDocumentationView) {
                Image(systemSymbol: .plus)
            }
            AllBookmarkCollectionsNavigationLink {
                Label("Open Bookmarks", systemSymbol: .folder)
            }
            .labelStyle(.iconOnly)
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
    private var searchList: some View {
        ForEach(docCSites) { site in
            if let index = site.indexV2, site.hasResultsForSearch(searchText) {
                Section(site.overrideName ?? site.groups.first?.title ?? "Unknown") {
                    ForEach(index.interfaceLanguages ?? []) { interface in
                        ForEach(interface.languages ?? []) { language in
                            InterfaceLanguageSearchListing(searchText: searchText, interfaceLanguage: language)
                        }
                    }
                }
            }
        }
        ForEach(documentationViewModel.technologies.filter({ !$0.isDocC })) { technology in
            technologyView(for: technology)
        }
    }
    
    /// Default technology listing grouped by custom and Apple sources.
    @ViewBuilder
    private var technologiesList: some View {
        if !docCSites.isEmpty && !documentationViewModel.technologies.isEmpty, !docCSites.asDTOs.filter(isVisibleForSearch).isEmpty {
            Section {
                ForEach(docCSites.asDTOs.filter({ $0.nonSampleCodeGroups.count <= 1  && ($0.overrideName == nil || $0.overrideName == $0.nonSampleCodeGroups.first?.title) })) { technology in
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
            ForEach(docCSites.asDTOs.filter({ $0.nonSampleCodeGroups.count > 1 || !($0.overrideName == nil || $0.overrideName == $0.nonSampleCodeGroups.first?.title) })) { technology in
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
        ForEach(documentationViewModel.technologies.filter({ !$0.isDocC })) { technology in
            technologyView(for: technology)
        }
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
        
        if let groups = technology.groups {
            
            let filtered = groups.flatMap { $0.technologies.filter(isVisibleForSearch) }
            
            if !filtered.isEmpty {
                ForEach(groups) { group in
                    
                    let filtered = group.technologies.filter(isVisibleForSearch)
                    
                    if !filtered.isEmpty {
                        Section(group.name) {
                            
                            ForEach(filtered) { framework in
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
                }
                Section {} footer: {
                    if let legalNotices = technology.legalNotices {
                        LegalNoticesView(legalNotices: legalNotices)
                            .padding(.bottom)
                    }
                }
            }
            
        }
    }
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
        .contentShape(Rectangle())
    }
}
