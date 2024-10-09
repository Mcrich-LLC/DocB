//
//  NavigationLinkButton.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/8/24.
//

import SwiftUI

struct ReferenceNavigationLinkButton<Content: View>: View {
    @EnvironmentObject var navigationViewModel: NavigationViewModel
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    let reference: Reference
    
    @ViewBuilder
    let label: Content
    
    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass != .compact {
            Button {
                navigationViewModel.reference = reference
            } label: {
                label
            }
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .padding(-10)
                    .foregroundStyle(Color(uiColor: .tertiarySystemFill))
                    .opacity(navigationViewModel.reference == reference ? 1 : 0)
            }
        } else {
            NavigationLink(value: reference) {
                label
            }
        }
    }
}

struct TechnologyNavigationLinkButton<Content: View>: View {
    @EnvironmentObject var navigationViewModel: NavigationViewModel
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    let technology: Technologies.FrameworkSection
    
    @ViewBuilder
    let label: Content
    
    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass != .compact {
            Button {
                withAnimation(.snappy) {
                    navigationViewModel.technology = technology
                }
            } label: {
                label
            }
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .padding(-10)
                    .foregroundStyle(Color(uiColor: .tertiarySystemFill))
                    .opacity(navigationViewModel.technology == technology ? 1 : 0)
            }
        } else {
            NavigationLink(value: technology) {
                label
            }
        }
    }
}
