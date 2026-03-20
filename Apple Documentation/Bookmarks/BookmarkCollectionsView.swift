//
//  BookmarkCollectionsView.swift
//  Developer Documentation
//
//  Created by Morris Richman on 3/19/26.
//

import SwiftUI
import SwiftData

struct BookmarkCollectionsView: View {
    
    /// The collections saved in SwiftData
    @Query(sort: \BookmarkCollection.lastUpdatedDate, animation: .default) private var collections: [BookmarkCollection] = []
    
    @Environment(\.modelContext) private var modelContext
    @State private var isShowingCreateCollectionAlert = false
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
                        Label(title, systemSymbol: .folder)
                    }
                }
            }
        }
        .navigationTitle("Bookmarks")
        .toolbar {
            EditButton()
            Button {
                isShowingCreateCollectionAlert.toggle()
            } label: {
                Label("Add Collection", systemSymbol: .plus)
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
        } catch {
            print(error)
            self.errorAlert = error
        }
    }
}

#Preview {
    BookmarkCollectionsView()
}
