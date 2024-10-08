//
//  ArticleView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/6/24.
//

import SwiftUI

struct ArticleView: View {
    @EnvironmentObject var documentationViewModel: DocumentationViewModel
    let reference: Framework.Reference
    
    @State var article: Article?
    
    var body: some View {
        VStack {
            if let article {
                articleView(article)
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
    
    @ViewBuilder
    func articleView(_ article: Article) -> some View {
        ScrollView {
            VStack {
                VStack(spacing: 20) {
                    Text(article.metadata.roleHeading)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(article.metadata.title)
                        .font(.title)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let abstract = article.abstract?.first, let text = abstract.text {
                        Text(text)
                            .font(.title3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    WrappingHStack(alignment: .leading, horizontalSpacing: 15) {
                        ForEach(article.metadata.platforms ?? []) { platform in
                            PlatformCapsule(platform: platform)
                        }
                    }
                }
                Spacer()
            }
            .padding()
        }
    }
}

//#Preview {
//    ArticleView()
//}
