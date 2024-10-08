//
//  TechnologyRootView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/5/24.
//

import SwiftUI

struct TechnologyRootView: View {
    
    @EnvironmentObject var navigationViewModel: NavigationViewModel
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
            await loadFramework()
        }
        .onChange(of: navigationViewModel.technology) {
            Task {
                await loadFramework()
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
                    Section(section.title) {
                        ForEach(section.identifiers, id: \.self) { identifier in
                            if let reference = framework.references[identifier], let title = reference.title {
                                FrameworkListItem(reference: reference, title: title)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        }
                    }
                    .headerProminence(.increased)
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemBackground))
            .listRowSpacing(0)
        }
    }
    
    func loadFramework() async {
        if framework == nil {
            await documentationViewModel.fetchFramework(for: frameworkSection.destination.identifier)
        }
    }
}

private struct FrameworkListItem: View {
    
    @EnvironmentObject var navigationViewModel: NavigationViewModel
    
    let reference: Reference
    let title: String
    
    var hasSubParts: Bool {
        if let fragments = reference.fragments,
           fragments.contains(where: {
               $0.text.lowercased() == "struct" ||
               $0.text.lowercased() == "class" ||
               $0.text.lowercased() == "protocol" ||
               $0.text.lowercased() == "actor" ||
               $0.text.lowercased() == "enum"
           })
        {
            return true
        }
        
        return reference.role == .collectionGroup
    }
    
    var body: some View {
        if hasSubParts {
            FrameworkDisclosureGroup(identifier: reference.identifier, title: title, reference: reference)
        } else if let urlString = reference.url, !urlString.hasPrefix("/documentation"), let url = URL(string: "https://developer.apple.com\(urlString)") {
            Link(destination: url) {
                HStack {
                    Label {
                        HStack {
                            Text(reference.title ?? "")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Image(systemSymbol: .arrowUpRight)
                                .imageScale(.small)
                                .foregroundStyle(.accent)
                        }
                    } icon: {
                        Image(systemSymbol: .link)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } else if reference.role == .collection {
            let section = Technologies.FrameworkSection(languages: [], title: title, tags: [], destination: .init(type: reference.type, isActive: true, identifier: reference.identifier))
            
            Text(title)
                .foregroundStyle(.secondary)
        } else {
            Button {
                navigationViewModel.reference = reference
            } label: {
                Label {
                    Text(reference.title ?? "")
                } icon: {
                    Image(systemName: reference.role?.labelIcon() ?? "text.document")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .padding(-10)
                    .foregroundStyle(Color(uiColor: .tertiarySystemFill))
                    .opacity(navigationViewModel.reference == reference ? 1 : 0)
            }
        }
    }
}

private struct FrameworkDisclosureGroup: View {
    
    @EnvironmentObject var navigationViewModel: NavigationViewModel
    @EnvironmentObject var documentationViewModel: DocumentationViewModel
    
    let identifier: String
    let title: String
    let reference: Reference
    
    var framework: Framework? { documentationViewModel.frameworks[identifier] }
    
    var body: some View {
        DisclosureGroup {
            if let framework {
                ForEach(framework.topicSections) { section in
                    Section {
                        ForEach(section.identifiers, id: \.self) { subidentifier in
                            if let subreference = framework.references[subidentifier], let subtitle = subreference.title {
                                FrameworkListItem(reference: subreference, title: subtitle)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        }
                    } header: {
                        Text(section.title)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } label: {
            Button {
                navigationViewModel.reference = reference
            } label: {
                Label {
                    Text(reference.title ?? "")
                } icon: {
                    Image(systemName: reference.role?.labelIcon() ?? "text.document")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .padding(-10)
                    .padding(.trailing, -20)
                    .foregroundStyle(Color(uiColor: .tertiarySystemFill))
                    .opacity(navigationViewModel.reference == reference ? 1 : 0)
            }
        }
        .task {
            if framework == nil {
                await documentationViewModel.fetchFramework(for: identifier)
            }
        }
    }
}

