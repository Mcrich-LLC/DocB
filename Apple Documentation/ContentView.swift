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
            if let technologies = documentationViewModel.technologies {
                techView(technologies)
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
            Section {
                if let header = technology.header {
                    Text(header.title)
                        .font(.largeTitle)
                }
            }
            
            if let groups = technology.groups {
                ForEach(groups) { group in
                    Section(group.name) {
                        ForEach(group.technologies) { technology in
                            NavigationLink(value: technology) {
                                Text(technology.title)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
            }
        }
        .navigationDestination(for: Technologies.FrameworkSection.self) { framework in
            TechnologyRootView(frameworkSection: framework)
        }
    }
}

#Preview {
    ContentView()
}
