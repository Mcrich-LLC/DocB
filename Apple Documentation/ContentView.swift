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
        .background(Color(uiColor: .systemBackground))
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
    
    let urlActionHandler: OpenURLAction = OpenURLAction { url in
            if url.absoluteString.contains("developer.apple.com/documentation"),
               let url = URL(string: url.absoluteString
                .replacingOccurrences(of: "https://", with: Constants.deeplinkScheme)
                .replacingOccurrences(of: "http://", with: Constants.deeplinkScheme)) {
                return .systemAction(url)
            } else if url.scheme == "doc",
                   let url = URL(string: url.absoluteString
                     .replacingOccurrences(of: "doc://", with: Constants.deeplinkScheme)) {
                return .systemAction(url)
            } else {
                return .systemAction
            }
        }
    
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
                            .navigationTitle("Documentation")
                            .navigationBarTitleDisplayMode(.large)
                            .transition(.move(edge: .leading))
                    } else {
                        ProgressView("Loading")
                    }
                }
            }
            .frame(minWidth: 290)
            .navigationSplitViewColumnWidth(min: 290, ideal: 380)
            .shadow(color: .init(uiColor: .separator), radius: 0, x: 0.5)
            .environment(\.horizontalSizeClass, horizontalSizeClass)
        } detail: {
            if let reference = navigationViewModel.reference {
                ArticleView(reference: reference)
            } else if let homepage = documentationViewModel.homepage {
                HomepageView(homepage: homepage)
            }
        }
    }
    
    @ViewBuilder
    var navigationStackView: some View {
        NavigationStack(path: $navigationViewModel.path) {
            Group {
                if let technologies = documentationViewModel.technologies {
                    techView(technologies)
                        .navigationTitle("Documentation")
                        .navigationBarTitleDisplayMode(.large)
                } else {
                    ProgressView("Loading")
                }
            }
            .shadow(color: .init(uiColor: .separator), radius: 0, x: 0.5)
            .navigationDestination(for: PathElement.self) { element in
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
    
    func techView(_ technology: Technologies) -> some View {
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
                                        TechnologyNavigationLinkButton(technology: framework) {
                                            HStack {
                                                Text(framework.title)
                                                
                                                if let reference = technology.references[framework.destination.identifier] {
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
        .background(Color(uiColor: .systemBackground))
        .searchable(text: $searchText)
    }
    
    func isVisibleForSearch(_ technology: Technologies.FrameworkSection) -> Bool {
        guard !searchText.isEmpty else { return true }
        
        return technology.title.localizedCaseInsensitiveContains(searchText) || technology.tags.contains(searchText)
    }
}
