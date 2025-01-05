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
        MacOSAgnosticButton {
            navigationViewModel.setReference(nil)
            navigationViewModel.removeLastPath(navigationViewModel.path.count)
            
            navigationViewModel.appendPath(.homepage)
        } label: {
            label
        }
        .background {
            if navigationViewModel.isUsingSplitView {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .padding(-10)
                    .foregroundStyle(Color(platformColor: .tertiarySystemFill))
                    .opacity((navigationViewModel.reference == nil && shouldShowBackground) ? 1 : 0)
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
    var removeLastPathComponentFirst: Bool = false
    
    var isSelected: Bool {
        navigationViewModel.reference?.isEqual(to: reference) == true
    }
    
    func action() {
        switch navigationViewModel.path.last {
        case .reference:
            if removeLastPathComponentFirst {
                navigationViewModel.removeLastPath()
            }
        default:
            break
        }
        
        for technology in documentationViewModel.technologies {
            switch technology {
            case .apple(let technologies):
                if let url = URL(string: reference.identifier),
                   let moduleString = Array(url.pathComponents.dropFirst(2)).first,
                   let groups = technologies.groups {
                    let identifier = "\(url.scheme ?? "doc")://\(url.host() ?? "com.apple.Documentation")/documentation/\(moduleString)"
                    
                    if let technologyGroup = groups.first(where: { $0.technologies.contains(where: { $0.destination.identifier == identifier }) }),
                       let technology = technologyGroup.technologies.first(where: { $0.destination.identifier == identifier }) {
                        withAnimation(.snappy) {
                            navigationViewModel.setTechnology(technology)
                        }
                        break
                    }
                }
            case .docC(let site):
                let groups: [DocCIndex.InterfaceLanguage] = site.index.interfaceLanguages.flatMap({ $0.value })
                if let url = URL(string: reference.identifier) {
                    let identifier = url.path()
                    
                    for group in groups {
                        let technologyGroup = group.children?.first(where: {
                            ($0.children ?? []).contains(where: { tech in
                                tech.path?.lowercased() == identifier.lowercased()
                            })
                        })
                        
                        if let technologyGroup,
                           let technology = technologyGroup.children?.first(where: { $0.path == identifier }) {
                            withAnimation(.snappy) {
                                navigationViewModel.setTechnology(site.frameworkSection(for: technology))
                            }
                            break
                        }
                    }
                }
            }
        }
        
        navigationViewModel.setReference(reference)
    }
    
    var body: some View {
        Group {
            MacOSAgnosticButton(action: action) {
                label
            }
            .background {
                if navigationViewModel.isUsingSplitView {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .padding(-10)
                        .foregroundStyle(Color(platformColor: .tertiarySystemFill))
                        .opacity((isSelected && shouldShowBackground) ? 1 : 0)
                }
            }
        }
#if !os(macOS)
        .hoverEffect()
#endif
    }
    
    func showBackground(_ bool: Bool) -> Self {
        var view = self
        view.shouldShowBackground = bool
        
        return view
    }
    
    func removeLastPathComponentFirst(_ bool: Bool) -> Self {
        var view = self
        view.removeLastPathComponentFirst = bool
        
        return view
    }
}

struct TechnologyNavigationLinkButton<Content: View>: View {
    @EnvironmentObject var navigationViewModel: NavigationViewModel
    let technology: AppleTechnologies.FrameworkSection
    
    @ViewBuilder
    let label: Content
    
    var body: some View {
        Group {
            MacOSAgnosticButton {
                navigationViewModel.technologyHistoryUpdatingIsEnabled = true
                
                withAnimation(.snappy) {
                    navigationViewModel.setTechnology(technology)
                }
                
                if navigationViewModel.isUsingSplitView {
                    let reference = technology.frameworkReference
                    navigationViewModel.setReference(reference)
                }
            } label: {
                label
            }
            .background {
                if navigationViewModel.isUsingSplitView {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .padding(-10)
                        .foregroundStyle(Color(platformColor: .tertiarySystemFill))
                        .opacity(navigationViewModel.technology?.destination.identifier.lowercased() == technology.destination.identifier.lowercased() ? 1 : 0)
                }
            }
        }
#if !os(macOS)
        .hoverEffect()
#endif
    }
}
