//
//  NavigationLinkButton.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/8/24.
//

import SwiftUI

struct HomepageNavigationLinkButton<Content: View>: View {
    @Environment(NavigationViewModel.self) var navigationViewModel
    @Environment(DocumentationViewModel.self) var documentationViewModel
    
    @ViewBuilder
    let label: Content
    
    var shouldShowBackground: Bool = true
    
    var body: some View {
        MacOSAgnosticButton {
            navigationViewModel.setReference(nil)
            navigationViewModel.setTechnology(nil)
            navigationViewModel.removeLastPath(navigationViewModel.path.count)
            
            navigationViewModel.appendPath(.homepage)
        } label: {
            label
        }
        .selectedLineBackground(isSelected: navigationViewModel.reference == nil && shouldShowBackground)
    }
    
    func showBackground(_ bool: Bool) -> Self {
        var view = self
        view.shouldShowBackground = bool
        
        return view
    }
}

struct ReferenceNavigationLinkButton<Content: View>: View {
    @Environment(NavigationViewModel.self) var navigationViewModel
    @Environment(DocumentationViewModel.self) var documentationViewModel
    @Environment(\.openURL) private var openURL
    let reference: Reference
    
    @ViewBuilder
    let label: Content
    
    var shouldShowBackground: Bool = true
    var removeLastPathComponentFirst: Bool = false
    
    /// Filters down to the lowest technology group and sets that as the side panel.
    var alwaysShowClosestTechnologyGroup: Bool = false
    
    var isSelected: Bool {
        navigationViewModel.reference?.isEqual(to: reference) == true
    }
    
    private func _actionHandleTechnologies(_ technologies: AppleTechnologies) {
        if let url = URL(string: reference.identifier),
           let moduleString = Array(url.pathComponents.dropFirst(2)).first,
           let groups = technologies.groups {
            let identifier = "\(url.scheme ?? "doc")://\(url.host() ?? "com.apple.Documentation")/documentation/\(moduleString)"
            
            if let technologyGroup = groups.first(where: { $0.technologies.contains(where: { $0.destination.identifier == identifier }) }),
               let technology = technologyGroup.technologies.first(where: { $0.destination.identifier == identifier }) {
                withAnimation(.snappy) {
                    navigationViewModel.setTechnology(technology)
                }
                return
            }
        }
    }
    
    private func _actionHandleSite(_ site: DocCSiteDTO) {
        let groups: [DocCIndex.InterfaceLanguage] = site.index.interfaceLanguages.flatMap({ $0.value })
        if let url = URL(string: reference.identifier) {
            let identifier = url.path()
            
            for group in groups {
                switch alwaysShowClosestTechnologyGroup {
                case true :
                    __handleAlwaysShowClosestTechnologyGroup(for: group, identifier: identifier, site: site)
                case false:
                    __handleDontAlwaysShowClosestTechnologyGroup(for: group, identifier: identifier, site: site)
                }
            }
        }
    }
    
    private func __handleDontAlwaysShowClosestTechnologyGroup(for group: DocCIndex.InterfaceLanguage, identifier: String, site: DocCSiteDTO) {
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
            return
        }
    }
    
    private func __handleAlwaysShowClosestTechnologyGroup(for group: DocCIndex.InterfaceLanguage, identifier: String, site: DocCSiteDTO) {
        let technologyGroup = group.allChildren.first(where: {
            ($0.children ?? []).contains(where: { tech in
                tech.path?.lowercased() == identifier.lowercased()
            })
        })
        
        if let technologyGroup {
            withAnimation(.snappy) {
                navigationViewModel.setTechnology(site.frameworkSection(for: technologyGroup))
            }
            return
        }
    }
    
    func action() {
        if let url = reference.externalURL, reference.isExternalReference {
            openURL(url)
            return
        }
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
                _actionHandleTechnologies(technologies)
            case .docC(let site):
                _actionHandleSite(site)
            }
        }
        
        navigationViewModel.setReference(reference)
    }
    
    var body: some View {
        Group {
            MacOSAgnosticButton(action: action) {
                label
            }
            .selectedLineBackground(isSelected: isSelected && shouldShowBackground)
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
    
    func alwaysShowClosestTechnologyGroup(_ isEnabled: Bool = true) -> Self {
        var view = self
        view.alwaysShowClosestTechnologyGroup = isEnabled
        
        return view
    }
}

struct TechnologyNavigationLinkButton<Content: View>: View {
    @Environment(NavigationViewModel.self) var navigationViewModel
    let technology: AppleTechnologies.FrameworkSection
    
    @ViewBuilder
    let label: Content
    
    var isSelected: Bool {
        navigationViewModel.technology?.destination.identifier.lowercased() == technology.destination.identifier.lowercased() && navigationViewModel.technology?.docCSite == technology.docCSite
    }
    
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
            .selectedLineBackground(isSelected: isSelected)
        }
#if !os(macOS)
        .hoverEffect()
#endif
    }
}
