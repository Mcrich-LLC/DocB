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
            if let technologies = documentationViewModel.technologies {
                techView(technologies)
                    .navigationTitle("Documentation")
                    .navigationBarTitleDisplayMode(.large)
            } else {
                ProgressView("Loading")
            }
        } content: {
            if let technology = navigationViewModel.technology {
                TechnologyRootView(frameworkSection: technology)
            }
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
    
    @ViewBuilder
    func techView(_ technology: Technologies) -> some View {
        List {
            if let groups = technology.groups {
                ForEach(groups) { group in
                    
                    Section(group.name) {
                        
                        ForEach(group.technologies) { technology in
                            if technology.destination.isActive {
                                Button {
                                    navigationViewModel.technology = technology
                                } label: {
                                    Text(technology.title)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .background {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .padding(-10)
                                        .foregroundStyle(Color(uiColor: .secondarySystemBackground))
                                }
                            }
                        }
                        
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
