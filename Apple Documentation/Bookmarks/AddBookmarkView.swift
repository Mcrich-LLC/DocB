//
//  AddBookmarkView.swift
//  Developer Documentation
//
//  Created by Morris Richman on 3/19/26.
//

import SwiftUI
import SwiftData

struct AddBookmarkView: View {
    /// The reference to be saved to bookmark collections.
    let reference: Reference
    
    /// The collections saved in SwiftData
    @Query(sort: \BookmarkCollection.lastUpdatedDate, animation: .default) private var collections: [BookmarkCollection] = []
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
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
        .onAppear {
            do {
                let identifier = reference.identifier
                
                let descriptor = FetchDescriptor<Bookmark>(
                    predicate: #Predicate { bookmark in
                        bookmark.identifier == identifier
                    }
                )
                
                let bookmarks = try modelContext.fetch(descriptor)
                
                self.selectedCollections = Set(bookmarks.compactMap(\.collection).map(\.id))
            } catch {
                print(error)
                errorAlert = error
            }
        }
        .navigationTitle("Add Bookmark")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if #available(iOS 26.0, macOS 26.0, *) {
                    doneButton
                        .buttonStyle(.glassProminent)
                } else {
                    doneButton
                }
            }
        }
        .overlay(alignment: .bottomTrailing, content: {
            if #available(iOS 26.0, macOS 26.0, *) {
                addButton
                .buttonStyle(.glass)
            } else {
                addButton
                .buttonStyle(.bordered)
            }
        })
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
    
    @ViewBuilder
    var doneButton: some View {
        Button {
            do {
                try addBookmarks()
                dismiss()
            } catch {
                print(error)
                errorAlert = error
            }
        } label: {
            Label("Done", systemSymbol: .checkmark)
        }
        .labelStyle(.iconOnly)
    }
    
    @ViewBuilder
    var addButton: some View {
        Button {
            isShowingCreateCollectionAlert.toggle()
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
    
    func addBookmarks() throws {
        let bookmarksFetchDescriptor = FetchDescriptor<Bookmark>(predicate: #Predicate { bookmark in
            bookmark.identifier == (reference.identifier as String?)
        })
        
        let existingBookmarksForReference = try modelContext.fetch(bookmarksFetchDescriptor)
        
        for bookmark in existingBookmarksForReference where selectedCollections.contains(bookmark.collection?.id ?? UUID()) {
            modelContext.delete(bookmark)
        }
        
        for collectionID in selectedCollections {
            guard let collection = collections.first(where: { $0.id == collectionID }),
                    collection.bookmarks?.contains(where: { existingBookmarksForReference.contains($0) }) != true
            else { continue }
            
            let bookmark = try Bookmark(reference: reference)
            
            collection.bookmarks?.append(bookmark)
        }
        try modelContext.save()
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
        AddBookmarkView(reference: .init(identifier: "", type: ""))
            .modelContainer(for: [Bookmark.self, BookmarkCollection.self])
    }
}
