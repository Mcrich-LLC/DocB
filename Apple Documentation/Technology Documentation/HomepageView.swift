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
            LazyVStack(spacing: 20) {
                ForEach(homepage.sections) { section in
                    switch section.kind {
                    case .hero:
                        HomepageHero(section: section, homepage: homepage)
                    case .homepageResources: EmptyView()
                    case .section:
                        HomepageSection(section: section, homepage: homepage)
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
