//
//  RelationshipsView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/8/24.
//

import SwiftUI

/// RelationshipsView renders a reusable SwiftUI view.
struct RelationshipsView: View {
    let article: Article
    @Environment(NavigationViewModel.self) var navigationViewModel
    
    var body: some View {
        if let relationshipsSections = article.relationshipsSections {
            VStack {
                Text("Relationships")
                    .font(.title2)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ForEach(relationshipsSections) { section in
                    Section {
                        LinksGridListView(identifiers: section.identifiers, style: .list, references: article.references, navigationViewModel: navigationViewModel)
                    } header: {
                        if let title = section.title {
                            Text(title)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
