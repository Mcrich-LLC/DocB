//
//  AddBookmarkView.swift
//  DocB
//
//  Created by Morris Richman on 3/19/26.
//

import SwiftUI
import SwiftData
import DocCKit

/// Lets the user add or remove the current reference across bookmark collections.
struct AddBookmarkView: View {
    /// The reference to be saved to bookmark collections.
    let reference: Reference
    
    /// The collections saved in SwiftData
    @Query(sort: \BookmarkCollection.lastUpdatedDate, animation: .default) private var collections: [BookmarkCollection]
    /// All bookmarks saved in SwiftData
    @Query private var bookmarks: [Bookmark]
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    /// Controls presentation of the "Create Collection" sheet.
    @State private var isShowingCreateCollectionSheet: Bool = false
    /// Captures persistence or conversion failures for alert display.
    @State private var errorAlert: Error?
    
    var body: some View {
        List {
            if collections.isEmpty {
                ContentUnavailableView("No saved collections", systemImage: "folder.badge.questionmark", description: Text("You haven't created any collections. Create one to save your bookmarks."))
                    .listRowBackground(Color.clear)
            } else {
                ForEach(collections) { collection in
                    if let title = collection.title {
                        let existingBookmark = bookmarks.first(where: { $0.identifier == reference.identifier && $0.collection?.id == collection.id })
                        let isSelected = existingBookmark != nil
                        
                        HStack {
                            Button {
                                toggleBookmark(existingBookmark, collection: collection)
                            } label: {
                                Label {
                                    Text(title)
                                } icon: {
                                    Image(systemName: collection.sfSymbolName ?? "folder")
                                        .foregroundStyle(collection.color)
                                }
                            }
                            .tintColor(Color.primary)
                            
                            Spacer()
                            
                            Image(systemSymbol: .checkmark)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 15, maxHeight: 15)
                                .opacity(isSelected ? 1 : 0)
                        }
                        .animation(.easeInOut.speed(1.4), value: isSelected)
                    }
                }
            }
        }
        .navigationTitle("Add Bookmark")
        #if !os(macOS)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                #if os(visionOS)
                doneButton
                #else
                if #available(iOS 26.0, macOS 26.0, *) {
                    doneButton
                        .buttonStyle(.glassProminent)
                } else {
                    doneButton
                }
                #endif
            }
        }
        #endif
        .overlay(alignment: .bottomTrailing, content: {
            #if os(visionOS)
            addButton
            #else
            if #available(iOS 26.0, macOS 26.0, *) {
                addButton
                .buttonStyle(.glass)
            } else {
                addButton
                .buttonStyle(.bordered)
            }
            #endif
        })
        .sheet(isPresented: $isShowingCreateCollectionSheet) {
            EditBookmarkCollectionView { collection in
                toggleBookmark(nil, collection: collection)
            }
        }
        .alert(for: $errorAlert)
    }
    
    /// Toolbar action that closes the current view.
    @ViewBuilder
    var doneButton: some View {
        Button {
            dismiss()
        } label: {
            Label("Done", systemSymbol: .checkmark)
        }
        .labelStyle(.iconOnly)
    }
    
    /// Floating action used to start creating a new collection.
    @ViewBuilder
    var addButton: some View {
        Button {
            isShowingCreateCollectionSheet.toggle()
        } label: {
            Label {
                Text("Add Collection")
            } icon: {
                Image(systemSymbol: .plus)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
            }
            .padding(7)
        }
        .buttonBorderShape(.circle)
        .labelStyle(.iconOnly)
        .padding([.trailing, .bottom], 15)
    }
    
    /// Adds the reference to the selected collection or removes the existing bookmark when present.
    func toggleBookmark(_ existingBookmark: Bookmark?, collection: BookmarkCollection) {
        do {
            if let existingBookmark {
                modelContext.delete(existingBookmark)
            } else {
                let bookmark = try Bookmark(reference: reference)
                
                if collection.bookmarks == nil {
                    collection.bookmarks = []
                }
                
                collection.bookmarks?.append(bookmark)
            }
            try modelContext.save()
        } catch {
            print(error)
            self.errorAlert = error
        }
    }
    
}

#Preview {
    NavigationStack {
        AddBookmarkView(reference: .init(identifier: "", type: ""))
            .modelContainer(for: [Bookmark.self, BookmarkCollection.self])
    }
}
