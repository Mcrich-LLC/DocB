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
    
    var body: some View {
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
            
            
        } detail: {
            if let reference = navigationViewModel.reference {
                ArticleView(reference: reference)
            }
        }
        .environmentObject(documentationViewModel)
        .environmentObject(navigationViewModel)
        .task {
            await documentationViewModel.fetchTechnologies()
        }
    }
    
    func techView(_ technology: Technologies) -> some View {
        List {
            if let groups = technology.groups {
                ForEach(groups) { group in
                    
                    Section(group.name) {
                        
                        ForEach(group.technologies) { technology in
                            if technology.destination.isActive {
                                Button {
                                    withAnimation(.snappy) {
                                        navigationViewModel.technology = technology
                                    }
                                    
                                } label: {
                                    Text(technology.title)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .background {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .padding(-10)
                                        .foregroundStyle(Color(uiColor: .tertiarySystemFill))
                                        .opacity(navigationViewModel.technology == technology ? 1 : 0)
                                }
                            }
                            
                        }
                    }
                }
            }
            
        }
    }
}

