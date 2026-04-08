//
//  EditBookmarkCollectionView.swift
//  DocB
//

import SwiftUI
import SwiftData
import SFSymbols

/// A view for creating or editing a bookmark collection.
struct EditBookmarkCollectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let collectionToEdit: BookmarkCollection?
    
    @State private var title: String
    @State private var sfSymbolName: String
    @State private var errorAlert: Error?
    
    /// Optional closure called when a collection is successfully created or updated.
    var onCollectionSaved: ((BookmarkCollection) -> Void)?
    
    init(collectionToEdit: BookmarkCollection? = nil, onCollectionSaved: ((BookmarkCollection) -> Void)? = nil) {
        self.collectionToEdit = collectionToEdit
        self.onCollectionSaved = onCollectionSaved
        self._title = State(initialValue: collectionToEdit?.title ?? "")
        self._sfSymbolName = State(initialValue: collectionToEdit?.sfSymbolName ?? "folder")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Collection Name", text: $title)
                    SFSymbolPicker("Icon", selection: $sfSymbolName)
                }
            }
            .formStyle(.grouped)
            #if os(macOS)
            .frame(minWidth: 350, minHeight: 180)
            #endif
            .navigationTitle(collectionToEdit == nil ? "New Collection" : "Edit Collection")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(collectionToEdit == nil ? "Create" : "Done") {
                        saveCollection()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert(for: $errorAlert)
        }
    }
    
    private func saveCollection() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        
        do {
            let collectionToPass: BookmarkCollection
            if let collection = collectionToEdit {
                // Edit existing
                collection.title = trimmedTitle
                collection.sfSymbolName = sfSymbolName
                collection.lastUpdatedDate = .now
                collectionToPass = collection
            } else {
                // Create new
                let newCollection = BookmarkCollection(
                    title: trimmedTitle,
                    sfSymbolName: sfSymbolName,
                    bookmarks: []
                )
                modelContext.insert(newCollection)
                collectionToPass = newCollection
            }
            try modelContext.save()
            onCollectionSaved?(collectionToPass)
            dismiss()
        } catch {
            print(error)
            errorAlert = error
        }
    }
}

#Preview {
    EditBookmarkCollectionView()
}
