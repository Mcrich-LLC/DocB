//
//  BookmarkCollectionNavigationView.swift
//  Developer Documentation
//
//  Created by Morris Richman on 3/19/26.
//

import SwiftUI

struct BookmarkCollectionNavigationView: View {
    @Environment(DocumentationViewModel.self) private var documentationViewModel
    @Environment(NavigationViewModel.self) private var navigationViewModel
    @Environment(\.modelContext) private var modelContext
    let collection: BookmarkCollection
    
    func technology(for url: URL) -> TechnologyTypes? {
        documentationViewModel.technologies.first(where: { $0.url.absoluteString.contains(url.absoluteString) })
    }
    
    var body: some View {
        List {
            if (collection.bookmarks ?? []).isEmpty {
                ContentUnavailableView(
                    "You haven't created any bookmarks",
                    systemImage: "folder.badge.questionmark",
                    description: Text("Visit a documentation page and tap the ") + Text(Image(systemSymbol: .bookmark)) + Text(" button to get started.")
                )
                    .listRowBackground(Color.clear)
            } else {
                ForEach(Array(collection.bookmarksWithinUrls.keys).sorted(by: { (technology(for: $0)?.primaryName ?? "") < (technology(for: $1)?.primaryName ?? "") }), id: \.self) { url in
                    Section(technology(for: url)?.primaryName ?? url.host() ?? url.absoluteString) {
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
            if navigationViewModel.bookmarkCollection == nil && !navigationViewModel.isUsingSplitView {
                navigationViewModel.goBackward(updatePath: false)
            }
        }
    }
}

private struct SectionView: View {
    let collection: BookmarkCollection
    let url: URL
    @Environment(DocumentationViewModel.self) private var documentationViewModel
    @Environment(NavigationViewModel.self) private var navigationViewModel
    
    var body: some View {
        ForEach(collection.bookmarksWithinUrls[url] ?? []) { bookmark in
            if let reference = bookmark.asReferenceWithDocCSite(from: documentationViewModel.technologies), let text = bookmark.title ?? bookmark.identifier {
                ReferenceNavigationLinkButton(reference: reference) {
                    HStack {
                        Text(text)
                        
                        if !navigationViewModel.isUsingSplitView {
                            Spacer()
                            ChevronView()
                        }
                    }
                }
                .tint(Color.primary)
            }
        }
    }
}
