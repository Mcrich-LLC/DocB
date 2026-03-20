//
//  BookmarkCollectionNavigationView.swift
//  Developer Documentation
//
//  Created by Morris Richman on 3/19/26.
//

import SwiftUI

struct BookmarkCollectionNavigationView: View {
    @Environment(DocumentationViewModel.self) private var documentationViewModel
    @Environment(\.modelContext) private var modelContext
    let collection: BookmarkCollection
    
    func technology(for url: URL) -> TechnologyTypes? {
        documentationViewModel.technologies.first(where: { $0.url.absoluteString.contains(url.absoluteString) })
    }
    
    var body: some View {
        List {
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
        .navigationTitle(collection.title ?? "")
        .toolbar {
            #if !os(macOS)
            EditButton()
            #endif
        }
    }
}

private struct SectionView: View {
    let collection: BookmarkCollection
    let url: URL
    @Environment(DocumentationViewModel.self) private var documentationViewModel
    
    var body: some View {
        ForEach(collection.bookmarksWithinUrls[url] ?? []) { bookmark in
            if let reference = bookmark.asReferenceWithDocCSite(from: documentationViewModel.technologies), let text = bookmark.title ?? bookmark.identifier {
                ReferenceNavigationLinkButton(reference: reference) {
                    Text(text)
                }
            }
        }
    }
}
