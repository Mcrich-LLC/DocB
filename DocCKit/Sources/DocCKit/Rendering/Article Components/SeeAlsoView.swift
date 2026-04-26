//
//  SeeAlsoView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/8/24.
//

import SwiftUI

/// SeeAlsoView renders a reusable SwiftUI view.
struct SeeAlsoView: View {
    /// Article payload containing "See Also" sections.
    let article: Article
    var body: some View {
        if let seeAlsoSections = article.seeAlsoSections {
            VStack(alignment: .leading, spacing: 20) {
                Text("See Also")
                    .font(.title2)
                    .bold()
                
                ForEach(seeAlsoSections) { section in
                    Section {
                        LinksGridListView(identifiers: section.identifiers, style: .list, references: article.references)
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
