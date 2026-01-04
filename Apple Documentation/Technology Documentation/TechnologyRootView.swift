//
//  TechnologyRootView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/5/24.
//

import SwiftUI

@Observable
private final class TechnologyRootManager {
    var frameworkSection: AppleTechnologies.FrameworkSection
    
    init(frameworkSection: AppleTechnologies.FrameworkSection) {
        self.frameworkSection = frameworkSection
    }
    
    var activeFilters: Set<TagFilters> = []
    var shownReferences: [String : Bool] = [:]
    
    func getReference(from reference: Reference) -> Reference {
        var reference = reference
        reference.docCSite = self.frameworkSection.docCSite
        
        return reference
    }
    
    func isReferenceShown(_ reference: Reference) -> Bool {
        guard let shownReference = shownReferences[reference.identifier] else {
            return Developer_Documentation.isTopReferencePartOfFilter(reference, with: activeFilters)
        }
        
        return shownReference
    }
}

struct TechnologyRootView: View {
    
    @Environment(NavigationViewModel.self) var navigationViewModel
    @Environment(DocumentationViewModel.self) var documentationViewModel
    
    init(frameworkSection: AppleTechnologies.FrameworkSection) {
        self.manager = TechnologyRootManager(frameworkSection: frameworkSection)
    }
    
    @Environment(\.colorScheme) var colorScheme
    @State private var manager: TechnologyRootManager
    @State var isLoading = false
    
    var framework: Framework? {
        documentationViewModel.frameworks[manager.frameworkSection.destination.identifier]
    }
    
    var topicSections: [Framework.TopicSection] {
        (framework?.topicSections ?? []).filter { section in
            section.identifiers.contains { identifier in
                guard let reference = framework?.references[identifier] else { return false }
                
                return manager.isReferenceShown(reference)
            }
        }
    }
    
    var body: some View {
        VStack {
            if let framework {
                FrameworkView(framework: framework, frameworkSection: manager.frameworkSection, topicSections: topicSections)
                #if os(macOS) || targetEnvironment(macCatalyst)
                .listRowSpacing(navigationViewModel.isUsingSplitView ? 10 : 0)
                #else
                .listRowSpacing(navigationViewModel.isUsingSplitView ? nil : 0)
                #endif
                    .toolbar {
                        HStack {
                            if self.manager.frameworkSection.docCSite == nil {
                                Menu {
                                    ForEach(TagFilters.allCases, id: \.self) { filter in
                                        Button {
                                            if manager.activeFilters.contains(filter) {
                                                manager.activeFilters.remove(filter)
                                            } else {
                                                manager.activeFilters.insert(filter)
                                            }
                                        } label: {
                                            if manager.activeFilters.contains(filter) {
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
        .navigationTitle(manager.frameworkSection.title)
        .navigationBarTitleDisplayMode(.large)
#endif
        .onAppear {
            Task {
                await loadFramework()
                await getShownReferences()
            }
        }
        .onChange(of: navigationViewModel.technology) { _, newValue in
            if let newValue {
                manager.frameworkSection = newValue
            }
            Task {
                await loadFramework()
                await getShownReferences()
            }
        }
        .onChange(of: manager.activeFilters) {
            Task {
                await getShownReferences()
            }
        }
        .onChange(of: documentationViewModel.preferedProgrammingLanguage, {
            Task {
                documentationViewModel.frameworks[manager.frameworkSection.destination.identifier] = nil
                await loadFramework()
            }
        })
        .onDisappear {
            if navigationViewModel.shouldRemoveTechnologyFromPath(manager.frameworkSection) && navigationViewModel.reference == nil && !navigationViewModel.isUsingSplitView {
                navigationViewModel.goBackward(updatePath: false)
            }
        }
        .environment(\.tagFilters, manager.activeFilters)
        .environment(manager)
    }
    
    private struct FrameworkView: View {
        let framework: Framework
        let frameworkSection: AppleTechnologies.FrameworkSection
        let topicSections: [Framework.TopicSection]
        @Environment(TechnologyRootManager.self) private var manager
        @Environment(DocumentationViewModel.self) var documentationViewModel
        
        var body: some View {
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
                                if let reference = framework.references[identifier.identifier], manager.isReferenceShown(reference), let title = reference.title {
                                    FrameworkListItem(reference: manager.getReference(from: reference), title: title)
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
            }
        }
    }
    
    func loadFramework() async {
        if framework == nil {
            await documentationViewModel.fetchFramework(for: manager.frameworkSection.destination.identifier, site: manager.frameworkSection.docCSite)
        }
    }
    
    @MainActor
    func getShownReferences() async {
        guard !manager.activeFilters.isEmpty else {
            manager.shownReferences.removeAll()
            return
        }
        
        isLoading = true
        for section in framework?.topicSections ?? [] {
            for identifier in section.identifiers {
                if let reference = framework?.references[identifier] {
                    self.manager.shownReferences[reference.identifier] = await isFullReferencePartOfFilter(reference, with: manager.activeFilters, documentationViewModel: documentationViewModel)
                }
            }
        }
        
        isLoading = false
    }
}

private struct FrameworkListItem: View {
    @Environment(\.tagFilters) var tagFilters
    
    let reference: Reference
    let title: String
    var willHideDisclosureGroups: Bool = false
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
        if hasSubParts && !willHideDisclosureGroups {
            FrameworkDisclosureGroup(identifier: reference.identifier, title: title, reference: reference)
        } else if let urlString = reference.url, !urlString.hasPrefix("/documentation"), let url = reference.externalURL {
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
    
    func hideDisclosureGroups() -> Self {
        var view = self
        view.willHideDisclosureGroups = true
        
        return view
    }
    
    func showChevron(_ bool: Bool) -> Self {
        var view = self
        view.isShowingChevron = bool
        
        return view
    }
}

private struct DefaultListItem: View {
    @Environment(NavigationViewModel.self) var navigationViewModel
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
    
    @Environment(NavigationViewModel.self) var navigationViewModel
    @Environment(DocumentationViewModel.self) var documentationViewModel
    
    let identifier: String
    let title: String
    let reference: Reference
    
    @Environment(\.tagFilters) var tagFilters
    @State var shownReferences: [String : Bool] = [:]
    @State var isLoading = false
    
    var framework: Framework? {
        documentationViewModel.frameworks[identifier]
    }
    
    var topicSections: [Framework.TopicSection] {
        (framework?.topicSections ?? []).filter { section in
            section.identifiers.contains { identifier in
                guard let reference = framework?.references[identifier] else { return false }
                
                return isReferenceShown(reference)
            }
        }
    }
    
    struct TopicSectionIdentifierWithID: View {
        let section: Framework.TopicSection
        let framework: Framework
        let reference: Reference
        let isReferenceShown: (Reference) -> Bool
        
        func getReference(from reference: Reference) -> Reference {
            var reference = reference
            reference.docCSite = self.reference.docCSite
            
            return reference
        }
        
        var body: some View {
            Section {
                ForEach(section.identifiersWithIDs) { subidentifier in
                    if let subreference = framework.references[subidentifier.identifier], let subtitle = subreference.title, isReferenceShown(subreference) {
                        FrameworkListItem(reference: getReference(from: subreference), title: subtitle)
//                            .hideDisclosureGroups()
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
    
    var body: some View {
        DisclosureGroup {
            Group {
                if let framework {
                    ForEach(topicSections) { section in
                        TopicSectionIdentifierWithID(section: section, framework: framework, reference: reference, isReferenceShown: isReferenceShown)
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
    if await documentationViewModel.frameworks[reference.identifier] == nil {
        await documentationViewModel.fetchFramework(for: reference.identifier, site: reference.docCSite)
    }
    
    guard let framework = await documentationViewModel.frameworks[reference.identifier] else { return false }
    
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
