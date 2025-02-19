//
//  ContentView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/5/24.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    
    @EnvironmentObject var documentationViewModel: DocumentationViewModel
    @StateObject var navigationViewModel = NavigationViewModel()
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.modelContext) var modelContext
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
        }
    }
    
    // Add Documentation Alert
    @State var showAddDocumentationAlert = false
    @State var addDocumentationName: String = ""
    @State var addDocumentationUrl: String = ""
    
    var navigationTint: Color? {
        guard let lastNavigationItem = navigationViewModel.path.last else { return nil }
        
        switch lastNavigationItem {
        case .reference(let ref):
            return ref.role?.accentColor
        case .technology:
            return nil
        case .homepage:
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
        .environmentObject(navigationViewModel)
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
            await documentationViewModel.fetchHomepage()
            await documentationViewModel.loadTechnologies(docCSites)
            await documentationViewModel.fetchTechnologies()
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
            
            switch navigationViewModel.openInAppDeeplinksInNewWindow {
            case true:
                return .systemAction(url)
            case false:
                navigationViewModel.handleURL(url, documentationViewModel: documentationViewModel)
                return .handled
            }
        } else if url.absoluteString.contains("developer.apple.com/documentation"),
                  let url = URL(string: url.absoluteString
                    .replacingOccurrences(of: "https://", with: Constants.deeplinkScheme)
                    .replacingOccurrences(of: "http://", with: Constants.deeplinkScheme)) {
            
            switch navigationViewModel.openInAppDeeplinksInNewWindow {
            case true:
                return .systemAction(url)
            case false:
                navigationViewModel.handleURL(url, documentationViewModel: documentationViewModel)
                return .handled
            }
        } else if url.scheme == "doc",
                  let url = URL(string: url.absoluteString
                    .replacingOccurrences(of: "doc://", with: Constants.deeplinkScheme)) {
            
            switch navigationViewModel.openInAppDeeplinksInNewWindow {
            case true:
                return .systemAction(url)
            case false:
                navigationViewModel.handleURL(url, documentationViewModel: documentationViewModel)
                return .handled
            }
        } else {
            return .systemAction
        }
    }}
    
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
        } detail: {
            Group {
                if let reference = navigationViewModel.reference {
                    ArticleView(reference: reference)
                } else if let homepage = documentationViewModel.homepage {
                    HomepageView(homepage: homepage)
                }
            }
            .frame(minWidth: 150, minHeight: 150)
        }
        .accentColor(navigationTint)
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
                    }
                }
            }
        }
        .accentColor(navigationTint)
    }
}
    
private struct TechView: View {
    @State var searchText = ""
    @EnvironmentObject private var documentationViewModel: DocumentationViewModel
    @Environment(\.modelContext) private var modelContext
    
    // Add Documentation Alert
    @State var showAddDocumentationAlert = false
    @State var addDocumentationName: String = ""
    @State var addDocumentationUrl: String = ""
    
    func isVisibleForSearch(_ interfaceLanguage: DocCIndex.InterfaceLanguage, site: DocCSite, group: DocCIndex.InterfaceLanguage) -> Bool {
        guard let frameworkSection = group.frameworkSection(for: interfaceLanguage, site: site) else {
            return false
        }
        
        return isVisibleForSearch(frameworkSection)
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
    
    var body: some View {
        List {
            if searchHasResults {
                ForEach(documentationViewModel.technologies) { technology in
                    switch technology {
                    case .apple(let technologies):
                        AppleTechView(technology: technologies, isVisibleForSearch: isVisibleForSearch, searchText: searchText)
                    case .docC(let site):
                        DocCTechView(technology: site, isVisibleForSearch: isVisibleForSearch)
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("No Results", systemSymbol: .magnifyingglass)
                }
            }
        }
        .overlay(content: {
            if documentationViewModel.technologies.isEmpty {
                ProgressView("Loading")
            }
        })
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(Color(platformColor: .systemBackground))
        .searchable(text: $searchText)
        #if !os(macOS)
        .navigationTitle("Documentation")
        #endif
        .toolbar {
            Button {
                showAddDocumentationAlert.toggle()
            } label: {
                Image(systemSymbol: .plus)
            }
            
        }
        .alert("Add Documentation", isPresented: $showAddDocumentationAlert) {
            TextField("Name", text: $addDocumentationName)
            TextField("URL", text: $addDocumentationUrl)
            Button("Add") {
                Task {
                    defer {
                        self.addDocumentationName = ""
                        self.addDocumentationUrl = ""
                    }
                    var addDocumentationUrl = self.addDocumentationUrl.replacingOccurrences(of: "http://", with: "https://")
                    
                    if !addDocumentationUrl.contains("://") {
                        addDocumentationUrl = "https://\(addDocumentationUrl)"
                    }
                    
                    guard let url = URL(string: addDocumentationUrl),
                          let scheme = url.scheme,
                          let host = url.host
                    else {
                        return
                    }
                    
                    let limitedPath: String
                    
                    if let indexRange = url.path().firstRange(of: "/documentation") {
                        limitedPath = String(url.path().prefix(upTo: indexRange.lowerBound))
                    } else {
                        limitedPath = url.path()
                    }
                    
                    guard let baseUrl = URL(string: "\(scheme)://\(host)\(limitedPath)") else {
                        return
                    }
                    
                    await documentationViewModel.addTechnology(named: addDocumentationName, baseUrl: baseUrl)
                    
                    if let technology = documentationViewModel.technologies.last {
                        switch technology {
                        case .apple(let appleTechnologies):
                            break
                        case .docC(let docCSite):
                            modelContext.insert(docCSite)
                        }
                    }
                }
            }
            Button("Cancel") {}
        }
        
    }
}

private struct DocCTechView: View {
    let technology: DocCSite
    let isVisibleForSearch: (_ interfaceLanguage: DocCIndex.InterfaceLanguage, _ site: DocCSite, _ group: DocCIndex.InterfaceLanguage) -> Bool
    @EnvironmentObject var documentationViewModel: DocumentationViewModel
    @Environment(\.modelContext) var modelContext
    
    var body: some View {
        ForEach(technology.groups) { group in
            let filtered = group.children?.filter { isVisibleForSearch($0, technology, group) } ?? []
            if !filtered.isEmpty {
                Section {
                    //                    let filteredChildren = group.children?.filter { isVisibleForSearch($0, site: technology, group: group) }
                    
                    ForEach(filtered) { framework in
                        Group {
                            if framework.type == "groupMarker" {
                                Text(framework.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                            } else if let path = framework.path, path.lowercased().contains("/documentation"),
                                      let frameworkSection = group.frameworkSection(for: framework, site: technology) {
                                TechnologyNavigationLinkButton(technology: frameworkSection) {
                                    ListItemLabel(framework: frameworkSection, references: [:])
                                }
                            } else if let path = framework.path, let url = URL(string: path), let frameworkSection = group.frameworkSection(for: framework, site: technology) {
                                MacOSAgnosticLink(destination: url) {
                                    ListItemLabel(framework: frameworkSection, references: [:])
                                }
                            }
                        }
                        .foregroundStyle(Color.primary)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                } header: {
                    Text(group.title)
                        .contextMenu {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                modelContext.delete(technology)
                                documentationViewModel.deleteTechnology(technology)
                            }
                        }
                }
            }
        }
    }
}

private struct AppleTechView: View {
    let technology: AppleTechnologies
    let isVisibleForSearch: (_ technology: AppleTechnologies.FrameworkSection) -> Bool
    let searchText: String
    @EnvironmentObject var navigationViewModel: NavigationViewModel
    
    var body: some View {
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
    
    @EnvironmentObject var navigationViewModel: NavigationViewModel
    
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
