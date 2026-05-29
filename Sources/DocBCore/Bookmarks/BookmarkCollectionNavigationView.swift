//
//  BookmarkCollectionNavigationView.swift
//  DocB
//
//  Created by Morris Richman on 3/19/26.
//

import SwiftUI
import DocCKit

/// Shows bookmarks in a single collection grouped by source technology and provides per-item navigation.
struct BookmarkCollectionNavigationView: View {
    @Environment(DocumentationViewModel.self) private var documentationViewModel
    @Environment(NavigationViewModel.self) private var navigationViewModel
    @Environment(DocBCloudSyncEngine.self) private var docBCloudSyncEngine
    @Environment(\.modelContext) private var modelContext
    /// Collection whose bookmarks are presented in grouped sections.
    let collection: BookmarkCollection
    
    /// Resolves the matching technology entry for a bookmark source URL when available.
    func technology(for url: URL) -> TechnologyTypes? {
        documentationViewModel.technologies.first(where: { $0.url.absoluteString.contains(url.absoluteString) })
    }
    
    /// Bookmark source groups sorted by their display technology name.
    private var sortedBookmarkGroups: [BookmarkSourceGroup] {
        collection.bookmarksWithinUrls.keys.map { url in
            BookmarkSourceGroup(url: url, technology: technology(for: url))
        }
        .sorted { lhs, rhs in
            (lhs.technology?.primaryName ?? "") < (rhs.technology?.primaryName ?? "")
        }
    }
    
    var body: some View {
        List {
            if (collection.bookmarks ?? []).isEmpty {
                ContentUnavailableView(
                    "You haven't saved any bookmarks",
                    systemImage: "folder.badge.questionmark",
                    description: Text("Visit a documentation page and tap the ") + Text(Image(systemSymbol: .bookmark)) + Text(" button to get started.")
                )
                    .listRowBackground(Color.clear)
            } else {
                ForEach(sortedBookmarkGroups) { group in
                    Section(group.technology?.primaryName ?? group.url.host() ?? group.url.absoluteString) {
                        SectionView(collection: collection, url: group.url, technology: group.technology)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        guard let bookmark = collection.bookmarks?[index] else { continue }
                        modelContext.delete(bookmark)
                    }
                    try? modelContext.save()
                }
            }
        }
        .refreshable {
            await docBCloudSyncEngine.fetchRemoteChanges()
        }
        .navigationTitle(collection.title ?? "")
        .toolbar {
            #if !os(macOS)
            if !(collection.bookmarks ?? []).isEmpty {
                EditButton()
            }
            #endif
        }
        .onDisappear {
            if navigationViewModel.reference == nil && navigationViewModel.technology == nil && !navigationViewModel.isUsingSplitView {
                navigationViewModel.goBackward(updatePath: false)
            }
        }
    }
}

/// Precomputed bookmark source group used to avoid repeated technology lookups during list rendering.
private struct BookmarkSourceGroup: Identifiable {
    /// Source URL shared by all bookmarks in this section.
    let url: URL
    /// Matching loaded technology, when available.
    let technology: TechnologyTypes?
    
    /// Stable identity for SwiftUI diffing.
    var id: URL { url }
}

/// Section renderer for bookmarks grouped under a single source URL.
private struct SectionView: View {
    /// Parent bookmark collection being rendered.
    let collection: BookmarkCollection
    /// Grouped source URL represented by this section.
    let url: URL
    /// Matching loaded technology for this source, when available.
    let technology: TechnologyTypes?
    @Environment(DocumentationViewModel.self) private var documentationViewModel
    @Environment(NavigationViewModel.self) private var navigationViewModel
    
    @State private var frameworks: [String : Framework] = [:]
    
    var body: some View {
        ForEach(collection.bookmarksWithinUrls[url] ?? []) { bookmark in
            if let reference = bookmark.asReferenceWithDocCSite(from: documentationViewModel.technologies), let text = bookmark.title ?? bookmark.identifier {
                let siteDestinationIdentifier = reference.docCSite?.allFrameworkSections.map(\.destination).first?.identifier
                
                Group {
                    if technology == nil {
                        AddSourceButton(bookmark: bookmark) {
                            Label(text: text, reference: reference, referenceContext: frameworks[siteDestinationIdentifier ?? ""]?.references ?? [:])
                        }
                    } else {
                        ReferenceNavigationLinkButton(reference: reference) {
                            Label(text: text, reference: reference, referenceContext: frameworks[siteDestinationIdentifier ?? ""]?.references ?? [:])
                        }
                        .bookmarkNavigator()
                    }
                }
                .tintColor(Color.primary)
                .onAppear {
                    guard let siteDestinationIdentifier, frameworks[siteDestinationIdentifier] == nil else { return }
                    frameworks[siteDestinationIdentifier] = documentationViewModel.framework(for: siteDestinationIdentifier)
                }
            }
        }
    }
    
    /// Bookmark row label used inside grouped bookmark sections.
    private struct Label: View {
        /// Row title shown for a bookmark entry.
        let text: String
        /// The general reference that was found in the bookmark
        let reference: Reference
        /// Neighboring references from the same DocC payload.
        let referenceContext: [String: Reference]
        @Environment(NavigationViewModel.self) private var navigationViewModel
        
        var body: some View {
            HStack {
                let site = reference.docCSite ?? navigationViewModel.technology?.docCSite
                SearchResultSymbolBadge(
                    symbolKind: SearchSymbolResolver.symbolKind(
                        for: reference,
                        title: text,
                        site: site,
                        referenceContext: referenceContext
                    ),
                    customIconIdentifier: customIconIdentifier(in: site),
                    customIconSite: site,
                    customIconArchiveIdentifier: site?.index.includedArchiveIdentifiers?.first
                )
                
                Text(text)
                
                if !navigationViewModel.isUsingSplitView {
                    Spacer()
                    ChevronView()
                }
            }
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
    }
}

/// Row button that offers to add a missing source for a bookmark target.
private struct AddSourceButton<Content: View>: View {
    /// Bookmark whose missing source can be added as a DocC site.
    let bookmark: Bookmark
    /// Custom label content displayed for the button row.
    @ViewBuilder let label: Content
    /// Controls presentation of the add-source confirmation dialog.
    @State private var isShowingAddPopover = false
    @Environment(DocumentationViewModel.self) private var documentationViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// Captures add-source failures for alert presentation.
    @State private var errorAlert: Error?
    
    var body: some View {
        Button {
            isShowingAddPopover.toggle()
        } label: {
            label
        }
        .confirmationDialog("Add Source?", isPresented: $isShowingAddPopover, titleVisibility: .visible) {
            CancelButton {}
            Button("Add") {
                Task {
                    await addDocCSite()
                }
            }
            .buttonStyle(.borderedProminent)
        } message: {
            Text("This bookmark references a source that has not been added. Do you want to add it?")
        }
        .alert(for: $errorAlert)
    }
    
    /// Normalizes and adds the bookmark's source URL as a DocC site.
    private func addDocCSite() async {
        guard let initialUrl = bookmark.siteBaseURL else { return }
        
        let scheme = initialUrl.scheme ?? "https"
        
        let urlString = "\(scheme)://\(initialUrl.absoluteString.replacingOccurrences(of: "\(scheme)://", with: ""))"
        guard let url = URL(string: urlString) else { return }
        print(url.absoluteString)
        
        do {
            try await documentationViewModel.addTechnology(baseUrl: url, overrideName: nil)
        } catch {
            self.errorAlert = error
        }
    }
}

#Preview {
    @Previewable @State var isShowing = false
    
    NavigationStack {
        Text("Hello World")
            .toolbar {
                Button("Test") {
                    isShowing.toggle()
                }
                .confirmationDialog("Test", isPresented: $isShowing, titleVisibility: .automatic) {
                    Button("Cancel") {}
                } message: {
                    Text("Lorem Ipsum")
                }
            }
    }
}
