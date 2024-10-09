//
//  NavigationLinkButton.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/8/24.
//

import SwiftUI

struct ReferenceNavigationLinkButton<Content: View>: View {
    @EnvironmentObject var navigationViewModel: NavigationViewModel
    @EnvironmentObject var documentationViewModel: DocumentationViewModel
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    let reference: Reference
    
    @ViewBuilder
    let label: Content
    
    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass != .compact {
            Button {
                navigationViewModel.reference = reference
                
                if let url = URL(string: reference.identifier),
                   let moduleString = Array(url.pathComponents.dropFirst(2)).first,
                   let technologies = documentationViewModel.technologies,
                   let groups = technologies.groups
                {
                    print(url.pathComponents)
                    let identifier = "\(url.scheme ?? "doc")://\(url.host() ?? "com.apple.Documentation")/documentation/\(moduleString)"
                    
                    if let technologyGroup = groups.first(where: { $0.technologies.contains(where: { $0.destination.identifier == identifier }) }),
                       let technology = technologyGroup.technologies.first(where: { $0.destination.identifier == identifier }) {
                        withAnimation(.snappy) {
                            navigationViewModel.technology = technology
                        }
                    }
                }
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
                
                let reference = Reference(title: technology.title, abstract: nil, identifier: technology.destination.identifier, kind: nil, type: "", url: nil, role: nil, fragments: nil, deprecated: nil, variants: nil, images: nil)
                navigationViewModel.reference = reference
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
