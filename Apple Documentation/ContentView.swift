//
//  ContentView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/5/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject var documentationViewModel = DocumentationViewModel()
    
    var body: some View {
        NavigationStack {
            if let technologies = documentationViewModel.technologies, let headerText = technologies.header?.title {
                techView(technologies)
                    .navigationTitle(headerText)
                    .navigationBarTitleDisplayMode(.large)
            } else {
                Text("Loading...")
            }
        }
        .environmentObject(documentationViewModel)
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
                                NavigationLink(value: technology) {
                                    Text(technology.title)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Framework Navigator
        .navigationDestination(for: Technologies.FrameworkSection.self) { framework in
            TechnologyRootView(frameworkSection: framework)
        }
        
        // Article View
        .navigationDestination(for: Framework.Reference.self) { reference in
            ArticleView(reference: reference)
        }
    }
}

#Preview {
    ContentView()
}
