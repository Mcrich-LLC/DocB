//
//  HomepageView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/11/24.
//

import SwiftUI

/// A view that renders the main homepage content, including hero sections, resources, and sections.
struct HomepageView: View {
    /// The parsed homepage data model.
    let homepage: HomepageParser
    
    @Environment(NavigationViewModel.self) var navigationViewModel
    
    @ViewBuilder
    private func verticalStacker(spacing: CGFloat? = nil, @ViewBuilder content: () -> some View) -> some View {
        if navigationViewModel.isUsingSplitView {
            LazyVStack(spacing: spacing, content: content)
        } else {
            VStack(spacing: spacing, content: content)
        }
    }
    
    var body: some View {
        ScrollView {
            verticalStacker(spacing: 60) {
                ForEach(homepage.sections) { section in
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
                if let legalNotices = homepage.legalNotices {
                    LegalNoticesView(legalNotices: legalNotices)
                        .padding(.horizontal, 25)
                }
            }
            .padding([.bottom], 25)
        }
        .toolbar(content: {
            if navigationViewModel.isUsingSplitView {
                ToolbarItemGroup(placement: .navigation) {
                    Group {
                        Button("Backward", systemImage: "chevron.left") {
                            navigationViewModel.goBackward()
                        }
                        .disabled(!navigationViewModel.previousHistoryExists)
                        
                        Button("Forward", systemImage: "chevron.right") {
                            navigationViewModel.goForward()
                        }
                        .disabled(!navigationViewModel.futureHistoryExists)
                    }
                }
            }
        })
        .lineSpacing(4)
        .scrollContentBackground(.hidden)
        .background(Color.homepageBackground)
    }
}
