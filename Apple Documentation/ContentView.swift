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
            if UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass != .compact {
                navigationSplitView
            } else {
                navigationStackView
            }
        }
        .background(Color(uiColor: .systemBackground))
        .environmentObject(documentationViewModel)
        .environmentObject(navigationViewModel)
        .task {
            await documentationViewModel.fetchTechnologies()
        }
        .onOpenURL { url in
            navigationViewModel.handleURL(url, documentationViewModel: documentationViewModel)
        }
    }
    
    @ViewBuilder
    var navigationSplitView: some View {
        NavigationSplitView {
            Group {
                if let selectedTechnology = navigationViewModel.technology {
                    TechnologyRootView(frameworkSection: selectedTechnology)
                        .transition(.move(edge: .trailing))
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("All Technologies", systemImage: "chevron.left") {
                                    withAnimation(.snappy) {
                                        navigationViewModel.technology = nil
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
            .navigationSplitViewColumnWidth(390)
            .shadow(color: .init(uiColor: .separator), radius: 0, x: 0.5)
            .environment(\.horizontalSizeClass, horizontalSizeClass)
        } detail: {
            if let reference = navigationViewModel.reference {
                ArticleView(reference: reference)
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
//            .navigationDestination(item: navigationViewModel.iphoneArticleDestinationBinding) { reference in
//                ArticleView(reference: reference)
//            }
        }
    }
    
    func techView(_ technology: Technologies) -> some View {
        List {
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
                                                
                                                
                                                
                                                if UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass != .compact {
                                                    Spacer()
                                                    chevron
                                                }
                                            }
                                        }
                                        .foregroundStyle(Color.primary)
                                        .listRowBackground(Color.clear)
                                        
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
        .background(colorScheme == .light ? Color.white : Color.black)
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
            .foregroundStyle(Color(uiColor: .systemGray3))
    }
}
