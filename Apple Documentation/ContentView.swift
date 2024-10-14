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
                navigationViewModel.addHomepageToHistoryIfEmpty()
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
        .onOpenURL { url in
            navigationViewModel.handleURL(url, documentationViewModel: documentationViewModel)
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
            .navigationDestination(for: Reference.self) { reference in
                ArticleView(reference: reference)
            }
            .navigationDestination(for: Technologies.FrameworkSection.self) { technology in
                TechnologyRootView(frameworkSection: technology)
            }
            .navigationDestination(for: HomepageParser.self) { homepage in
                HomepageView(homepage: homepage)
            }
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
                        
                        if UIDevice.current.userInterfaceIdiom != .phone {
                            Spacer()
                            chevron
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
                                
                                ForEach(filtered) { technology in
                                    if technology.destination.isActive {
                                        TechnologyNavigationLinkButton(technology: technology) {
                                            HStack {
                                                Text(technology.title)
                                                
                                                if technology.tags.contains(where: { $0.lowercased() == "beta" }) {
                                                    ArticleBadge(badge: .beta)
                                                }
                                                
                                                if technology.tags.contains(where: { $0.lowercased() == "deprecated" }) {
                                                    ArticleBadge(badge: .deprecated)
                                                }
                                                
                                                Spacer()
                                                
                                                if UIDevice.current.userInterfaceIdiom != .phone {
                                                    chevron
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
    
    var chevron: some View {
        Image(systemSymbol: .chevronRight)
            .resizable()
            .frame(width: 8, height: 12)
        #if os(visionOS)
            .foregroundStyle(colorScheme == .dark ? Color.primary : Color(uiColor: .systemGray3))
        #else
            .foregroundStyle(Color(uiColor: .systemGray3))
        #endif
    }
}
