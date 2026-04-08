//
//  BookmarkCollectionsView.swift
//  DocB
//
//  Created by Morris Richman on 3/19/26.
//

import SwiftUI
import SwiftData

/// Displays saved bookmark collections and supports creating, deleting, and opening collections.
struct BookmarkCollectionsView: View {
    /// Navigation state used to synchronize split-view and stack navigation behavior.
    @Environment(NavigationViewModel.self) private var navigationViewModel
    
    /// The collections saved in SwiftData
    @Query(sort: \BookmarkCollection.lastUpdatedDate, animation: .default) private var collections: [BookmarkCollection] = []
    
    /// SwiftData context used to create and delete collections.
    @Environment(\.modelContext) private var modelContext
    /// Controls presentation of the create-collection alert.
    @State private var isShowingCreateCollectionAlert = false
    /// User-entered collection title for creation flow.
    @State private var createCollectionTitleString = ""
    /// Captures persistence failures for alert presentation.
    @State private var errorAlert: Error?
    /// Controls presentation of the delete-confirmation alert.
    @State private var showDeleteCollectionAlert = false
    /// Collection currently targeted for deletion confirmation.
    @State private var currentCollection: BookmarkCollection?
    
    var body: some View {
        List {
            if collections.isEmpty {
                ContentUnavailableView("No saved collections", systemImage: "folder.badge.questionmark", description: Text("You haven't created any collections. Create one to save your bookmarks."))
                    .listRowBackground(Color.clear)
            } else {
                ForEach(collections) { collection in
                    if let title = collection.title {
                        BookmarkCollectionNavigationLink(collection: collection) {
                            HStack {
                                Label(title, systemSymbol: .folder)
                                
                                if !navigationViewModel.isUsingSplitView {
                                    Spacer()
                                    ChevronView()
                                }
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                currentCollection = collection
                                showDeleteCollectionAlert = true
                            } label: {
                                Label("Delete", systemSymbol: .trash)
                            }
                        }
                        .tint(Color.primary)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        currentCollection = collections[index]
                        showDeleteCollectionAlert = true
                    }
                }
            }
        }
        .navigationTitle("Bookmarks")
        .toolbar {
            #if !os(macOS)
            EditButton()
            #endif
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
        .alert("Are You Sure?", isPresented: $showDeleteCollectionAlert, presenting: currentCollection) { collection in
            Button("Cancel", role: .cancel) {
                currentCollection = nil
            }
            Button("Delete", role: .destructive) {
                do {
                    modelContext.delete(collection)
                    currentCollection = nil
                    try modelContext.save()
                } catch {
                    errorAlert = error
                }
            }
        } message: { collection in
            Text("Deleting \"\(collection.title ?? "")\" cannot be undone.")
        }
        .onDisappear {
            if navigationViewModel.bookmarkCollection == nil && !navigationViewModel.isUsingSplitView {
                navigationViewModel.goBackward(updatePath: false)
            }
        }
    }
    
    /// Creates and persists a new bookmark collection from the alert input.
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
