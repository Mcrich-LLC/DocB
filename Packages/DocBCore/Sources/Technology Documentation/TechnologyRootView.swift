//
//  TechnologyRootView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/5/24.
//

import SwiftUI
import DocCKit

/// Internal coordinator that keeps filtering and reference-visibility state for `TechnologyRootView`.
@Observable
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
    /// Current Apple index load, shared by filter refreshes that need the index.
    private var appleIndexTask: Task<DocCIndex?, Never>?
    
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
            return referenceMatchesFilters(reference, filters: activeFilters)
        }
        
        return shownReference
    }
    
    /// Starts loading the Apple framework index if needed.
    @MainActor
    func loadAppleIndexIfNeeded() -> Task<DocCIndex?, Never>? {
        guard frameworkSection.docCSite == nil || frameworkSection.legalNotices != nil else {
            return nil
        }
        
        if let index = frameworkSection.index {
            return Task { index }
        }
        
        if let appleIndexTask {
            return appleIndexTask
        }
        
        let percentEncodedTitle = frameworkSection.title.lowercased().addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? frameworkSection.title
        
        let url = AppleDocsClient.basePath.appending(path: "index/\(percentEncodedTitle).json")
        let task = Task<DocCIndex?, Never> { [weak self] in
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let index = try JSONDecoder().decode(DocCIndex.self, from: data)
                await MainActor.run {
                    self?.frameworkSection.setIndex(index)
                }
                return index
            } catch {
                print(error)
                return nil
            }
        }
        
        appleIndexTask = task
        return task
    }
    
    /// Returns an index for filtering, waiting for the Apple index load when necessary.
    @MainActor
    func indexForFiltering(fallback: DocCIndex?) async -> DocCIndex? {
        if let index = frameworkSection.index {
            return index
        }
        
        if let fallback {
            return fallback
        }
        
        return await loadAppleIndexIfNeeded()?.value
    }
}

/// Root technology browser for a selected framework section.
struct TechnologyRootView: View {
    
    @Environment(NavigationViewModel.self) var navigationViewModel
    @Environment(DocumentationViewModel.self) var documentationViewModel
    
    /// Creates a technology root view for a framework section.
    init(frameworkSection: AppleTechnologies.FrameworkSection) {
        self.manager = TechnologyRootManager(frameworkSection: frameworkSection)
    }
    
    @Environment(\.colorScheme) var colorScheme
    /// Stateful manager containing local filtering/rendering state.
    @State private var manager: TechnologyRootManager
    /// Whether deep-filter recomputation is in progress.
    @State var isLoading = false
    /// Current root-level deep-filter task.
    @State private var shownReferencesTask: Task<Void, Never>?
    /// Monotonic token used to ignore stale root-level filter results.
    @State private var shownReferencesRequestID = UUID()
    
    /// Cached framework payload for the selected framework section.
    var framework: Framework? {
        documentationViewModel.framework(for: manager.frameworkSection.destination.identifier)
    }
    
    /// Published fallback index used for local descendant filtering when the selected section does not carry one yet.
    private var publishedFilterIndex: DocCIndex? {
        documentationViewModel.technologies.appleTechnologies.compactMap(\.index).first ??
        documentationViewModel.appleDocCSiteRef?.index
    }
    
    /// Topic sections filtered to only rows that should be visible.
    private var topicSections: [VisibleFrameworkTopicSection] {
        (framework?.topicSections ?? []).compactMap { section in
            let rows = section.identifiers.compactMap { identifier -> FrameworkReferenceRow? in
                guard let reference = framework?.references[identifier], manager.isReferenceShown(reference), let title = reference.title else {
                    return nil
                }
                
                return FrameworkReferenceRow(
                    id: identifier,
                    reference: manager.getReference(from: reference),
                    title: title,
                    referenceContext: framework?.references ?? [:]
                )
            }
            
            guard !rows.isEmpty else { return nil }
            
            return VisibleFrameworkTopicSection(id: section.id, title: section.title, rows: rows)
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
                    FrameworkRootContent(framework: framework, frameworkSection: manager.frameworkSection, topicSections: topicSections)
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
                    TechnologyRootToolbar(framework: framework, frameworkSection: manager.frameworkSection)
                }
            } else {
                ProgressView("Loading")
                    .controlSize(.small)
            }
        }
        .opacity(isLoading ? 0 : 1)
        .overlay(content: {
            if isLoading {
                ProgressView("Loading")
                    .controlSize(.small)
            }
        })
#if !os(macOS)
        .navigationTitle(manager.frameworkSection.title)
        .navigationBarTitleDisplayMode(.large)
#endif
        .onAppear {
            Task {
                _ = await manager.loadAppleIndexIfNeeded()?.value
                guard !Task.isCancelled, !manager.activeFilters.isEmpty else { return }
                scheduleShownReferencesRefresh(loadFrameworkFirst: false)
            }
            
            scheduleShownReferencesRefresh(loadFrameworkFirst: true)
        }
        .onChange(of: navigationViewModel.technology) { _, newValue in
            if let newValue, navigationViewModel.isUsingSplitView {
                manager.frameworkSection = newValue
            }
            scheduleShownReferencesRefresh(loadFrameworkFirst: true)
        }
        .onChange(of: manager.activeFilters) {
            scheduleShownReferencesRefresh(loadFrameworkFirst: false)
        }
        .onDisappear {
            shownReferencesTask?.cancel()
            if !navigationViewModel.isUsingSplitView && navigationViewModel.shouldRemoveTechnologyFromPath(manager.frameworkSection) && navigationViewModel.reference == nil {
                navigationViewModel.goBackward(updatePath: false)
            }
        }
        .environment(\.tagFilters, manager.activeFilters)
        .environment(manager)
    }
    
    /// Inner framework list renderer used once a framework payload is available.
    private struct FrameworkRootContent: View {
        /// Framework payload currently being rendered.
        let framework: Framework
        /// Framework section metadata for root list item/title.
        let frameworkSection: AppleTechnologies.FrameworkSection
        /// Topic sections already filtered for display.
        let topicSections: [VisibleFrameworkTopicSection]
        
        /// Renders the framework + topics list.
        var body: some View {
            if framework.topicSections?.isEmpty == true {
                Text("No documentation available for \(framework.metadata.title)")
            } else {
                FrameworkListContent(framework: framework, frameworkSection: frameworkSection, topicSections: topicSections)
            }
        }
    }
    
    /// Starts a cancellable root-level deep-filter refresh for the current framework state.
    ///
    /// - Parameter loadFrameworkFirst: Whether the selected framework should be loaded before filtering.
    @MainActor
    private func scheduleShownReferencesRefresh(loadFrameworkFirst: Bool) {
        shownReferencesTask?.cancel()
        
        let requestID = UUID()
        shownReferencesRequestID = requestID
        shownReferencesTask = Task {
            if loadFrameworkFirst {
                await loadFramework()
            }
            
            await getShownReferences(requestID: requestID)
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
    func getShownReferences(requestID: UUID) async {
        guard !manager.activeFilters.isEmpty else {
            if shownReferencesRequestID == requestID {
                manager.shownReferences.removeAll()
                isLoading = false
            }
            return
        }
        
        let frameworkIdentifier = manager.frameworkSection.destination.identifier
        let references = (framework?.topicSections ?? []).flatMap { section in
            section.identifiers.compactMap { identifier in
                framework?.references[identifier]
            }
        }
        let filters = manager.activeFilters
        let index = await manager.indexForFiltering(fallback: publishedFilterIndex)
        let frameworkResolver = documentationViewModel.frameworkResolver()
        
        isLoading = true
        let result = await visibilityByReferenceIdentifier(
            for: references,
            filters: filters,
            index: index,
            frameworkResolver: frameworkResolver
        )
        
        guard !Task.isCancelled,
              shownReferencesRequestID == requestID,
              manager.activeFilters == filters,
              manager.frameworkSection.destination.identifier == frameworkIdentifier
        else {
            return
        }
        
        documentationViewModel.cacheFrameworks(result.frameworksLoadedForCache)
        manager.shownReferences = result.visibilityByIdentifier
        isLoading = false
    }
}

/// Toolbar controls for root technology screens.
private struct TechnologyRootToolbar: ToolbarContent {
    /// Framework payload currently being rendered.
    let framework: Framework
    /// Framework section metadata for filtering behavior.
    let frameworkSection: AppleTechnologies.FrameworkSection
    
    @Environment(TechnologyRootManager.self) private var manager
    @Environment(NavigationViewModel.self) private var navigationViewModel
    
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if frameworkSection.docCSite == nil {
                TechnologyFilterMenu()
            }
            
            if let variants = framework.variants, !navigationViewModel.isUsingSplitView {
                LanguagePicker(variants: variants)
            }
        }
    }
}

/// Filter menu for technology root topic lists.
private struct TechnologyFilterMenu: View {
    @Environment(TechnologyRootManager.self) private var manager
    
    var body: some View {
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
}

/// Precomputed visible topic section used by root and disclosure lists.
private struct VisibleFrameworkTopicSection: Identifiable {
    /// Stable section identifier from the decoded framework topic section.
    let id: UUID
    /// Optional section title.
    let title: String?
    /// Rows visible in this section.
    let rows: [FrameworkReferenceRow]
}

/// Precomputed framework reference row.
private struct FrameworkReferenceRow: Identifiable {
    /// Stable row identifier.
    let id: String
    /// Navigation reference for the row.
    let reference: Reference
    /// Display title.
    let title: String
    /// Neighboring references from the same DocC payload.
    let referenceContext: [String: Reference]
}

/// Stable list shell for root framework rows.
private struct FrameworkListContent: View {
    /// Framework payload currently being rendered.
    let framework: Framework
    /// Framework section metadata for root list item/title.
    let frameworkSection: AppleTechnologies.FrameworkSection
    /// Topic sections already filtered for display.
    let topicSections: [VisibleFrameworkTopicSection]
    
    var body: some View {
        List {
            Section {
                FrameworkListItem(reference: frameworkSection.frameworkReference, title: frameworkSection.title)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .id(frameworkSection.frameworkReference.identifier)
            }
            
            ForEach(topicSections) { section in
                FrameworkTopicSectionView(section: section)
            }
            
            Section {} footer: {
                if let legalNotices = framework.legalNotices {
                    DocCLegalNoticesView(legalNotices: legalNotices)
                        .padding(.bottom)
                }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(Color(platformColor: .systemBackground))
    }
}

/// Renders one framework topic section from precomputed visible rows.
private struct FrameworkTopicSectionView: View {
    /// Source topic section with visible rows.
    let section: VisibleFrameworkTopicSection
    /// Whether the section header should use secondary styling.
    var usesSecondaryHeader = false
    
    var body: some View {
        Section {
            ForEach(section.rows) { row in
                FrameworkListItem(reference: row.reference, title: row.title, referenceContext: row.referenceContext)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .id(row.id)
            }
        } header: {
            if let title = section.title {
                Text(title)
                    .foregroundStyle(usesSecondaryHeader ? .secondary : .primary)
            }
        }
        .headerProminence(.increased)
    }
}

/// Row renderer for a framework/reference item, including nested disclosure handling.
private struct FrameworkListItem: View {
    @Environment(\.tagFilters) var tagFilters
    
    let reference: Reference
    let title: String
    var referenceContext: [String: Reference] = [:]
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
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            DefaultListItem(reference: reference, title: title, referenceContext: referenceContext)
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
    let referenceContext: [String: Reference]
    
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
            HStack {
                let site = reference.docCSite ?? navigationViewModel.technology?.docCSite
                SearchResultSymbolBadge(
                    symbolKind: SearchSymbolResolver.symbolKind(
                        for: reference,
                        title: title,
                        site: site,
                        referenceContext: referenceContext
                    ),
                    customIconIdentifier: customIconIdentifier(in: site),
                    customIconSite: site,
                    customIconArchiveIdentifier: site?.index.includedArchiveIdentifiers?.first
                )
                
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

    /// Resolves a custom index icon for this row's reference.
    ///
    /// - Parameter site: Custom DocC source containing persisted index metadata.
    /// - Returns: Custom icon identifier when the source index contains one for this reference.
    private func customIconIdentifier(in site: DocCSource?) -> String? {
        guard let site else {
            return nil
        }

        let paths = [
            reference.url,
            reference.identifier
        ].compactMap(SearchSymbolResolver.normalizedDocumentationPath)

        guard !paths.isEmpty else {
            return nil
        }

        for language in site.index.interfaceLanguages.values.flatMap({ $0 }) {
            if let icon = customIconIdentifier(in: language, matchingAny: paths) {
                return icon
            }
        }

        return nil
    }

    private func customIconIdentifier(in language: DocCIndex.InterfaceLanguage, matchingAny paths: [String]) -> String? {
        if let path = language.path,
           let normalizedPath = SearchSymbolResolver.normalizedDocumentationPath(path),
           paths.contains(normalizedPath),
           let icon = language.icon {
            return icon
        }

        for child in language.children ?? [] {
            if let icon = customIconIdentifier(in: child, matchingAny: paths) {
                return icon
            }
        }

        return nil
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
    @Environment(TechnologyRootManager.self) private var manager
    
    let identifier: String
    let title: String
    let reference: Reference
    
    @Environment(\.tagFilters) var tagFilters
    @State private var shownReferences: [String : Bool] = [:]
    @State private var isLoading = false
    @State private var isExpanded = false
    /// Current disclosure-level deep-filter task.
    @State private var shownReferencesTask: Task<Void, Never>?
    /// Monotonic token used to ignore stale disclosure-level filter results.
    @State private var shownReferencesRequestID = UUID()
    
    /// Cached framework payload for this nested reference identifier.
    var framework: Framework? {
        documentationViewModel.framework(for: identifier)
    }
    
    /// Published fallback index used for local descendant filtering when the selected section does not carry one yet.
    private var publishedFilterIndex: DocCIndex? {
        documentationViewModel.technologies.appleTechnologies.compactMap(\.index).first ??
        documentationViewModel.appleDocCSiteRef?.index
    }
    
    /// Topic sections filtered to references visible under the active tags.
    private var topicSections: [VisibleFrameworkTopicSection] {
        (framework?.topicSections ?? []).compactMap { section in
            let rows = section.identifiers.compactMap { identifier -> FrameworkReferenceRow? in
                guard let subreference = framework?.references[identifier], let subtitle = subreference.title, isReferenceShown(subreference) else {
                    return nil
                }
                
                return FrameworkReferenceRow(
                    id: identifier,
                    reference: getReference(from: subreference),
                    title: subtitle,
                    referenceContext: framework?.references ?? [:]
                )
            }
            
            guard !rows.isEmpty else { return nil }
            
            return VisibleFrameworkTopicSection(id: section.id, title: section.title, rows: rows)
        }
    }
    
    /// Returns a copy of `reference` with inherited DocC site context.
    func getReference(from reference: Reference) -> Reference {
        var reference = reference
        reference.docCSite = self.reference.docCSite
        
        return reference
    }
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Group {
                if framework != nil, isExpanded {
                    ForEach(topicSections) { section in
                        FrameworkTopicSectionView(section: section, usesSecondaryHeader: true)
                    }
                } else if isExpanded {
                    ProgressView("Loading")
                        .controlSize(.small)
                }
            }
            .opacity(isLoading ? 0 : 1)
            .overlay {
                if isLoading {
                    ProgressView("Loading")
                        .controlSize(.small)
                }
            }
        } label: {
            DefaultListItem(reference: reference, title: title, referenceContext: framework?.references ?? [:])
                .showBackground(false)
                .showChevron(false)
                .background {
                    SelectedLineBackground(isSelected: navigationViewModel.reference == reference)
                        .padding(.leading, -10)
                }
        }
        .onChange(of: isExpanded, initial: false) { _, isExpanded in
            guard isExpanded else {
                cancelShownReferencesRefresh()
                return
            }
            
            scheduleShownReferencesRefresh(loadFrameworkFirst: true)
        }
        .onChange(of: tagFilters) {
            guard isExpanded else { return }
            
            scheduleShownReferencesRefresh(loadFrameworkFirst: false)
        }
        .onDisappear {
            cancelShownReferencesRefresh()
        }
    }
    
    /// Determines whether a nested reference should be shown.
    func isReferenceShown(_ reference: Reference) -> Bool {
        guard let shownReference = shownReferences[reference.identifier] else {
            return referenceMatchesFilters(reference, filters: tagFilters)
        }
        
        return shownReference
    }
    
    /// Starts a cancellable disclosure-level deep-filter refresh for the current expansion state.
    ///
    /// - Parameter loadFrameworkFirst: Whether the disclosure framework should be loaded before filtering.
    @MainActor
    private func scheduleShownReferencesRefresh(loadFrameworkFirst: Bool) {
        shownReferencesTask?.cancel()
        
        let requestID = UUID()
        shownReferencesRequestID = requestID
        shownReferencesTask = Task {
            if loadFrameworkFirst {
                await loadFrameworkIfNeeded()
            }
            
            await getShownReferences(requestID: requestID)
        }
    }
    
    /// Cancels any pending disclosure-level deep-filter refresh.
    @MainActor
    private func cancelShownReferencesRefresh() {
        shownReferencesTask?.cancel()
        shownReferencesTask = nil
        isLoading = false
    }
    
    /// Recomputes deep-filter visibility for references in this disclosure group.
    @MainActor
    func getShownReferences(requestID: UUID) async {
        guard isExpanded else {
            return
        }
        
        guard !tagFilters.isEmpty else {
            if shownReferencesRequestID == requestID {
                shownReferences.removeAll()
                isLoading = false
            }
            return
        }
        
        let references = (framework?.topicSections ?? []).flatMap { section in
            section.identifiers.compactMap { identifier in
                framework?.references[identifier]
            }
        }
        let filters = tagFilters
        let index = await manager.indexForFiltering(fallback: publishedFilterIndex)
        let frameworkResolver = documentationViewModel.frameworkResolver()
        
        isLoading = true
        let result = await visibilityByReferenceIdentifier(
            for: references,
            filters: filters,
            index: index,
            frameworkResolver: frameworkResolver
        )
        
        guard !Task.isCancelled,
              shownReferencesRequestID == requestID,
              isExpanded,
              tagFilters == filters
        else {
            return
        }
        
        documentationViewModel.cacheFrameworks(result.frameworksLoadedForCache)
        shownReferences = result.visibilityByIdentifier
        isLoading = false
    }
    
    /// Loads the nested framework only once the disclosure content is needed.
    private func loadFrameworkIfNeeded() async {
        guard framework == nil else {
            return
        }
        
        isLoading = true
        await documentationViewModel.fetchFramework(for: identifier, site: reference.docCSite)
        isLoading = false
    }
}

// MARK: File-Level Filter Functions

/// Checks whether a reference matches active filters using only local metadata.
///
/// - Parameters:
///   - reference: The reference to evaluate.
///   - filters: Active tag filters.
/// - Returns: `true` when the reference directly matches one of the filters.
private func referenceMatchesFilters(_ reference: Reference, filters: Set<TagFilters>) -> Bool {
    guard !filters.isEmpty else { return true }
    
    if filters.contains(.beta) && reference.beta == true {
        return true
    }
    
    if filters.contains(.deprecated) && reference.deprecated == true {
        return true
    }
    
    return false
}

/// Checks whether an index node or any indexed descendants match active filters.
///
/// - Parameters:
///   - node: Index node to evaluate.
///   - filters: Active tag filters.
/// - Returns: `true` when the node or a descendant is beta/deprecated as requested.
private func indexNodeMatchesFilters(_ node: DocCIndex.InterfaceLanguage, filters: Set<TagFilters>) -> Bool {
    if filters.contains(.beta) && node.isBeta {
        return true
    }
    
    if filters.contains(.deprecated) && node.isDeprecated {
        return true
    }
    
    return node.children?.contains { child in
        indexNodeMatchesFilters(child, filters: filters)
    } == true
}

/// Finds the index node matching a reference.
///
/// - Parameters:
///   - reference: Reference whose path should be located in the index.
///   - index: Index to search.
/// - Returns: Matching index node, if one exists.
private func indexNode(for reference: Reference, in index: DocCIndex) -> DocCIndex.InterfaceLanguage? {
    let paths = [
        reference.url,
        reference.identifier
    ].compactMap(normalizedDocumentationPath)
    
    guard !paths.isEmpty else {
        return nil
    }
    
    for node in index.interfaceLanguages.values.flatMap({ $0 }) {
        if let match = indexNode(in: node, matchingAny: paths) {
            return match
        }
    }
    
    return nil
}

/// Recursively finds an index node whose path matches any normalized reference path.
///
/// - Parameters:
///   - node: Index node to search.
///   - paths: Normalized paths to match.
/// - Returns: Matching index node, if one exists.
private func indexNode(in node: DocCIndex.InterfaceLanguage, matchingAny paths: [String]) -> DocCIndex.InterfaceLanguage? {
    if let path = normalizedDocumentationPath(node.path), paths.contains(path) {
        return node
    }
    
    for child in node.children ?? [] {
        if let match = indexNode(in: child, matchingAny: paths) {
            return match
        }
    }
    
    return nil
}

/// Normalizes a DocC URL, identifier, or path for index matching.
///
/// - Parameter value: Raw path-like value to normalize.
/// - Returns: Lowercase documentation path.
private func normalizedDocumentationPath(_ value: String?) -> String? {
    guard let value, !value.isEmpty else {
        return nil
    }
    
    if let url = URL(string: value) {
        let path = url.path()
        guard !path.isEmpty else {
            return nil
        }
        
        return path.lowercased()
    }
    
    return value.hasPrefix("/") ? value.lowercased() : "/\(value.lowercased())"
}

/// Checks whether a reference or any nested members satisfy active filters.
///
/// This prefers the framework index for descendant checks and only falls back to loading nested frameworks when no index node
/// can be matched for the reference.
///
/// - Parameters:
///   - reference: The reference to evaluate.
///   - filters: Active tag filters.
///   - index: Optional framework index used to inspect descendants without loading nested frameworks.
///   - frameworkResolver: Sendable resolver used to fetch nested frameworks.
/// - Returns: Visibility plus any framework loaded while checking descendants.
private func referenceFilterResult(
    _ reference: Reference,
    filters: Set<TagFilters>,
    index: DocCIndex?,
    frameworkResolver: DocumentationFrameworkResolver
) async -> ReferenceVisibilityResult {
    if referenceMatchesFilters(reference, filters: filters) {
        return ReferenceVisibilityResult(identifier: reference.identifier, isShown: true)
    }
    
    if let index, let node = indexNode(for: reference, in: index) {
        return ReferenceVisibilityResult(
            identifier: reference.identifier,
            isShown: indexNodeMatchesFilters(node, filters: filters)
        )
    }
    
    guard referenceHasSubParts(reference) else {
        return ReferenceVisibilityResult(identifier: reference.identifier, isShown: false)
    }
    
    guard let framework = try? await frameworkResolver.fetchFramework(for: reference.identifier, site: reference.docCSite) else {
        return ReferenceVisibilityResult(identifier: reference.identifier, isShown: false)
    }
    
    return ReferenceVisibilityResult(
        identifier: reference.identifier,
        isShown: frameworkContainsReferenceMatchingFilters(framework, filters: filters),
        loadedFramework: framework
    )
}

/// Checks whether a fetched framework payload contains a matching reference.
///
/// - Parameters:
///   - framework: Framework payload to inspect.
///   - filters: Active tag filters.
/// - Returns: `true` when any reference in the payload directly matches the filters.
private func frameworkContainsReferenceMatchingFilters(_ framework: Framework, filters: Set<TagFilters>) -> Bool {
    (framework.topicSections ?? []).contains { section in
        section.identifiers.contains { identifier in
            guard let reference = framework.references[identifier] else {
                return false
            }
            
            return referenceMatchesFilters(reference, filters: filters)
        }
    }
}

/// Computes deep-filter visibility away from the main actor with bounded framework fetch concurrency.
///
/// - Parameters:
///   - references: References to evaluate.
///   - filters: Active tag filters.
///   - index: Optional framework index used to inspect descendants before falling back to framework loads.
///   - frameworkResolver: Sendable framework resolver used to fetch nested frameworks.
/// - Returns: Visibility and loaded frameworks that should be published into the shared cache.
private func visibilityByReferenceIdentifier(
    for references: [Reference],
    filters: Set<TagFilters>,
    index: DocCIndex?,
    frameworkResolver: DocumentationFrameworkResolver,
    maxConcurrentChecks: Int = 4
) async -> VisibilityComputationResult {
    let workerCount = min(max(maxConcurrentChecks, 1), references.count)
    guard workerCount > 0 else { return .empty }
    
    let iterator = ReferenceVisibilityIterator(references: references)
    return await withTaskGroup(of: VisibilityComputationResult.self, returning: VisibilityComputationResult.self) { group in
        for _ in 0..<workerCount {
            group.addTask {
                var partialResult = VisibilityComputationResult.empty
                
                while let reference = await iterator.next() {
                    if Task.isCancelled { break }
                    let result = await referenceFilterResult(
                        reference,
                        filters: filters,
                        index: index,
                        frameworkResolver: frameworkResolver
                    )
                    partialResult.visibilityByIdentifier[result.identifier] = result.isShown
                    if let loadedFramework = result.loadedFramework {
                        partialResult.frameworksLoadedForCache[result.identifier] = loadedFramework
                    }
                }
                
                return partialResult
            }
        }
        
        var result = VisibilityComputationResult.empty
        for await partialResult in group {
            result.merge(partialResult)
        }
        
        return result
    }
}

/// Thread-safe iterator used to bound concurrent reference visibility checks.
private actor ReferenceVisibilityIterator {
    /// References waiting to be checked.
    private let references: [Reference]
    /// Index of the next reference to hand to a worker.
    private var nextIndex = 0
    
    /// Creates an iterator for a batch of references.
    ///
    /// - Parameter references: References that should be evaluated.
    init(references: [Reference]) {
        self.references = references
    }
    
    /// Returns the next reference to evaluate.
    ///
    /// - Returns: The next reference, or `nil` when all references have been claimed.
    func next() -> Reference? {
        guard nextIndex < references.count else { return nil }
        defer { nextIndex += 1 }
        return references[nextIndex]
    }
}

/// Combined result for a bounded deep-filter visibility computation.
private struct VisibilityComputationResult: Sendable {
    /// Visibility keyed by reference identifier.
    var visibilityByIdentifier: [String : Bool]
    /// Frameworks loaded while filtering, keyed by the same identifier used for cache lookup.
    var frameworksLoadedForCache: [String : Framework]
    
    /// Empty visibility computation result.
    static let empty = VisibilityComputationResult(visibilityByIdentifier: [:], frameworksLoadedForCache: [:])
    
    /// Merges a partial worker result into this result.
    ///
    /// - Parameter other: Partial result produced by one worker.
    mutating func merge(_ other: VisibilityComputationResult) {
        visibilityByIdentifier.merge(other.visibilityByIdentifier) { _, newValue in newValue }
        frameworksLoadedForCache.merge(other.frameworksLoadedForCache) { _, newValue in newValue }
    }
}

/// Visibility result for one reference.
private struct ReferenceVisibilityResult: Sendable {
    /// Identifier of the checked reference.
    var identifier: String
    /// Whether the reference should be visible for the active filters.
    var isShown: Bool
    /// Framework loaded while checking descendants, if any.
    var loadedFramework: Framework?
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
