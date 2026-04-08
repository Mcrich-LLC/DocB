//
//  EditBookmarkCollectionView.swift
//  DocB
//

import SwiftUI
import SwiftData
import SFSymbols

/// A view for creating or editing a bookmark collection.
public struct EditBookmarkCollectionView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    /// The collection currently being edited, or nil if creating a new collection.
    public let collectionToEdit: BookmarkCollection?
    
    /// The local state for the user-entered collection title.
    @State private var title: String
    /// The local state for the selected SF Symbol icon name.
    @State private var sfSymbolName: String
    /// Holds any error that occurs during save for presentation in an alert.
    @State private var errorAlert: Error?
    
    /// Optional closure called when a collection is successfully created or updated.
    public var onCollectionSaved: ((BookmarkCollection) -> Void)?
    
    /// Creates a new view for editing or creating a bookmark collection.
    /// - Parameters:
    ///   - collectionToEdit: The collection currently being edited, or nil if creating a new collection.
    ///   - onCollectionSaved: Optional closure called when a collection is successfully created or updated.
    public init(collectionToEdit: BookmarkCollection? = nil, onCollectionSaved: ((BookmarkCollection) -> Void)? = nil) {
        self.collectionToEdit = collectionToEdit
        self.onCollectionSaved = onCollectionSaved
        self._title = State(initialValue: collectionToEdit?.title ?? "")
        self._sfSymbolName = State(initialValue: collectionToEdit?.sfSymbolName ?? "folder")
    }
    
    /// The content and behavior of the view.
    public var body: some View {
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
    
    /// Creates a new collection or updates the existing one and saves it to the model context.
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
