//
//  ContentView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/5/24.
//

import SwiftUI

struct ContentView: View {
    
    @StateObject var navigationViewModel = NavigationViewModel()
    @StateObject var documentationViewModel = DocumentationViewModel()
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @State var searchText = ""
    
    var body: some View {
        Group {
            if navigationViewModel.isUsingSplitView {
                navigationSplitView
            } else {
                navigationStackView
            }
        }
        .background(Color(platformColor: .systemBackground))
        .environmentObject(documentationViewModel)
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
            await documentationViewModel.fetchTechnologies()
        }
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
                if let selectedTechnology = navigationViewModel.technology {
                    TechnologyRootView(frameworkSection: selectedTechnology)
                        .transition(.move(edge: .trailing))
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Back", systemImage: "chevron.left") {
                                    withAnimation(.snappy) {
                                        navigationViewModel.setTechnology(nil)
                                    }
                                }
                                .labelStyle(.titleAndIcon)
                            }
                        }
                } else {
                    if let technologies = documentationViewModel.technologies {
                        techView(technologies)
#if !os(macOS)
                            .navigationTitle("Documentation")
                            .navigationBarTitleDisplayMode(.large)
#endif
                            .transition(.move(edge: .leading))
                    } else {
                        ProgressView("Loading")
                    }
                }
            }
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
    }
    
    @ViewBuilder
    var navigationStackView: some View {
        NavigationStack(path: $navigationViewModel.path) {
            Group {
                if let technologies = documentationViewModel.technologies {
                    techView(technologies)
#if !os(macOS)
                        .navigationTitle("Documentation")
                        .navigationBarTitleDisplayMode(.large)
#endif
                } else {
                    ProgressView("Loading")
                }
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
    }
    
    func techView(_ technology: AppleTechnologies) -> some View {
        List {
            Section {
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
                } else {
                    ContentUnavailableView {
                        Label("No Results", systemSymbol: .magnifyingglass)
                    }
                }
                
            }
            
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(Color(platformColor: .systemBackground))
        .searchable(text: $searchText)
    }
    
    func isVisibleForSearch(_ technology: AppleTechnologies.FrameworkSection) -> Bool {
        guard !searchText.isEmpty else { return true }
        
        return technology.title.localizedCaseInsensitiveContains(searchText) || technology.tags.contains(searchText)
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
}
