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
    @Environment(NavigationViewModel.self) private var navigationViewModel
    
    /// The collections saved in SwiftData
    @Query(sort: \BookmarkCollection.lastUpdatedDate, animation: .default) private var collections: [BookmarkCollection] = []
    
    @Environment(\.modelContext) private var modelContext
    #if !os(macOS)
    @Environment(\.editMode) private var editMode
    #endif
    /// Controls presentation of the create-collection sheet.
    @State private var isShowingCreateCollectionSheet = false
    /// Collection currently targeted for editing.
    @State private var collectionToEdit: BookmarkCollection?
    /// Captures persistence failures for alert presentation.
    @State private var errorAlert: Error?
    /// Controls presentation of the delete-confirmation alert.
    @State private var showDeleteCollectionAlert = false
    /// Collection currently targeted for deletion confirmation.
    @State private var currentCollection: BookmarkCollection?
    
    /// A platform agnostic variable describing the edit state for the UI
    var isEditing: Bool {
        #if os(macOS)
        return false
        #else
        return editMode?.wrappedValue.isEditing ?? false
        #endif
    }
    
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
                                Label(title, systemImage: collection.sfSymbolName ?? "folder")
                                
                                if !navigationViewModel.isUsingSplitView && isEditing != true {
                                    Spacer()
                                    ChevronView()
                                }
                            }
                        }
                        #if !os(macOS)
                        .overriddenAction { navigate in
                            if editMode?.wrappedValue.isEditing == true {
                                collectionToEdit = collection
                            } else {
                                navigate()
                            }
                        }
                        #endif
                        .contextMenu {
                            Button {
                                collectionToEdit = collection
                            } label: {
                                Label("Edit", systemSymbol: .pencil)
                            }
                            Button(role: .destructive) {
                                currentCollection = collection
                                showDeleteCollectionAlert = true
                            } label: {
                                Label("Delete", systemSymbol: .trash)
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                collectionToEdit = collection
                            } label: {
                                Label("Edit", systemSymbol: .pencil)
                            }
                            .tint(.blue)
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
                isShowingCreateCollectionSheet.toggle()
            } label: {
                Label("Add Collection", systemSymbol: .plus)
            }
        }
        .sheet(isPresented: $isShowingCreateCollectionSheet) {
            EditBookmarkCollectionView()
        }
        .sheet(item: $collectionToEdit) { collection in
            EditBookmarkCollectionView(collectionToEdit: collection)
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
}

#Preview {
    BookmarkCollectionsView()
}
