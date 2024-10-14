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
    
    @Environment(\.colorScheme) var colorScheme
    
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
        .onAppear(perform: {
            navigationViewModel.technology = frameworkSection
        })
        .task {
            await loadFramework()
        }
        .onChange(of: navigationViewModel.technology) {
            Task {
                await loadFramework()
            }
        }
        .onChange(of: documentationViewModel.preferedProgrammingLanguage, {
            Task {
                documentationViewModel.frameworks[frameworkSection.destination.identifier] = nil
                await loadFramework()
            }
        })
    }
    
    var frameworkReference: Reference {
        // swiftlint:disable line_length
        .init(title: frameworkSection.title, abstract: nil, identifier: frameworkSection.destination.identifier, kind: nil, type: "", url: nil, role: .collection, fragments: nil, deprecated: nil, beta: nil, variants: nil, images: nil)
        // swiftlint:enable line_length
    }
    
    @ViewBuilder
    func frameworkView(_ framework: Framework) -> some View {
        if framework.topicSections?.isEmpty == true {
            Text("No documentation available for \(framework.metadata.title)")
        } else {
            List {

                Section {
                    FrameworkListItem(reference: frameworkReference, title: frameworkSection.title)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                
                ForEach(framework.topicSections ?? []) { section in
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
#if os(macOS) || targetEnvironment(macCatalyst)
            .listRowSpacing(navigationViewModel.isUsingSplitView ? 10 : 0)
            #else
            .listRowSpacing(navigationViewModel.isUsingSplitView ? nil : 0)
            #endif
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
           }) {
            return true
        }
        
        return reference.role == .collectionGroup
    }
    
    var body: some View {
        if hasSubParts {
            FrameworkDisclosureGroup(identifier: reference.identifier, title: title, reference: reference)
        } else if let urlString = reference.url, !urlString.hasPrefix("/documentation"), let url = URL(string: "https://developer.apple.com\(urlString)") {
            MacOSAgnosticLink(destination: url) {
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
        } else {
            DefaultListItem(reference: reference, title: title)
        }
    }
}

private struct DefaultListItem: View {
    @EnvironmentObject var navigationViewModel: NavigationViewModel
    let reference: Reference
    let title: String
    
    var shouldShowBackground: Bool = true
    
    var body: some View {
        ReferenceNavigationLinkButton(reference: reference) {
            Label {
                Text(title)
                
                if reference.beta == true {
                    ArticleBadge(badge: .beta)
                }
                
                if reference.deprecated == true {
                    ArticleBadge(badge: .deprecated)
                }
            } icon: {
                Image(systemSymbol: reference.role?.labelIcon ?? .docText)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .showBackground(shouldShowBackground)
    }
    
    func showBackground(_ bool: Bool) -> Self {
        var view = self
        view.shouldShowBackground = bool
        
        return view
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
                ForEach(framework.topicSections ?? []) { section in
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
            DefaultListItem(reference: reference, title: title)
                .showBackground(false)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .padding(-10)
                        .padding(.trailing, -25)
                        .foregroundStyle(Color(uiColor: .tertiarySystemFill))
                        .opacity((navigationViewModel.reference == reference) ? 1 : 0)
                }
        }
        .task {
            if framework == nil {
                await documentationViewModel.fetchFramework(for: identifier)
            }
        }
    }
}
