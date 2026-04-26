//
//  HomepageView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/11/24.
//

import SwiftUI
import DocCKit

/// HomepageView renders a reusable SwiftUI view.
struct HomepageView: View {
    /// Parsed homepage payload.
    let homepage: HomepageParser
    
    var body: some View {
        ScrollView {
            HomepageScrollContent(homepage: homepage)
        }
        .lineSpacing(4)
        .scrollContentBackground(.hidden)
        .background(Color.homepageBackground)
    }
}

/// Renders homepage content inside the stable scroll shell.
private struct HomepageScrollContent: View {
    /// Parsed homepage payload.
    let homepage: HomepageParser
    
    @Environment(NavigationViewModel.self) private var navigationViewModel
    
    var body: some View {
        verticalStacker(spacing: 60) {
            ForEach(homepage.sections) { section in
                HomepageSectionContent(section: section, homepage: homepage)
            }
            
            if let legalNotices = homepage.legalNotices {
                LegalNoticesView(legalNotices: legalNotices)
                    .padding(.horizontal, 25)
            }
        }
        .padding([.bottom], 25)
    }
    
    /// Chooses lazy layout when the homepage is in split-view navigation.
    @ViewBuilder
    private func verticalStacker(spacing: CGFloat? = nil, @ViewBuilder content: () -> some View) -> some View {
        if navigationViewModel.isUsingSplitView {
            LazyVStack(spacing: spacing, content: content)
        } else {
            VStack(spacing: spacing, content: content)
        }
    }
}

/// Renders one top-level homepage section.
private struct HomepageSectionContent: View {
    /// Homepage section payload.
    let section: HomepageParser.Section
    /// Parsed homepage payload.
    let homepage: HomepageParser
    
    var body: some View {
        switch section.kind {
        case .hero:
            HomepageHero(section: section, homepage: homepage)
        case .homepageResources:
            HomepageResources(section: section, homepage: homepage)
                .padding(.horizontal, 25)
        case .section:
            HomepageSection(section: section, homepage: homepage)
                .padding(.horizontal, 25)
        }
    }
}
