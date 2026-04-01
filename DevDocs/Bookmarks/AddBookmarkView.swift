//
//  AddBookmarkView.swift
//  DevDocs
//
//  Created by Morris Richman on 3/19/26.
//

import SwiftUI
import SwiftData

struct AddBookmarkView: View {
    /// The reference to be saved to bookmark collections.
    let reference: Reference
    
    /// The collections saved in SwiftData
    @Query(sort: \BookmarkCollection.lastUpdatedDate, animation: .default) private var collections: [BookmarkCollection]
    /// All bookmarks saved in SwiftData
    @Query private var bookmarks: [Bookmark]
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
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
                        let existingBookmark = bookmarks.first(where: { $0.identifier == reference.identifier && $0.collection?.id == collection.id })
                        let isSelected = existingBookmark != nil
                        
                        HStack {
                            Button {
                                toggleBookmark(existingBookmark, collection: collection)
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
        .alert("Create Collection", isPresented: $isShowingCreateCollectionAlert) {
            TextField("Collection Name", text: $createCollectionTitleString)
            CancelButton {
                createCollectionTitleString = ""
            }
            Button("Create") {
                Task {
                    await createCollection()
                }
            }
        } message: {
            Text("Enter the name of your new collection.")
        }
        .alert(for: $errorAlert)
    }
    
    @ViewBuilder
    var doneButton: some View {
        Button {
            dismiss()
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
    
    func createCollection() async {
        guard !createCollectionTitleString.isEmpty else {
            return
        }
        
        let collection = BookmarkCollection(title: createCollectionTitleString, bookmarks: [])
        createCollectionTitleString = ""
        
        do {
            modelContext.insert(collection)
            try modelContext.save()
            
            try? await Task.sleep(nanoseconds: 25)
            toggleBookmark(nil, collection: collection)
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
