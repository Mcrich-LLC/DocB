//
//  HomepageView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/11/24.
//

import SwiftUI

struct HomepageView: View {
    let homepage: HomepageParser
    
    @EnvironmentObject var navigationViewModel: NavigationViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 60) {
                ForEach(homepage.sections) { section in
                    switch section.kind {
                    case .hero:
                        HomepageHero(section: section, homepage: homepage)
                    case .homepageResources:
                        HomepageResources(section: section, homepage: homepage)
                    case .section:
                        HomepageSection(section: section, homepage: homepage)
                    }
                }
            }
            .padding([.horizontal, .bottom], 25)
        }
        .toolbar(content: {
            if navigationViewModel.isUsingSplitView {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Group {
                        Button("Backward", systemImage: "chevron.backward") {
                            navigationViewModel.goBackward()
                        }
                        .disabled(!navigationViewModel.previousHistoryExists)
                        
                        Button("Forward", systemImage: "chevron.forward") {
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
