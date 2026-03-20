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
    
    var body: some View {
        List {
            ForEach(collection.bookmarks ?? []) { bookmark in
                if let reference = bookmark.asReferenceWithDocCSite(from: documentationViewModel.technologies), let text = bookmark.title ?? bookmark.identifier {
                    ReferenceNavigationLinkButton(reference: reference) {
                        Text(text)
                    }
                    .removeLastPathComponentFirst(true)
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
