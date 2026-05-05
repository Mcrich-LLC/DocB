//
//  ArticleView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/6/24.
//

import SwiftUI
import SwiftData
import DocCKit

/// ArticleView coordinates DocB app state for a DocC article renderer.
struct ArticleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(NavigationViewModel.self) private var navigationViewModel
    @Environment(DocumentationViewModel.self) private var documentationViewModel
    
    /// Reference currently being displayed.
    let reference: Reference
    
    /// Whether the current reference is already bookmarked.
    @State private var isBookmarked = false
    /// Loaded article payload.
    @State private var article: Article?
    /// Controls Add Bookmark popover presentation.
    @State private var isShowingAddBookmark = false
    
    /// The general accent color.
    private var accentColor: Color? {
        let color = article?.metadata.color?.standardColorIdentifier.swiftUIColor ?? article?.metadata.role.accentColor
        
        // Keep contrast good
        guard color != .gray && color != .secondary && (article?.metadata.role != .article || article?.metadata.color?.standardColorIdentifier != nil) else {
            return nil
        }
        
        return color
    }
    
    var body: some View {
        Group {
            if let article {
                DocCArticleView(article: article, reference: reference, navigator: navigationViewModel)
            } else {
                ProgressView("Loading")
            }
        }
        .task(id: navigationViewModel.reference) {
            await loadArticle()
        }
        .id(reference)
        .onChange(of: documentationViewModel.preferedProgrammingLanguage) {
            Task {
                article = nil
                await loadArticle()
            }
        }
        .onChange(of: reference, initial: true) {
            getIfBookmarked()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
            Task {
                try? await Task.sleep(nanoseconds: 25)
                getIfBookmarked()
            }
        }
        .onDisappear {
            navigationViewModel.handleHistoryRemoval(for: reference)
        }
        .toolbar {
            ArticleToolbar(
                article: article,
                reference: reference,
                accentColor: accentColor,
                horizontalSizeClass: horizontalSizeClass,
                isBookmarked: $isBookmarked,
                isShowingAddBookmark: $isShowingAddBookmark
            )
        }
        .tintColor(accentColor)
        .accentColor(accentColor)
    }
    
    /// Refreshes bookmark state for the currently displayed reference.
    private func getIfBookmarked() {
        do {
            let descriptor = FetchDescriptor<Bookmark>(
                predicate: #Predicate { bookmark in
                    bookmark.identifier == (reference.identifier as String?)
                }
            )
            
            let bookmarks = try modelContext.fetch(descriptor)
            isBookmarked = !bookmarks.isEmpty
        } catch {
            print(error)
            isBookmarked = false
        }
    }
    
    /// Fetches and assigns full article content for the current reference.
    private func loadArticle() async {
        do {
            article = try await documentationViewModel.fetchArticle(for: reference.identifier, site: reference.docCSite)
        } catch {
            print(error)
        }
    }
}

/// Renders the DocB-specific toolbar controls for article actions and variants.
private struct ArticleToolbar: ToolbarContent {
    /// Loaded article payload.
    let article: Article?
    /// Reference currently being displayed.
    let reference: Reference
    /// Accent color resolved by the parent article view.
    let accentColor: Color?
    /// Horizontal size class used to size bookmark popovers.
    let horizontalSizeClass: UserInterfaceSizeClass?
    /// Whether the current reference is already bookmarked.
    @Binding var isBookmarked: Bool
    /// Controls Add Bookmark popover presentation.
    @Binding var isShowingAddBookmark: Bool
    
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Group {
                if let url = reference.externalURL {
                    ShareLink(item: url) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
                
                Button("Save", systemImage: isBookmarked ? "bookmark.fill" : "bookmark") {
                    isShowingAddBookmark.toggle()
                }
                .animation(.default, value: isBookmarked)
                .popover(isPresented: $isShowingAddBookmark) {
                    NavigationStack {
                        AddBookmarkView(reference: reference)
                            .frame(minWidth: horizontalSizeClass == .regular ? 400 : nil, minHeight: horizontalSizeClass == .regular ? 400 : nil)
                    }
                }
                
                if let variants = article?.variants {
                    LanguagePicker(variants: variants)
                }
            }
            .tintColor(accentColor)
        }
    }
}
