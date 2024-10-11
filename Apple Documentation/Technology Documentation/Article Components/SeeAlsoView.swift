//
//  SeeAlsoView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/8/24.
//

import SwiftUI

struct SeeAlsoView: View {
    let article: Article
    
    var body: some View {
        if let seeAlsoSections = article.seeAlsoSections {
            VStack(alignment: .leading, spacing: 20) {
                Text("See Also")
                    .font(.title2)
                    .bold()
                
                ForEach(seeAlsoSections) { section in
                    Section {
                        LinksGridListView(identifiers: section.identifiers, style: .list, article: article)
                    } header: {
                        Text(section.title)
                            .font(.title3)
                            .bold()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
