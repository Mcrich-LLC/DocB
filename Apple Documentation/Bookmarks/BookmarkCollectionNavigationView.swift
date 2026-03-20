//
//  BookmarkCollectionNavigationView.swift
//  Developer Documentation
//
//  Created by Morris Richman on 3/19/26.
//

import SwiftUI

struct BookmarkCollectionNavigationView: View {
    let collection: BookmarkCollection
    
    var body: some View {
        List {
            ForEach(collection.bookmarks ?? []) { bookmark in
                if let reference = bookmark.asReference, let text = bookmark.title ?? bookmark.identifier {
                    ReferenceNavigationLinkButton(reference: reference) {
                        Text(text)
                    }
                }
            }
        }
        .navigationTitle(collection.title ?? "")
    }
}
