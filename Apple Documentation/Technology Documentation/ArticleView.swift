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
                Text("\(article)")
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

//#Preview {
//    ArticleView()
//}
