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
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass != .compact {
                navigationSplitView
            } else {
                navigationStackView
            }
        }
        .environmentObject(documentationViewModel)
        .environmentObject(navigationViewModel)
        .task {
            await documentationViewModel.fetchTechnologies()
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
                                Button("Back", systemImage: "chevron.left") {
                                    withAnimation(.snappy) {
                                        navigationViewModel.technology = nil
                                    }
                                    
                                }
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
        NavigationStack {
            Group {
                if let technologies = documentationViewModel.technologies {
                    techView(technologies)
                        .navigationTitle("Documentation")
                        .navigationBarTitleDisplayMode(.large)
                        .transition(.move(edge: .leading))
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
                ForEach(groups) { group in
                    
                    Section(group.name) {
                        
                        ForEach(group.technologies) { technology in
                            if technology.destination.isActive {
                                if UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass != .compact {
                                    Button {
                                        withAnimation(.snappy) {
                                            navigationViewModel.technology = technology
                                        }
                                        
                                    } label: {
                                        HStack {
                                            Text(technology.title)
                                            
                                            Spacer()
                                            
                                            chevron
                                        }
                                    }
                                    .foregroundStyle(Color.primary)
                                    .background {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .padding(-10)
                                            .foregroundStyle(Color(uiColor: .tertiarySystemFill))
                                            .opacity(navigationViewModel.technology == technology ? 1 : 0)
                                    }
                                } else {
                                    NavigationLink(technology.title, value: technology)
                                        .foregroundStyle(Color.primary)
                                }
                            }
                            
                        }
                    }
                }
            }
            
        }
    }
    
    
    var chevron: some View {
        Image(systemSymbol: .chevronRight)
            .resizable()
            .frame(width: 8, height: 12)
            .foregroundStyle(Color(uiColor: .systemGray3))
    }
}

