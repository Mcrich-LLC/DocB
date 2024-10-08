//
//  ArticleView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/6/24.
//

import SwiftUI

struct ArticleView: View {
    @EnvironmentObject var documentationViewModel: DocumentationViewModel
    let reference: Reference
    
    @State var article: Article?
    
    var body: some View {
        VStack {
            if let article {
                _ArticleView(article: article)
            } else {
                Text("Loading...")
            }
        }
            .task {
                do {
                    let article = try await documentationViewModel.fetchArticle(for: reference.identifier)
                    
                    self.article = article
                } catch {
                    print(error)
                }
            }
    }
}

private struct _ArticleView: View {
    let article: Article
    
    var body: some View {
        ScrollView {
            VStack {
                heading
                // Main Content
                ForEach(article.primaryContentSections) { section in
                    switch section.kind {
                    case .content:
                        VStack {
                            ForEach(section.content ?? []) { content in
                                ArticleContentView(content: content, article: article)
                                    .padding(.top, content.type == .heading ? nil : 0)
                            }
                        }
                    case .declarations:
                        // TODO: Add declarations support
                        ForEach(section.declarations ?? []) { declaration in
                            DeclarationContentView(content: declaration, article: article)
                        }
                    }
                }
                Spacer()
            }
            .padding()
        }
    }
    
    @ViewBuilder
    var heading: some View {
        VStack(spacing: 20) {
            HStack(spacing: 15) {
                Text(article.metadata.roleHeading)
                    .foregroundStyle(.secondary)
                headingBadge(article.metadata)
            }
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(article.metadata.title)
                .font(.title)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
            if let abstract = article.abstract {
                AbstractView(abstract: abstract)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            WrappingHStack(alignment: .leading, horizontalSpacing: 15) {
                ForEach(article.metadata.platforms ?? []) { platform in
                    PlatformCapsule(platform: platform)
                }
            }
        }
    }
    
    @ViewBuilder
    func headingBadge(_ metadata: Article.Metadata) -> some View {
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
