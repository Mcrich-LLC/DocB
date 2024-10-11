//
//  RelationshipsView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/8/24.
//

import SwiftUI

struct RelationshipsView: View {
    let article: Article
    
    var body: some View {
        if let relationshipsSections = article.relationshipsSections {
            VStack {
                Text("Relationships")
                    .font(.title2)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ForEach(relationshipsSections) { section in
                    Section(header: Text(section.title)) {
                        LinksGridListView(identifiers: section.identifiers, style: .list, article: article)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
