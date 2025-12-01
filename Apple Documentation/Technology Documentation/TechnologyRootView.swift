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
    let frameworkSection: AppleTechnologies.FrameworkSection
    
    @Environment(\.colorScheme) var colorScheme
    @State private var activeFilters: Set<TagFilters> = []
    @State var shownReferences: [String : Bool] = [:]
    @State var isLoading = false
    
    var framework: Framework? {
        documentationViewModel.frameworks[frameworkSection.destination.identifier]
    }
    
    func getReference(from reference: Reference) -> Reference {
        var reference = reference
        reference.docCSite = self.frameworkSection.docCSite
        
        return reference
    }
    
    var topicSections: [Framework.TopicSection] {
        (framework?.topicSections ?? []).filter { section in
            section.identifiers.contains { identifier in
                guard let reference = framework?.references[identifier] else { return false }
                
                return isReferenceShown(reference)
            }
        }
    }
    
    var body: some View {
        VStack {
            if let framework {
                frameworkView(framework)
                    .toolbar {
                        HStack {
                            if self.frameworkSection.docCSite == nil {
                                Menu {
                                    ForEach(TagFilters.allCases, id: \.self) { filter in
                                        Button {
                                            if activeFilters.contains(filter) {
                                                activeFilters.remove(filter)
                                            } else {
                                                activeFilters.insert(filter)
                                            }
                                        } label: {
                                            if activeFilters.contains(filter) {
                                                Text("\(filter.rawValue.capitalized) \(Image(systemSymbol: .checkmark))")
                                            } else {
                                                Text(filter.rawValue.capitalized)
                                            }
                                        }
                                    }
                                } label: {
                                    Label("Filter", systemSymbol: .line3HorizontalDecrease)
                                        .labelStyle(.iconOnly)
                                }
                            }

                            if let variants = framework.variants, !navigationViewModel.isUsingSplitView {
                                LanguagePicker(variants: variants)
                            }
                        }
                    }
            } else {
                ProgressView("Loading")
            }
        }
        .opacity(isLoading ? 0 : 1)
        .overlay(content: {
            if isLoading {
                ProgressView("Loading")
            }
        })
#if !os(macOS)
        .navigationTitle(frameworkSection.title)
        .navigationBarTitleDisplayMode(.large)
#endif
        .onAppear {
            Task {
                await loadFramework()
                await getShownReferences()
            }
        }
        .onChange(of: navigationViewModel.technology) {
            Task {
                await loadFramework()
                await getShownReferences()
            }
        }
        .onChange(of: activeFilters) {
            Task {
                await getShownReferences()
            }
        }
        .onChange(of: documentationViewModel.preferedProgrammingLanguage, {
            Task {
                documentationViewModel.frameworks[frameworkSection.destination.identifier] = nil
                await loadFramework()
            }
        })
        .onDisappear {
            if navigationViewModel.shouldRemoveTechnologyFromPath(frameworkSection) && navigationViewModel.reference == nil && !navigationViewModel.isUsingSplitView {
                navigationViewModel.goBackward(updatePath: false)
            }
        }
        .environment(\.tagFilters, activeFilters)
    }
    
    @ViewBuilder
    func frameworkView(_ framework: Framework) -> some View {
        if framework.topicSections?.isEmpty == true {
            Text("No documentation available for \(framework.metadata.title)")
        } else {
            List {
                Section {
                    FrameworkListItem(reference: frameworkSection.frameworkReference, title: frameworkSection.title)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                
                ForEach(topicSections) { section in
                    Section {
                        ForEach(section.identifiersWithIDs) { identifier in
                            if let reference = framework.references[identifier.identifier], let title = reference.title, isReferenceShown(reference) {
                                FrameworkListItem(reference: getReference(from: reference), title: title)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        }
                    } header: {
                        if let title = section.title {
                            Text(title)
                        }
                    }
                    .headerProminence(.increased)
                }
                
                Section {} footer: {
                    if let legalNotices = framework.legalNotices {
                        LegalNoticesView(legalNotices: legalNotices)
                            .padding(.bottom)
                    }
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .background(Color(platformColor: .systemBackground))
#if os(macOS) || targetEnvironment(macCatalyst)
            .listRowSpacing(navigationViewModel.isUsingSplitView ? 10 : 0)
            #else
            .listRowSpacing(navigationViewModel.isUsingSplitView ? nil : 0)
            #endif
        }
    }
    
    func loadFramework() async {
        if framework == nil {
            await documentationViewModel.fetchFramework(for: frameworkSection.destination.identifier, site: frameworkSection.docCSite)
        }
    }
    
    func isReferenceShown(_ reference: Reference) -> Bool {
        guard let shownReference = shownReferences[reference.identifier] else {
            return Developer_Documentation.isTopReferencePartOfFilter(reference, with: activeFilters)
        }
        
        return shownReference
    }
    
    @MainActor
    func getShownReferences() async {
        guard !activeFilters.isEmpty else {
            shownReferences.removeAll()
            return
        }
        
        isLoading = true
        for section in framework?.topicSections ?? [] {
            for identifier in section.identifiers {
                if let reference = framework?.references[identifier] {
                    self.shownReferences[reference.identifier] = await isFullReferencePartOfFilter(reference, with: activeFilters, documentationViewModel: documentationViewModel)
                }
            }
        }
        
        isLoading = false
    }
}

private struct FrameworkListItem: View {
    
    @EnvironmentObject var navigationViewModel: NavigationViewModel
    @Environment(\.tagFilters) var tagFilters
    
    let reference: Reference
    let title: String
    var isShowingChevron: Bool = true
    
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
                .showChevron(isShowingChevron)
        }
    }
    
    func showChevron(_ bool: Bool) -> Self {
        var view = self
        view.isShowingChevron = bool
        
        return view
    }
}

private struct DefaultListItem: View {
    @EnvironmentObject var navigationViewModel: NavigationViewModel
    let reference: Reference
    let title: String
    
    var isShowingChevron: Bool = true
    var shouldShowBackground: Bool = true
    
    var removeLastPathComponentFirst: Bool {
        guard let url = URL(string: reference.identifier), let currentTech = navigationViewModel.technology, let currentTechUrl = URL(string: currentTech.destination.identifier) else {
            return false
        }
        
        return !url.path().contains(currentTechUrl.path())
    }
    
    var body: some View {
        ReferenceNavigationLinkButton(reference: reference) {
            Label {
                HStack {
                    Text(title)
                    
                    if reference.beta == true {
                        ArticleBadge(badge: .beta)
                    }
                    
                    if reference.deprecated == true {
                        ArticleBadge(badge: .deprecated)
                    }
                    
                    if !navigationViewModel.isUsingSplitView && isShowingChevron {
                        Spacer()
                        ChevronView()
                    }
                }
            } icon: {
                Image(systemSymbol: reference.role?.labelIcon ?? .docText)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .showBackground(shouldShowBackground)
        .removeLastPathComponentFirst(removeLastPathComponentFirst)
    }
    
    func showBackground(_ bool: Bool) -> Self {
        var view = self
        view.shouldShowBackground = bool
        
        return view
    }
    
    func showChevron(_ bool: Bool) -> Self {
        var view = self
        view.isShowingChevron = bool
        
        return view
    }
}

private struct FrameworkDisclosureGroup: View {
    
    @EnvironmentObject var navigationViewModel: NavigationViewModel
    @EnvironmentObject var documentationViewModel: DocumentationViewModel
    
    let identifier: String
    let title: String
    let reference: Reference
    
    @Environment(\.tagFilters) var tagFilters
    @State var shownReferences: [String : Bool] = [:]
    @State var isLoading = false
    
    var framework: Framework? {
        documentationViewModel.frameworks[identifier]
    }
    
    func getReference(from reference: Reference) -> Reference {
        var reference = reference
        reference.docCSite = self.reference.docCSite
        
        return reference
    }
    
    var topicSections: [Framework.TopicSection] {
        (framework?.topicSections ?? []).filter { section in
            section.identifiers.contains { identifier in
                guard let reference = framework?.references[identifier] else { return false }
                
                return isReferenceShown(reference)
            }
        }
    }
    
    var body: some View {
        DisclosureGroup {
            Group {
                if let framework {
                    ForEach(topicSections) { section in
                        Section {
                            ForEach(section.identifiersWithIDs) { subidentifier in
                                if let subreference = framework.references[subidentifier.identifier], let subtitle = subreference.title, isReferenceShown(subreference) {
                                    FrameworkListItem(reference: getReference(from: subreference), title: subtitle)
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                }
                            }
                        } header: {
                            if let title = section.title {
                                Text(title)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .opacity(isLoading ? 0 : 1)
            .overlay {
                if isLoading {
                    ProgressView("Loading")
                }
            }
        } label: {
            DefaultListItem(reference: reference, title: title)
                .showBackground(false)
                .showChevron(false)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .padding(-10)
                        .padding(.trailing, -25)
                        .foregroundStyle(Color(platformColor: .tertiarySystemFill))
                        .opacity((navigationViewModel.reference == reference) ? 1 : 0)
                }
        }
        .onAppear {
            Task {
                if framework == nil {
                    await documentationViewModel.fetchFramework(for: identifier, site: reference.docCSite)
                }
                await getShownReferences()
            }
        }
        .onChange(of: tagFilters) {
            Task {
                await getShownReferences()
            }
        }
    }
    
    func isReferenceShown(_ reference: Reference) -> Bool {
        guard let shownReference = shownReferences[reference.identifier] else {
            return Developer_Documentation.isTopReferencePartOfFilter(reference, with: tagFilters)
        }
        
        return shownReference
    }
    
    @MainActor
    func getShownReferences() async {
        guard !tagFilters.isEmpty else {
            shownReferences.removeAll()
            return
        }
        
        isLoading = true
        for section in framework?.topicSections ?? [] {
            for identifier in section.identifiers {
                if let reference = framework?.references[identifier] {
                    self.shownReferences[reference.identifier] = await isFullReferencePartOfFilter(reference, with: tagFilters, documentationViewModel: documentationViewModel)
                }
            }
        }
        
        isLoading = false
    }
}

// MARK: File-Level Filter Functions

private func isTopReferencePartOfFilter(_ reference: Reference, with filters: Set<TagFilters>) -> Bool {
    guard !filters.isEmpty else { return true }
    
    if filters.contains(.beta) && reference.beta == true {
        return true
    }
    
    if filters.contains(.deprecated) && reference.deprecated == true {
        return true
    }
    
    return false
}

private func isFullReferencePartOfFilter(_ reference: Reference, with filters: Set<TagFilters>, documentationViewModel: DocumentationViewModel) async -> Bool {
    // Return if the top level is included
    if isTopReferencePartOfFilter(reference, with: filters) { return true }
    
    // Search deeper down if it contains something included
    guard referenceHasSubParts(reference) else { return false }
    
    // Fetch framework if needed
    if documentationViewModel.frameworks[reference.identifier] == nil {
        await documentationViewModel.fetchFramework(for: reference.identifier, site: reference.docCSite)
    }
    
    guard let framework = documentationViewModel.frameworks[reference.identifier] else { return false }
    
    for section in (framework.topicSections ?? []) {
        for subidentifier in section.identifiers {
            guard let subreference = framework.references[subidentifier] else { continue }
            if Developer_Documentation.isTopReferencePartOfFilter(subreference, with: filters) {
                return true
            }
        }
    }
    
    return false
}

private func referenceHasSubParts(_ reference: Reference) -> Bool {
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
