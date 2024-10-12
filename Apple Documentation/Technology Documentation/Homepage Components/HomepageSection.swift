//
//  HomepageSection.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/11/24.
//

import SwiftUI

struct HomepageSection: View {
    let section: HomepageParser.Section
    let homepage: HomepageParser
    
    var body: some View {
        VStack {
            if let title = section.title {
                Text(title)
                    .font(.title2)
                    .bold()
            }
            
            if let sectionContent = section.content {
                ForEach(sectionContent) { content in
                    ArticleContentView(content: content, references: homepage.references)
                }
            }
            
            if let body = section.body {
                switch body.kind {
                case .links:
                    VStack {
                        if let links = section.body?.links {
                            ForEach(links) { link in
                                LinksGridListView(identifiers: link.items, style: link.style, references: self.homepage.references)
                            }
                        }
                    }
                case .cards: EmptyView()
                case .homepageLinks: EmptyView()
                }
            }
        }
    }
}
