//
//  NavigationLinkButton.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/8/24.
//

import SwiftUI

struct HomepageNavigationLinkButton<Content: View>: View {
    @EnvironmentObject var navigationViewModel: NavigationViewModel
    @EnvironmentObject var documentationViewModel: DocumentationViewModel
    
    @ViewBuilder
    let label: Content
    
    var shouldShowBackground: Bool = true
    
    var body: some View {
        if UIDevice.current.userInterfaceIdiom != .phone {
            MacOSAgnosticButton {
                navigationViewModel.setReference(nil)
                navigationViewModel.removeLastPath(navigationViewModel.path.count)
                
                if let homepage = documentationViewModel.homepage {
                    navigationViewModel.appendPath(homepage)
                }
            } label: {
                label
            }
            .background {
                if navigationViewModel.isUsingSplitView {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .padding(-10)
                        .foregroundStyle(Color(uiColor: .tertiarySystemFill))
                        .opacity((navigationViewModel.reference == nil && shouldShowBackground) ? 1 : 0)
                }
            }
        } else {
            if let homepage = documentationViewModel.homepage {
                NavigationLink(value: homepage) {
                    label
                }
            }
        }
    }
    
    func showBackground(_ bool: Bool) -> Self {
        var view = self
        view.shouldShowBackground = bool
        
        return view
    }
}

struct ReferenceNavigationLinkButton<Content: View>: View {
    @EnvironmentObject var navigationViewModel: NavigationViewModel
    @EnvironmentObject var documentationViewModel: DocumentationViewModel
    let reference: Reference
    
    @ViewBuilder
    let label: Content
    
    var shouldShowBackground: Bool = true
    
    var isSelected: Bool {
        navigationViewModel.reference?.isEqual(to: reference) == true
    }
    
    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom != .phone {
                MacOSAgnosticButton {
                    if let url = URL(string: reference.identifier),
                       let moduleString = Array(url.pathComponents.dropFirst(2)).first,
                       let technologies = documentationViewModel.technologies,
                       let groups = technologies.groups {
                        let identifier = "\(url.scheme ?? "doc")://\(url.host() ?? "com.apple.Documentation")/documentation/\(moduleString)"
                        
                        if let technologyGroup = groups.first(where: { $0.technologies.contains(where: { $0.destination.identifier == identifier }) }),
                           let technology = technologyGroup.technologies.first(where: { $0.destination.identifier == identifier }) {
                            withAnimation(.snappy) {
                                navigationViewModel.setTechnology(technology)
                            }
                        }
                    }
                    
                    navigationViewModel.setReference(reference)
                } label: {
                    label
                }
                .background {
                    if navigationViewModel.isUsingSplitView {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .padding(-10)
                            .foregroundStyle(Color(uiColor: .tertiarySystemFill))
                            .opacity((isSelected && shouldShowBackground) ? 1 : 0)
                    }
                }
            } else {
                NavigationLink(value: reference) {
                    label
                }
            }
        }
        .hoverEffect()
    }
    
    func showBackground(_ bool: Bool) -> Self {
        var view = self
        view.shouldShowBackground = bool
        
        return view
    }
}

struct TechnologyNavigationLinkButton<Content: View>: View {
    @EnvironmentObject var navigationViewModel: NavigationViewModel
    let technology: Technologies.FrameworkSection
    
    @ViewBuilder
    let label: Content
    
    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom != .phone {
                MacOSAgnosticButton {
//                    navigationViewModel.technologyHistoryUpdatingIsEnabled = false
//                    defer {
                        navigationViewModel.technologyHistoryUpdatingIsEnabled = true
//                    }
                    
                    withAnimation(.snappy) {
                        navigationViewModel.setTechnology(technology)
                    }
                    
                    if navigationViewModel.isUsingSplitView {
                        // swiftlint:disable line_length
                        let reference = Reference(title: technology.title, abstract: nil, identifier: technology.destination.identifier, kind: nil, type: "", url: nil, role: nil, fragments: nil, deprecated: nil, beta: nil, variants: nil, images: nil)
                        // swiftlint:enable line_length
                        navigationViewModel.setReference(reference)
                    }
                } label: {
                    label
                }
                .background {
                    if navigationViewModel.isUsingSplitView {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .padding(-10)
                            .foregroundStyle(Color(uiColor: .tertiarySystemFill))
                            .opacity(navigationViewModel.technology?.destination.identifier.lowercased() == technology.destination.identifier.lowercased() ? 1 : 0)
                    }
                }
            } else {
                NavigationLink(value: technology) {
                    label
                }
            }
        }
        .hoverEffect()
    }
}
