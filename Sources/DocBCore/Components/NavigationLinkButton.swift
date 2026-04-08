//
//  NavigationLinkButton.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/8/24.
//

import SwiftUI

/// Reusable navigation button that routes to the homepage and updates navigation selection state.
public struct HomepageNavigationLinkButton<Content: View>: View {
    public init(@ViewBuilder label: () -> Content) {
        self.label = label()
    }
    
    /// Shared navigation coordinator.
    @Environment(NavigationViewModel.self) var navigationViewModel
    /// Documentation model (kept for parity/extension across navigation buttons).
    @Environment(DocumentationViewModel.self) var documentationViewModel
    
    /// Label content displayed by the button.
    @ViewBuilder
    public let label: Content
    
    /// Whether selection background highlighting should be shown.
    public var shouldShowBackground: Bool = true
    
    /// Renders the homepage navigation control.
    public var body: some View {
        MacOSAgnosticButton(action: {
            navigationViewModel.setReference(nil)
            navigationViewModel.setTechnology(nil)
            navigationViewModel.removeLastPath(navigationViewModel.path.count)
            
            navigationViewModel.appendPath(.homepage)
        }) {
            label
        }
        .selectedLineBackground(isSelected: navigationViewModel.reference == nil && shouldShowBackground)
    }
    
    /// Returns a copy configured to show or hide selection background.
    public func showBackground(_ bool: Bool) -> Self {
        var view = self
        view.shouldShowBackground = bool
        
        return view
    }
}

/// Reusable navigation button for article/reference destinations with optional bookmark-specific behavior.
public struct ReferenceNavigationLinkButton<Content: View>: View {
    /// Shared navigation coordinator.
    @Environment(NavigationViewModel.self) private var navigationViewModel
    /// Documentation model used to resolve technologies for a reference.
    @Environment(DocumentationViewModel.self) private var documentationViewModel
    /// URL opener for external links.
    @Environment(\.openURL) private var openURL
    /// Destination reference for navigation.
    private let reference: Reference
    
    /// Row label content.
    @ViewBuilder
    private let label: Content
    
    /// Creates a reference navigation button with a destination and label.
    public init(reference: Reference, @ViewBuilder label: () -> Content) {
        self.reference = reference
        self.label = label()
    }
    
    /// Whether this action should preserve bookmark-driven history semantics.
    private var isBookmarkNavigator: Bool = false
    /// Whether selection background highlighting should be shown.
    private var shouldShowBackground: Bool = true
    /// Whether one path component should be removed before pushing destination.
    private var removeLastPathComponentFirst: Bool = false
    
    /// Filters down to the lowest technology group and sets that as the side panel.
    private var alwaysShowClosestTechnologyGroup: Bool = false
    
    /// Whether this row is currently selected in navigation state.
    private var isSelected: Bool {
        navigationViewModel.reference?.isEqual(to: reference) == true
    }
    
    /// Resolves and selects an Apple technology group for the current reference when possible.
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
    
    /// Resolves and selects a custom DocC technology group for the current reference when possible.
    private func _actionHandleSite(_ site: DocCSiteDTO) {
        let groups: [DocCIndex.InterfaceLanguage] = site.index.interfaceLanguages.flatMap({ $0.value })
        if let url = URL(string: reference.identifier) {
            let identifier = url.path()
            
            for group in groups {
                if group.path?.lowercased() == identifier.lowercased() {
                    withAnimation(.snappy) {
                        navigationViewModel.isNavigatingFromBookmarks = isBookmarkNavigator
                        navigationViewModel.setTechnology(site.frameworkSection(for: group), noHistory: isBookmarkNavigator)
                    }
                    return
                }
                
                switch alwaysShowClosestTechnologyGroup {
                case true :
                    __handleAlwaysShowClosestTechnologyGroup(for: group, identifier: identifier, site: site)
                case false:
                    __handleDontAlwaysShowClosestTechnologyGroup(for: group, identifier: identifier, site: site)
                }
            }
        }
    }
    
    /// Handles direct child group matching for custom DocC technologies.
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
    
    /// Handles closest descendant group matching for custom DocC technologies.
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
    
    /// Executes navigation behavior for this reference, including external-link fallback.
    public func action() {
        navigationViewModel.isNavigatingFromBookmarks = isBookmarkNavigator
        
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
        
        navigationViewModel.isNavigatingFromBookmarks = isBookmarkNavigator
        navigationViewModel.setReference(reference, forceHistory: isBookmarkNavigator)
    }
    
    /// Renders the reference navigation control.
    public var body: some View {
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
    
    /// Returns a copy configured to show or hide selection background.
    public func showBackground(_ bool: Bool) -> Self {
        var view = self
        view.shouldShowBackground = bool
        
        return view
    }
    
    /// Returns a copy configured to pop one path element before pushing this destination.
    public func removeLastPathComponentFirst(_ bool: Bool) -> Self {
        var view = self
        view.removeLastPathComponentFirst = bool
        
        return view
    }
    
    /// Filters down to the lowest technology group and sets that as the side panel when enabled.
    public func alwaysShowClosestTechnologyGroup(_ isEnabled: Bool = true) -> Self {
        var view = self
        view.alwaysShowClosestTechnologyGroup = isEnabled
        
        return view
    }
    
    /// Navigates from the position a bookmark group.
    public func bookmarkNavigator(_ isEnabled: Bool = true) -> Self {
        var view = self
        view.isBookmarkNavigator = isEnabled
        
        return view
    }
}

/// Reusable navigation button that selects and shows a technology section.
public struct TechnologyNavigationLinkButton<Content: View>: View {
    public init(technology: AppleTechnologies.FrameworkSection, @ViewBuilder label: () -> Content) {
        self.technology = technology
        self.label = label()
    }
    
    /// Shared navigation coordinator.
    @Environment(NavigationViewModel.self) var navigationViewModel
    /// Technology destination represented by this row.
    public let technology: AppleTechnologies.FrameworkSection
    
    /// Label content displayed by the button.
    @ViewBuilder
    public let label: Content
    
    /// Whether this row is currently selected.
    public var isSelected: Bool {
        navigationViewModel.technology?.destination.identifier.lowercased() == technology.destination.identifier.lowercased() && navigationViewModel.technology?.docCSite == technology.docCSite
    }
    
    /// Renders the technology navigation control.
    public var body: some View {
        Group {
            MacOSAgnosticButton(action: {
                navigationViewModel.technologyHistoryUpdatingIsEnabled = true
                
                withAnimation(.snappy) {
                    navigationViewModel.setTechnology(technology)
                }
                
                if navigationViewModel.isUsingSplitView {
                    let reference = technology.frameworkReference
                    navigationViewModel.setReference(reference)
                }
            }) {
                label
            }
            .selectedLineBackground(isSelected: isSelected)
        }
#if !os(macOS)
        .hoverEffect()
#endif
    }
}

/// Navigation button that selects a specific bookmark collection in the sidebar flow.
public struct BookmarkCollectionNavigationLink<Content: View>: View {
    public init(collection: BookmarkCollection, @ViewBuilder label: () -> Content) {
        self.collection = collection
        self.label = label()
    }
    
    /// Target bookmark collection selected when this control is activated.
    public let collection: BookmarkCollection
    /// Label content displayed by the control.
    @ViewBuilder public let label: Content
    /// Shared navigation coordinator.
    @Environment(NavigationViewModel.self) private var navigationViewModel
    
    /// The action run instead. A navigate function is passed in to the override action. Running this will navigate to the collection as normal.
    private var overrideAction: (_ navigate: () -> Void) -> Void = { $0() }
    
    /// Renders the bookmark collection navigation control.
    public var body: some View {
        MacOSAgnosticButton(action: {
            overrideAction {
                navigationViewModel.isNavigatingFromBookmarks = true
                navigationViewModel.setBookmarkCollection(collection)
            }
        }) {
            label
        }
    }
    
    /// Overrides the default action when set
    ///
    /// - Parameters:
    ///    - action: The action run instead. A navigate function is passed in to the override action. Running this will navigate to the collection as normal.
    public func overriddenAction(_ action: @escaping (_ navigate: () -> Void) -> Void) -> Self {
        var view = self
        view.overrideAction = action
        return view
    }
}

/// Navigation button that routes to the top-level bookmark collections list.
public struct AllBookmarkCollectionsNavigationLink<Content: View>: View {
    public init(@ViewBuilder label: () -> Content) {
        self.label = label()
    }
    
    /// Label content displayed by the control.
    @ViewBuilder public let label: Content
    /// Shared navigation coordinator.
    @Environment(NavigationViewModel.self) private var navigationViewModel
    
    /// Renders the all-bookmarks navigation control.
    public var body: some View {
        Button {
            navigationViewModel.isNavigatingFromBookmarks = true
            navigationViewModel.isShowingAllBookmarkCollections = true
        } label: {
            label
        }
    }
}
