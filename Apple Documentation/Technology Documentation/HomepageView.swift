//
//  HomepageView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/11/24.
//

import SwiftUI

struct HomepageView: View {
    let homepage: HomepageParser
    
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(homepage.sections) { section in
                    switch section.kind {
                    case .hero:
                        HomepageHero(section: section, homepage: homepage)
                    case .homepageResources: EmptyView()
                    case .section:
                        VStack {
                            if let body = section.body {
                                switch body.kind {
                                case .links:
                                    VStack {
                                        if let title = section.title {
                                            Text(title)
                                                .font(.title2)
                                                .bold()
                                        }
                                        if let links = section.body?.links {
                                            ForEach(links) { link in
                                                LinksGridListView(identifiers: link.items, style: link.style, references: self.homepage.references)
                                            }
                                        }
                                    }
                                case .cards: EmptyView()
                                case .homepageLinks: EmptyView()
                                default: EmptyView()
                                }
                            }
                        }
                    }
                }
            }
            .padding([.horizontal, .bottom], 25)
        }
        .lineSpacing(4)
        .scrollContentBackground(.hidden)
        .background(Color.homepageBackground)
    }
}
