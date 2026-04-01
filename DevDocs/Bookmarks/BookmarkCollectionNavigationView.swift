//
//  BookmarkCollectionNavigationView.swift
//  DevDocs
//
//  Created by Morris Richman on 3/19/26.
//

import SwiftUI

struct BookmarkCollectionNavigationView: View {
    @Environment(DocumentationViewModel.self) private var documentationViewModel
    @Environment(NavigationViewModel.self) private var navigationViewModel
    @Environment(\.modelContext) private var modelContext
    let collection: BookmarkCollection
    
    func technology(for url: URL) -> TechnologyTypes? {
        documentationViewModel.technologies.first(where: { $0.url.absoluteString.contains(url.absoluteString) })
    }
    
    var body: some View {
        List {
            if (collection.bookmarks ?? []).isEmpty {
                ContentUnavailableView(
                    "You haven't saved any bookmarks",
                    systemImage: "folder.badge.questionmark",
                    description: Text("Visit a documentation page and tap the ") + Text(Image(systemSymbol: .bookmark)) + Text(" button to get started.")
                )
                    .listRowBackground(Color.clear)
            } else {
                ForEach(Array(collection.bookmarksWithinUrls.keys).sorted(by: { (technology(for: $0)?.primaryName ?? "") < (technology(for: $1)?.primaryName ?? "") }), id: \.self) { url in
                    let tech = technology(for: url)
                    
                    Section(tech?.primaryName ?? url.host() ?? url.absoluteString) {
                        SectionView(collection: collection, url: url)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        guard let bookmark = collection.bookmarks?[index] else { continue }
                        modelContext.delete(bookmark)
                    }
                    try? modelContext.save()
                }
            }
        }
        .navigationTitle(collection.title ?? "")
        .toolbar {
            #if !os(macOS)
            if !(collection.bookmarks ?? []).isEmpty {
                EditButton()
            }
            #endif
        }
        .onDisappear {
            if navigationViewModel.reference == nil && navigationViewModel.technology == nil && !navigationViewModel.isUsingSplitView {
                navigationViewModel.goBackward(updatePath: false)
            }
        }
    }
}

private struct SectionView: View {
    let collection: BookmarkCollection
    let url: URL
    @Environment(DocumentationViewModel.self) private var documentationViewModel
    @Environment(NavigationViewModel.self) private var navigationViewModel
    
    func technology(for url: URL) -> TechnologyTypes? {
        documentationViewModel.technologies.first(where: { $0.url.absoluteString.contains(url.absoluteString) })
    }
    
    var body: some View {
        ForEach(collection.bookmarksWithinUrls[url] ?? []) { bookmark in
            if let reference = bookmark.asReferenceWithDocCSite(from: documentationViewModel.technologies), let text = bookmark.title ?? bookmark.identifier {
                Group {
                    if technology(for: url) == nil {
                        AddSourceButton(bookmark: bookmark) {
                            Label(text: text)
                        }
                    } else {
                        ReferenceNavigationLinkButton(reference: reference) {
                            Label(text: text)
                        }
                        .bookmarkNavigator()
                    }
                }
                .tint(Color.primary)
            }
        }
    }
    
    private struct Label: View {
        let text: String
        @Environment(NavigationViewModel.self) private var navigationViewModel
        
        var body: some View {
            HStack {
                Text(text)
                
                if !navigationViewModel.isUsingSplitView {
                    Spacer()
                    ChevronView()
                }
            }
        }
    }
}

private struct AddSourceButton<Content: View>: View {
    let bookmark: Bookmark
    @ViewBuilder let label: Content
    @State private var isShowingAddPopover = false
    @Environment(DocumentationViewModel.self) private var documentationViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var errorAlert: Error?
    
    var body: some View {
        Button {
            isShowingAddPopover.toggle()
        } label: {
            label
        }
        .confirmationDialog("Add Source?", isPresented: $isShowingAddPopover, titleVisibility: .visible) {
            CancelButton {}
            Button("Add") {
                Task {
                    await addDocCSite()
                }
            }
            .buttonStyle(.borderedProminent)
        } message: {
            Text("This bookmark references a source that has not been added. Do you want to add it?")
        }
        .alert(for: $errorAlert)
    }
    
    private func addDocCSite() async {
        guard let initialUrl = bookmark.siteBaseURL else { return }
        
        let scheme = initialUrl.scheme ?? "https"
        
        let urlString = "\(scheme)://\(initialUrl.absoluteString.replacingOccurrences(of: "\(scheme)://", with: ""))"
        guard let url = URL(string: urlString) else { return }
        print(url.absoluteString)
        
        do {
            try await documentationViewModel.addTechnology(baseUrl: url, modelContext: modelContext, overrideName: nil)
        } catch {
            self.errorAlert = error
        }
    }
}

#Preview {
    @Previewable @State var isShowing = false
    
    NavigationStack {
        Text("Hello World")
            .toolbar {
                Button("Test") {
                    isShowing.toggle()
                }
                .confirmationDialog("Test", isPresented: $isShowing, titleVisibility: .automatic) {
                    Button("Cancel") {}
                } message: {
                    Text("Lorem Ipsum")
                }
            }
    }
}
