//
//  AddBookmarkView.swift
//  Developer Documentation
//
//  Created by Morris Richman on 3/19/26.
//

import SwiftUI
import SwiftData

struct AddBookmarkView: View {
    /// The collections saved in SwiftData
    @Query(sort: \BookmarkCollection.lastUpdatedDate, animation: .default) private var collections: [BookmarkCollection] = []
    
    @Environment(\.modelContext) private var modelContext
    
    /// The IDs of collections the user has selected for a bookmark to be saved in.
    @State private var selectedCollections: Set<UUID> = []
    @State private var isShowingCreateCollectionAlert: Bool = false
    @State private var createCollectionTitleString = ""
    @State private var errorAlert: Error?
    
    var body: some View {
        List {
            ForEach(collections) { collection in
                if let title = collection.title {
                    Toggle(isOn: collectionBinding(for: collection.id), label: {
                        Label(title, systemSymbol: .folder)
                    })
                    .toggleStyle(.button)
                }
            }
        }
        .navigationTitle("Add Bookmark")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                ToolbarCloseButton()
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    
                } label: {
                    Label("Add", systemSymbol: .plus)
                }
            }
        }
        .alert("Create Collection", isPresented: $isShowingCreateCollectionAlert) {
            TextField("Collection Name", text: $createCollectionTitleString)
            CancelButton {
                createCollectionTitleString = ""
            }
            Button("Create", action: createCollection)
        } message: {
            Text("Enter the name of your new collection.")
        }
        .alert(for: $errorAlert)

    }
    
    func createCollection() {
        guard !createCollectionTitleString.isEmpty else {
            return
        }
        
        let collection = BookmarkCollection(title: createCollectionTitleString, bookmarks: [])
        createCollectionTitleString = ""
        
        do {
            modelContext.insert(collection)
            try modelContext.save()
            
            self.selectedCollections.insert(collection.id)
        } catch {
            print(error)
            self.errorAlert = error
        }
    }
    
    func collectionBinding(for id: UUID) -> Binding<Bool> {
        Binding {
            selectedCollections.contains(id)
        } set: { isSelected in
            switch isSelected {
            case true:
                selectedCollections.insert(id)
            case false:
                selectedCollections.remove(id)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AddBookmarkView()
            .modelContainer(for: [Bookmark.self, BookmarkCollection.self])
    }
}
