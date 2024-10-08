//
//  ArticleView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/6/24.
//

import SwiftUI

struct ArticleView: View {
    
    @EnvironmentObject var navigationViewModel: NavigationViewModel
    @EnvironmentObject var documentationViewModel: DocumentationViewModel
    let reference: Framework.Reference
    
    @State var article: Article?
    
    var body: some View {
        ScrollView {
            VStack {
                if let article {
                    Heading(article)
                }
            }
            .padding()
        }
        .id(reference)
        .task {
            await loadArticle()
        }
        .onChange(of: navigationViewModel.reference) {
            Task { await loadArticle() }
        }
    }
    
    func loadArticle() async {
        do {
            let article = try await documentationViewModel.fetchArticle(for: reference.identifier)
            
            self.article = article
        } catch {
            print(error)
        }
    }
    
    @ViewBuilder
    func Heading(_ article: Article) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 15) {
                Text(article.metadata.roleHeading)
                    .foregroundStyle(.secondary)
                HeadingBadge(article.metadata)
            }
            .font(.headline)
            
            Text(article.metadata.title)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if let abstract = article.abstract?.first, let text = abstract.text {
                Text(text)
                    .font(.title3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            WrappingHStack(alignment: .leading, horizontalSpacing: 10) {
                ForEach(article.metadata.platforms ?? []) { platform in
                    PlatformCapsule(platform: platform)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                let url = documentationViewModel.jsonUrl(for: reference.identifier)!.absoluteString.replacingOccurrences(of: "doc://com.apple.documentation", with: "https://developer.apple.com").replacingOccurrences(of: ".json", with: "")
                
                ShareLink(item: URL(string: url)!) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .labelsHidden()
                
                Button("Download", systemImage: "arrow.down.circle.fill") {
                    
                }
                .labelsHidden()
                
                Button("Save", systemImage: "bookmark") {
                    
                }
                .labelsHidden()
            }
        }
    }
    
    @ViewBuilder
    func HeadingBadge(_ metadata: Article.Metadata) -> some View {
        if let platforms = metadata.platforms {
            if platforms.filter({ $0.beta == true }).count == platforms.count {
                ArticleBadge(badge: .beta)
            }
            if platforms.filter({ $0.deprecated == true || $0.deprecatedAt != nil }).count == platforms.count {
                ArticleBadge(badge: .deprecated)
            }
        }
    }
}

//#Preview {
//    ArticleView()
//}

/*
 
 
 //
 //  ArticleView.swift
 //  Apple Documentation
 //
 //  Created by Morris Richman on 10/6/24.
 //
 
 import SwiftUI
 
 struct ArticleView: View {
 @EnvironmentObject var navigationViewModel: NavigationViewModel
 @EnvironmentObject var documentationViewModel: DocumentationViewModel
 let reference: Framework.Reference
 
 @State var article: Article?
 @State var showTitle: Bool = false
 
 var body: some View {
 ScrollView {
 VStack(alignment: .leading) {
 if let article {
 VStack(alignment: .leading, spacing: 15) {
 if let role = reference.role {
 Label {
 Text(article.metadata.roleHeading)
 } icon: {
 Image(systemName: role.roleImage).foregroundStyle(.secondary)
 .foregroundStyle(.secondary)
 }
 }
 
 Text(article.metadata.title)
 .font(.largeTitle)
 .fontWeight(.semibold)
 
 
 }
 .toolbar {
 ToolbarItemGroup(placement: .topBarTrailing) {
 let url = documentationViewModel.jsonUrl(for: reference.identifier)!.absoluteString.replacingOccurrences(of: "doc://com.apple.documentation", with: "https://developer.apple.com").replacingOccurrences(of: ".json", with: "")
 
 ShareLink(item: URL(string: url)!) {
 Label("Share", systemImage: "square.and.arrow.up")
 }
 .labelsHidden()
 
 Button("Download", systemImage: "arrow.down.circle.fill") {
 
 }
 .labelsHidden()
 
 Button("Save", systemImage: "bookmark") {
 
 }
 .labelsHidden()
 }
 }
 .onAppear {
 showTitle = false
 }
 .onDisappear {
 showTitle = true
 }
 }
 }
 .frame(maxWidth: .infinity, alignment: .leading)
 .padding()
 .multilineTextAlignment(.leading)
 .navigationBarTitleDisplayMode(.inline)
 .navigationTitle(showTitle ? reference.title ?? "" : "")
 }
 .task {
 await loadArticle()
 }
 .onChange(of: navigationViewModel.reference) {
 Task {
 await loadArticle()
 }
 }
 .id(reference.identifier)
 .transition(.opacity)
 }
 
 func loadArticle() async {
 do {
 let article = try await documentationViewModel.fetchArticle(for: reference.identifier)
 
 self.article = article
 } catch {
 print(error)
 }
 }
 }
 
 func format(_ contentArray: [ContentStruct]) -> String {
 var result = ""
 
 for content in contentArray {
 let text = content.text ?? ""
 
 if content.type == "paragraph" {
 result += text
 } else if content.type == "reference", let identifier = content.identifier {
 result += "[\(text)](\(identifier))"
 }
 }
 
 return result.trimmingCharacters(in: .whitespacesAndNewlines)
 }
 
 */
