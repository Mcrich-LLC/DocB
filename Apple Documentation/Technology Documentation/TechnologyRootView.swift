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
        .navigationTitle(frameworkSection.title)
        .navigationBarTitleDisplayMode(.large)
        .task {
            if framework == nil {
                await documentationViewModel.fetchFramework(for: frameworkSection.destination.identifier)
            }
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
                                    FrameworkDisclosureGroup(identifier: identifier, title: title)
                                } else if let urlString = reference.url, !urlString.hasPrefix("/documentation"), let url = URL(string: "https://developer.apple.com\(urlString)") {
                                    Link(destination: url) {
                                        HStack {
                                            Text(title)
                                                .foregroundStyle(Color.primary)
                                                
                                            Spacer()
                                            
                                            Image(systemName: "link")
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(height: 15)
                                                .bold()
                                                .foregroundStyle(Color.accentColor)
                                        }
                                    }
                                } else {
                                    NavigationLink(title, value: reference)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct FrameworkDisclosureGroup: View {
    @EnvironmentObject var documentationViewModel: DocumentationViewModel
    let identifier: String
    let title: String
    
    var framework: Framework? { documentationViewModel.frameworks[identifier] }
    
    var body: some View {
        DisclosureGroup(title) {
            if let framework {
                ForEach(framework.topicSections) { section in
                    ForEach(section.identifiers, id: \.self) { subidentifier in
                        if let subreference = framework.references[subidentifier], let subtitle = subreference.title {
                            if subreference.role == .collectionGroup {
                                FrameworkDisclosureGroup(identifier: subidentifier, title: subtitle)
                            } else {
                                Text(subtitle)
                            }
                        }
                    }
                }
            }
        }
        .task {
            if framework == nil {
                await documentationViewModel.fetchFramework(for: identifier)
            }
        }
    }
}

//#Preview {
//    TechnologyRootView()
//}
