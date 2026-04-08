//
//  CreateBookmarkCollectionView.swift
//  DocB
//

import SwiftUI
import SwiftData
import SFSymbols

/// A view for creating a new bookmark collection.
struct CreateBookmarkCollectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var title: String = ""
    @State private var sfSymbolName: String = "folder"
    @State private var errorAlert: Error?
    
    /// Optional closure called when a collection is successfully created.
    var onCollectionCreated: ((BookmarkCollection) -> Void)?
    
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
            .navigationTitle("New Collection")
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
                    Button("Create") {
                        createCollection()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert(for: $errorAlert)
        }
    }
    
    private func createCollection() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        
        let collection = BookmarkCollection(
            title: trimmedTitle,
            sfSymbolName: sfSymbolName,
            bookmarks: []
        )
        
        do {
            modelContext.insert(collection)
            try modelContext.save()
            onCollectionCreated?(collection)
            dismiss()
        } catch {
            print(error)
            errorAlert = error
        }
    }
}

#Preview {
    CreateBookmarkCollectionView()
}
