//
//  TopicsView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/8/24.
//

import SwiftUI

struct TopicsView: View {
    let article: Article
    @EnvironmentObject var navigationViewModel: NavigationViewModel
    
    var body: some View {
        if let topicSections = article.topicSections {
            VStack(alignment: .leading, spacing: 20) {
                Text("Topics")
                    .font(.title2)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ForEach(topicSections) { section in
                    Section {
                        LinksGridListView(identifiers: section.identifiers, style: article.topicSectionsStyle ?? .list, references: article.references, navigationViewModel: navigationViewModel)
                    } header: {
                        if let title = section.title {
                            Text(title)
                                .font(.title3)
                                .bold()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                }
            }
        }
    }
}

extension RangeExpression where Bound == String.Index {
    func nsRange<S: StringProtocol>(in string: S) -> NSRange { .init(self, in: string) }
}
