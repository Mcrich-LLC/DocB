//
//  TechnologyRootView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/5/24.
//

import SwiftUI

struct TechnologyRootView: View {
    @EnvironmentObject var documentationViewModel: DocumentationViewModel
    let frameworkSection: Technologies.FrameworkSection
    
    var framework: Framework? {
        documentationViewModel.frameworks[frameworkSection.destination.identifier]
    }
    
    var body: some View {
        VStack {
            if let framework {
                frameworkView(framework)
            } else {
                Text("Loading...")
            }
        }
        .task {
            await documentationViewModel.fetchFramework(for: frameworkSection.destination.identifier)
        }
    }
    
    @ViewBuilder
    func frameworkView(_ framework: Framework) -> some View {
        if framework.topicSections.isEmpty {
            Text("No documentation available for \(framework.metadata.title)")
        } else {
            List {
                ForEach(framework.topicSections) { section in
                    Section(header: Text(section.title)) {
                        ForEach(section.identifiers, id: \.self) { identifier in
                            if let reference = framework.references[identifier], let title = reference.title {
                                if reference.role == .collectionGroup {
                                    
                                    let section = Technologies.FrameworkSection(languages: [], title: title, tags: [], destination: .init(type: reference.type, isActive: true, identifier: identifier))
                                    NavigationLink(title, value: section)
                                } else {
                                    Text(title)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

//#Preview {
//    TechnologyRootView()
//}
