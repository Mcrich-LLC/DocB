//
//  BookmarkCollectionNavigationView.swift
//  DocB
//
//  Created by Morris Richman on 3/19/26.
//

import SwiftUI

/// Shows bookmarks in a single collection grouped by source technology and provides per-item navigation.
struct BookmarkCollectionNavigationView: View {
    /// Documentation source state used to resolve bookmark URLs to known technologies.
    @Environment(DocumentationViewModel.self) private var documentationViewModel
    /// Navigation state used when returning from this collection detail view.
    @Environment(NavigationViewModel.self) private var navigationViewModel
    /// SwiftData context used for deleting bookmarks from the collection.
    @Environment(\.modelContext) private var modelContext
    /// Collection whose bookmarks are presented in grouped sections.
    let collection: BookmarkCollection
    
    /// Resolves the matching technology entry for a bookmark source URL when available.
    func technology(for url: URL) -> TechnologyTypes? {
        documentationViewModel.technologies.first(where: { $0.url.absoluteString.contains(url.absoluteString) })
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
                ForEach(Array(collection.bookmarksWithinUrls.keys).sorted(by: { (technology(for: $0)?.primaryName ?? "") < (technology(for: $1)?.primaryName ?? "") }), id: \.self) { url in
                    let tech = technology(for: url)
                    
                    Section(tech?.primaryName ?? url.host() ?? url.absoluteString) {
                        SectionView(collection: collection, url: url)
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

private struct SectionView: View {
    /// Parent bookmark collection being rendered.
    let collection: BookmarkCollection
    /// Grouped source URL represented by this section.
    let url: URL
    /// Documentation source state used to resolve source labels.
    @Environment(DocumentationViewModel.self) private var documentationViewModel
    /// Navigation state used to adapt row affordances in split view.
    @Environment(NavigationViewModel.self) private var navigationViewModel
    
    /// Resolves the matching technology entry for a grouped URL.
    func technology(for url: URL) -> TechnologyTypes? {
        documentationViewModel.technologies.first(where: { $0.url.absoluteString.contains(url.absoluteString) })
    }
    
    var body: some View {
        ForEach(collection.bookmarksWithinUrls[url] ?? []) { bookmark in
            if let reference = bookmark.asReferenceWithDocCSite(from: documentationViewModel.technologies), let text = bookmark.title ?? bookmark.identifier {
                Group {
                    if technology(for: url) == nil {
                        AddSourceButton(bookmark: bookmark) {
                            Label(text: text)
                        }
                    } else {
                        ReferenceNavigationLinkButton(reference: reference) {
                            Label(text: text)
                        }
                        .bookmarkNavigator()
                    }
                }
                .tint(Color.primary)
            }
        }
    }
    
    private struct Label: View {
        /// Row title shown for a bookmark entry.
        let text: String
        /// Navigation state used to decide whether chevron affordance is shown.
        @Environment(NavigationViewModel.self) private var navigationViewModel
        
        var body: some View {
            HStack {
                Text(text)
                
                if !navigationViewModel.isUsingSplitView {
                    Spacer()
                    ChevronView()
                }
            }
        }
    }
}

private struct AddSourceButton<Content: View>: View {
    /// Bookmark whose missing source can be added as a DocC site.
    let bookmark: Bookmark
    /// Custom label content displayed for the button row.
    @ViewBuilder let label: Content
    /// Controls presentation of the add-source confirmation dialog.
    @State private var isShowingAddPopover = false
    /// Documentation model used to add the missing DocC source.
    @Environment(DocumentationViewModel.self) private var documentationViewModel
    /// SwiftData context used by add-technology operations.
    @Environment(\.modelContext) private var modelContext
    /// Size class reserved for future presentation branching.
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
            try await documentationViewModel.addTechnology(baseUrl: url, modelContext: modelContext, overrideName: nil)
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
