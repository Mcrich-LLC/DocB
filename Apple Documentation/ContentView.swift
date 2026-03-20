//
//  ContentView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/5/24.
//

import SwiftUI
import HighlightSwift
import SwiftData

struct ContentView: View {
    let url: URL?
    
    @Environment(DocumentationViewModel.self) var documentationViewModel
    @Environment(AppSettings.self) var appSettings
    @State var navigationViewModel = NavigationViewModel()
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.modelContext) var modelContext
    @Environment(\.openWindow) var openWindow
    @Environment(\.supportsMultipleWindows) var supportsMultipleWindows
    @Query var docCSites: [DocCSite]
    
    var navigationTint: Color? {
        guard let lastNavigationItem = navigationViewModel.path.last else { return nil }
        
        switch lastNavigationItem {
        case .reference(let ref):
            return ref.role?.accentColor
        case .technology:
            return nil
        case .homepage:
            return nil
        case .bookmarks:
            return nil
        }
    }
    
    var body: some View {
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
    
    @ViewBuilder
    var navigationSplitView: some View {
        NavigationSplitView(columnVisibility: $navigationViewModel.splitViewColumnVisibility) {
            Group {
                if let selectedTechnology = navigationViewModel.technology, navigationViewModel.isShowingTechnology {
                    TechnologyRootView(frameworkSection: selectedTechnology)
                        .transition(.move(edge: .trailing))
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Back", systemImage: "chevron.left") {
                                    withAnimation(.snappy) {
                                        navigationViewModel.isShowingTechnology = false
                                    }
                                }
                                .labelStyle(.titleAndIcon)
                            }
                        }
                } else {
                    TechView()
                        .transition(.move(edge: .leading))
                }
            }
            .animation(.default, value: navigationViewModel.isShowingTechnology)
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
                }
            }
            .frame(minWidth: 150, minHeight: 150)
            .accentColor(Color.accentColor)
        }
        .accentColor(navigationTint)
        .frame(minWidth: minWindowFrame?.width, minHeight: minWindowFrame?.height)
    }
    
    @ViewBuilder
    var navigationStackView: some View {
        NavigationStack(path: $navigationViewModel.path) {
            Group {
                TechView()
            }
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
                    case .bookmarks:
                        BookmarkCollectionsView()
                    }
                }
            }
        }
        .accentColor(navigationTint)
    }
}
    
private struct TechView: View {
    @State var searchText = ""
    @State private var errorAlert: Error?
    @Environment(DocumentationViewModel.self) private var documentationViewModel
    @Environment(NavigationViewModel.self) private var navigationViewModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DocCSite.timestamp) var docCSites: [DocCSite]
    
    // Add Documentation Alert
    @State var showAddDocumentationAlert = false
    @State var addDocumentationUrl: String = ""
    
    func isVisibleForSearch(_ interfaceLanguage: DocCIndex.InterfaceLanguage, site: DocCSiteDTO, group: DocCIndex.InterfaceLanguage) -> Bool {
        guard let frameworkSection = group.frameworkSection(for: interfaceLanguage, site: site) else {
            return false
        }
        
        return isVisibleForSearch(frameworkSection)
    }
    
    func isVisibleForSearch(_ site: DocCSiteDTO) -> Bool {
        return !site.allFrameworkSections.filter(isVisibleForSearch).isEmpty
    }
    
    func isVisibleForSearch(_ technology: AppleTechnologies.FrameworkSection) -> Bool {
        guard !searchText.isEmpty else { return true }
        
        return technology.title.lowercased().contains(searchText.lowercased()) || technology.tags.contains(searchText)
    }
    
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
            if docCSites.isEmpty && searchText.isEmpty {
                ContentUnavailableView {
                    Label("No Docs Have Been Added", systemSymbol: .questionmarkFolderFill)
                }
                .listRowSeparator(.hidden)
            } else if !searchText.isEmpty {
                searchList
            } else if searchHasResults {
                technoloigesList
            } else {
                ContentUnavailableView.search(text: searchText)
            }
        }
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
        .navigationTitle("Documentation")
        #endif
        .toolbar {
            Button(action: showAddDocumentationView) {
                Image(systemSymbol: .plus)
            }
            
            Button {
                navigationViewModel.appendPath(.bookmarks)
            } label: {
                Label("Open Bookmarks", systemSymbol: .folder)
            }
        }
        .sheet(isPresented: $showAddDocumentationAlert, content: {
            AddTechnologySheetView()
        })
        .alert(for: $errorAlert)
    }
    
    private func showAddDocumentationView() {
        #if os(macOS)
        openWindow(id: WindowTypes.addSites)
        #else
        showAddDocumentationAlert.toggle()
        #endif
    }
    
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
    
    @ViewBuilder
    private var technoloigesList: some View {
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

private struct InterfaceLanguageSearchListing: View {
    let searchText: String
    let interfaceLanguage: DocCSite.InterfaceLanguageModel
    
    @Environment(DocumentationViewModel.self) var documentationViewModel
    
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

private struct DocCTechView: View {
    let technology: DocCSiteDTO
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

private struct AppleTechView: View {
    let technology: AppleTechnologies
    let isVisibleForSearch: (_ technology: AppleTechnologies.FrameworkSection) -> Bool
    let searchText: String
    @Environment(NavigationViewModel.self) var navigationViewModel
    @Environment(DocumentationViewModel.self) var documentationViewModel
    @Environment(\.modelContext) var modelContext
    @State var errorAlert: Error?
    
    var body: some View {
        internalBody
            .alert(for: $errorAlert)
    }
    
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

private struct ListItemLabel: View {
    let framework: AppleTechnologies.FrameworkSection
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
