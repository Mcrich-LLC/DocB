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
            if collections.isEmpty {
                ContentUnavailableView("No saved collections", systemImage: "folder.badge.questionmark", description: Text("You haven't created any collections. Create one to save your bookmarks."))
                    .listRowBackground(Color.clear)
            } else {
                ForEach(collections) { collection in
                    if let title = collection.title {
                        let isSelected = selectedCollections.contains(collection.id)
                        
                        HStack {
                            Button {
                                switch isSelected {
                                case true:
                                    selectedCollections.remove(collection.id)
                                case false:
                                    selectedCollections.insert(collection.id)
                                }
                            } label: {
                                Label(title, systemSymbol: .folder)
                            }
                            .tint(Color.primary)
                            
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
        .toolbar {
            ToolbarItem(placement: .navigation) {
                ToolbarCloseButton()
            }
            ToolbarItemGroup(placement: .primaryAction) {
                EditButton()
                Button {
                    isShowingCreateCollectionAlert.toggle()
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
}

#Preview {
    NavigationStack {
        AddBookmarkView()
            .modelContainer(for: [Bookmark.self, BookmarkCollection.self])
    }
}
