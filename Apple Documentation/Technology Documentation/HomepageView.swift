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
                    case .cards: EmptyView()
                    case .hero:
                        HomepageHero(section: section, homepage: homepage)
                    case .homepageLinks: EmptyView()
                    case .homepageResources: EmptyView()
                    case .links: EmptyView()
                    case .section: EmptyView()
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.homepageBackground)
    }
}
