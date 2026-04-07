//
//  TechnologyRootView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/5/24.
//

import SwiftUI

@Observable
/// Internal coordinator that keeps filtering and reference-visibility state for `TechnologyRootView`.
private final class TechnologyRootManager {
    /// Currently selected framework section driving this screen.
    var frameworkSection: AppleTechnologies.FrameworkSection
    
    /// Creates a manager for a selected framework section.
    init(frameworkSection: AppleTechnologies.FrameworkSection) {
        self.frameworkSection = frameworkSection
    }
    
    /// Active topic tag filters.
    var activeFilters: Set<TagFilters> = []
    /// Cached deep-filter visibility keyed by reference identifier.
    var shownReferences: [String : Bool] = [:]
    
    /// Returns a copy of a reference associated with the currently displayed DocC site.
    ///
    /// - Parameter reference: Source reference from a framework payload.
    /// - Returns: A reference with the site context attached.
    func getReference(from reference: Reference) -> Reference {
        var reference = reference
        reference.docCSite = self.frameworkSection.docCSite
        
        return reference
    }
    
    /// Determines whether a reference should be shown under the active filter set.
    ///
    /// - Parameter reference: The reference to evaluate.
    /// - Returns: `true` when visible according to cached and top-level filter checks.
    func isReferenceShown(_ reference: Reference) -> Bool {
        guard let shownReference = shownReferences[reference.identifier] else {
            return SwiftDocB.isTopReferencePartOfFilter(reference, with: activeFilters)
        }
        
        return shownReference
    }
}

/// Root technology browser for a selected framework section.
struct TechnologyRootView: View {
    
    /// Shared navigation state coordinator.
    @Environment(NavigationViewModel.self) var navigationViewModel
    /// Shared documentation data/model coordinator.
    @Environment(DocumentationViewModel.self) var documentationViewModel
    
    /// Creates a technology root view for a framework section.
    init(frameworkSection: AppleTechnologies.FrameworkSection) {
        self.manager = TechnologyRootManager(frameworkSection: frameworkSection)
    }
    
    /// Current interface color scheme.
    @Environment(\.colorScheme) var colorScheme
    /// Stateful manager containing local filtering/rendering state.
    @State private var manager: TechnologyRootManager
    /// Whether deep-filter recomputation is in progress.
    @State var isLoading = false
    
    /// Cached framework payload for the selected framework section.
    var framework: Framework? {
        documentationViewModel.frameworks[manager.frameworkSection.destination.identifier]
    }
    
    /// Topic sections filtered to only those containing visible references.
    var topicSections: [Framework.TopicSection] {
        (framework?.topicSections ?? []).filter { section in
            section.identifiers.contains { identifier in
                guard let reference = framework?.references[identifier] else { return false }
                
                return manager.isReferenceShown(reference)
            }
        }
    }
    
    /// Maps an externally provided identifier to the local framework reference key space.
    private func convertOutsideReferenceToIn() -> Reference? {
        guard let ogIdentifier = navigationViewModel.reference?.identifier,
              let ogIdentifierURL = URL(string: ogIdentifier.lowercased()),
              let reference = framework?.references.first(where: { URL(string: $0.key.lowercased())?.path() == ogIdentifierURL.path() })
        else {
            return nil
        }
        
        return reference.value
    }
    
    var body: some View {
        VStack {
            if let framework {
                ScrollViewReader { scrollProxy in
                    FrameworkView(framework: framework, frameworkSection: manager.frameworkSection, topicSections: topicSections)
                        .onAppear {
                            guard let reference = convertOutsideReferenceToIn() else { return }
                            scrollProxy.scrollTo(reference.identifier, anchor: .center)
                        }
                }
                #if os(macOS) || targetEnvironment(macCatalyst)
                .listRowSpacing(navigationViewModel.isUsingSplitView ? 10 : 0)
                #else
                .listRowSpacing(navigationViewModel.isUsingSplitView ? nil : 0)
                #endif
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
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
            if let newValue, navigationViewModel.isUsingSplitView {
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
    
    /// Inner framework list renderer used once a framework payload is available.
    private struct FrameworkView: View {
        /// Framework payload currently being rendered.
        let framework: Framework
        /// Framework section metadata for root list item/title.
        let frameworkSection: AppleTechnologies.FrameworkSection
        /// Topic sections already filtered for display.
        let topicSections: [Framework.TopicSection]
        /// Shared local manager from parent view.
        @Environment(TechnologyRootManager.self) private var manager
        /// Shared documentation data/model coordinator.
        @Environment(DocumentationViewModel.self) var documentationViewModel
        
        /// Renders the framework + topics list.
        var body: some View {
            if framework.topicSections?.isEmpty == true {
                Text("No documentation available for \(framework.metadata.title)")
            } else {
                List {
                    Section {
                        FrameworkListItem(reference: frameworkSection.frameworkReference, title: frameworkSection.title)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .id(frameworkSection.frameworkReference.identifier)
                    }
                    
                    ForEach(topicSections) { section in
                        Section {
                            ForEach(section.identifiersWithIDs) { identifier in
                                if let reference = framework.references[identifier.identifier], manager.isReferenceShown(reference), let title = reference.title {
                                    FrameworkListItem(reference: manager.getReference(from: reference), title: title)
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                        .id(identifier.identifier)
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
    
    /// Loads the selected framework if it is not already cached.
    func loadFramework() async {
        if framework == nil {
            await documentationViewModel.fetchFramework(for: manager.frameworkSection.destination.identifier, site: manager.frameworkSection.docCSite)
        }
    }
    
    /// Recomputes deep-filter visibility for all references in the current framework.
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

/// Row renderer for a framework/reference item, including nested disclosure handling.
private struct FrameworkListItem: View {
    @Environment(\.tagFilters) var tagFilters
    
    let reference: Reference
    let title: String
    var willHideDisclosureGroups: Bool = false
    var isShowingChevron: Bool = true
    
    /// Whether this row can expand into a nested reference list.
    var hasSubParts: Bool {
        if let fragments = reference.fragments,
           fragments.contains(where: {
               $0.text.lowercased() == "struct" ||
               $0.text.lowercased() == "class" ||
               $0.text.lowercased() == "protocol" ||
               $0.text.lowercased() == "module" ||
               $0.text.lowercased() == "actor" ||
               $0.text.lowercased() == "enum"
           }) {
            return true
        }
        
        return reference.role == .collectionGroup || reference.role == .collection
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
    
    /// Returns a copy of this row that suppresses nested disclosure behavior.
    func hideDisclosureGroups() -> Self {
        var view = self
        view.willHideDisclosureGroups = true
        
        return view
    }
    
    /// Returns a copy of this row with configurable chevron visibility.
    func showChevron(_ bool: Bool) -> Self {
        var view = self
        view.isShowingChevron = bool
        
        return view
    }
}

/// Default non-disclosure row renderer for a single reference destination.
private struct DefaultListItem: View {
    @Environment(NavigationViewModel.self) var navigationViewModel
    let reference: Reference
    let title: String
    
    var isShowingChevron: Bool = true
    var shouldShowBackground: Bool = true
    
    /// Whether navigation path adjustment is needed before appending this destination.
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
    
    /// Returns a copy of this row with optional selected-line background.
    func showBackground(_ bool: Bool) -> Self {
        var view = self
        view.shouldShowBackground = bool
        
        return view
    }
    
    /// Returns a copy of this row with configurable chevron visibility.
    func showChevron(_ bool: Bool) -> Self {
        var view = self
        view.isShowingChevron = bool
        
        return view
    }
}

/// Disclosure group that lazily loads and displays nested framework topic references.
private struct FrameworkDisclosureGroup: View {
    
    @Environment(NavigationViewModel.self) var navigationViewModel
    @Environment(DocumentationViewModel.self) var documentationViewModel
    
    let identifier: String
    let title: String
    let reference: Reference
    
    @Environment(\.tagFilters) var tagFilters
    @State var shownReferences: [String : Bool] = [:]
    @State var isLoading = false
    
    /// Cached framework payload for this nested reference identifier.
    var framework: Framework? {
        documentationViewModel.frameworks[identifier]
    }
    
    /// Topic sections filtered to references visible under the active tags.
    var topicSections: [Framework.TopicSection] {
        (framework?.topicSections ?? []).filter { section in
            section.identifiers.contains { identifier in
                guard let reference = framework?.references[identifier] else { return false }
                
                return isReferenceShown(reference)
            }
        }
    }
    
    /// Section renderer that expands topic identifiers into visible framework list rows.
    struct TopicSectionIdentifierWithID: View {
        /// Source topic section.
        let section: Framework.TopicSection
        /// Parent framework payload.
        let framework: Framework
        /// Reference whose site context should be propagated to children.
        let reference: Reference
        /// Visibility predicate for child references.
        let isReferenceShown: (Reference) -> Bool
        
        /// Returns a copy of `reference` with inherited DocC site context.
        func getReference(from reference: Reference) -> Reference {
            var reference = reference
            reference.docCSite = self.reference.docCSite
            
            return reference
        }
        
        /// Renders topic-section rows for visible child references.
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
                    SelectedLineBackground(isSelected: navigationViewModel.reference == reference)
                        .padding(.leading, -10)
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
    
    /// Determines whether a nested reference should be shown.
    func isReferenceShown(_ reference: Reference) -> Bool {
        guard let shownReference = shownReferences[reference.identifier] else {
            return SwiftDocB.isTopReferencePartOfFilter(reference, with: tagFilters)
        }
        
        return shownReference
    }
    
    /// Recomputes deep-filter visibility for references in this disclosure group.
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

/// Checks top-level reference metadata against active filters.
///
/// - Parameters:
///   - reference: The reference to evaluate.
///   - filters: Active tag filters.
/// - Returns: `true` when the reference matches top-level filter criteria.
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

/// Checks whether a reference or any nested members satisfy active filters.
///
/// This may fetch nested frameworks while evaluating descendants.
/// Running it across many references can be network-intensive and may briefly show loading states.
///
/// - Parameters:
///   - reference: The reference to evaluate.
///   - filters: Active tag filters.
///   - documentationViewModel: Shared documentation state used to fetch nested frameworks.
/// - Returns: `true` when the reference or descendants match the filters.
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
            if SwiftDocB.isTopReferencePartOfFilter(subreference, with: filters) {
                return true
            }
        }
    }
    
    return false
}

/// Determines whether a reference kind is expected to contain nested members.
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
