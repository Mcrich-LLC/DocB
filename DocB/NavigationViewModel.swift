//
//  NavigationViewModel.swift
//  Apple Documentation
//
//  Created by Franco Miguel Guevarra on 10/7/24.
//
// swiftlint:disable file_length

import Foundation
import SwiftUI

@Observable
@MainActor
/// Central navigation state coordinator that drives history, deep links, and path synchronization.
///
/// - Important: `isNavigating` guards history writes during internal state transitions to prevent recursive history mutations.
class NavigationViewModel: @MainActor Equatable {
    /// Enables selective in-place history updates for technology transitions.
    var technologyHistoryUpdatingIsEnabled: Bool = false
    
    /// Sets the next `addToHistory` call to use bookmarks 
    var isNavigatingFromBookmarks: Bool = false
    /// Whether the UI is currently showing the top-level bookmark collections route.
    var isShowingAllBookmarkCollections = false {
        didSet {
            if !isNavigating {
                addToHistory()
            }
        }
    }
    
    /// Whether a specific bookmark collection is currently being shown.
    var isShowingBookmarkCollection = false
    /// Currently selected bookmark collection.
    private(set) var bookmarkCollection: BookmarkCollection? {
        didSet {
            if !isNavigating {
                addToHistory()
            }
        }
    }
    
    /// Sets the currently selected bookmark collection and updates bookmark mode state.
    func setBookmarkCollection(_ collection: BookmarkCollection?) {
        self.bookmarkCollection = collection
        self.isShowingBookmarkCollection = collection != nil
    }
    
    /// Whether a technology pane/route is currently active.
    var isShowingTechnology = false
    /// Currently selected technology.
    private(set) var technology: AppleTechnologies.FrameworkSection? {
        didSet {
            if !isNavigating {
                addToHistory()
            }
        }
    }
    
    /// Sets the currently selected technology section.
    ///
    /// - Parameters:
    ///   - technology: The technology section to select.
    ///   - noHistory: When `true`, suppresses automatic history insertion for this update.
    func setTechnology(_ technology: AppleTechnologies.FrameworkSection?, noHistory: Bool = false) {
        if noHistory {
            isNavigating = true
        }
        
        self.technology = technology
        self.isShowingTechnology = technology != nil
    }
    
    /// Currently selected documentation reference.
    private(set) var reference: Reference? {
        didSet {
            if !isNavigating {
                addToHistory()
            }
        }
    }
    
    /// Sets the currently selected reference.
    ///
    /// - Parameters:
    ///   - reference: The reference to select.
    ///   - forceHistory: When `true`, allows this change to be captured in history.
    func setReference(_ reference: Reference?, forceHistory: Bool = false) {
        if forceHistory {
            isNavigating = false
        }
        
        self.reference = reference
    }
        
    /// Active split-view column visibility state.
    var splitViewColumnVisibility = NavigationSplitViewVisibility.automatic
    /// Current horizontal size class used for layout-mode decisions.
    var horizontalSizeClass: UserInterfaceSizeClass? = .regular
    /// Returns `true` when the current environment should present split-view navigation.
    var isUsingSplitView: Bool {
        #if os(macOS)
        true
        #else
        UIDevice.current.userInterfaceIdiom != .phone && horizontalSizeClass == .regular
        #endif
    }
    
    /// Reconciles state when transitioning between split and stacked navigation modes.
    ///
    /// - Warning: This mutates both history and path state; call it only when layout mode actually changes.
    func handleIsUsingSplitViewChanged() {
        toggleHomepageInBeginingOfHistory()
        path = backupPath
        if isUsingSplitView {
            let reference = reference
            
            if reference == nil, let frameworkReference = technology?.frameworkReference {
                setReference(frameworkReference)
            }
#if os(iOS)
            if UIDevice.current.orientation.isPortrait && reference == nil {
                splitViewColumnVisibility = .all
            } else if UIDevice.current.orientation.isLandscape {
                splitViewColumnVisibility = .all
            }
            #else
            splitViewColumnVisibility = .all
            #endif
        }
    }
    
    /// Indicates that the next history transition is initializing from an empty state.
    var isStartingHistory: Bool = false
    /// Linear navigation history backing back/forward behavior.
    private var history: [History] = []// [.init(technology: nil, reference: nil, isHomepage: true)]
    /// Whether at least one backward history step exists.
    var previousHistoryExists: Bool { currentIndex > 0 }
    /// Whether at least one forward history step exists.
    var futureHistoryExists: Bool { currentIndex < history.count - 1 }
    
    /// Index of the currently active history entry.
    private var currentIndex = 0 {
        willSet {
            guard currentIndex >= 0 else { return }
            previousIndex = currentIndex
        }
    }
    /// Previously active history index, used to compute path deltas.
    private var previousIndex = 0
    /// Internal re-entrancy guard used while programmatically mutating selection/history.
    private var isNavigating = false
    
    /// Stack path backing compact navigation presentation.
    var path: [PathElement] = [] /*{
        willSet {
            if newValue == path.dropLast() {
                goBackward(updatePath: false)
            }
        }
    }*/
    /// Backup copy of the stack path used during layout-mode transitions.
    private var backupPath: [PathElement] = []
    
    /// Appends a new element to both active and backup navigation paths.
    func appendPath(_ element: PathElement) {
        path.append(element)
        backupPath.append(element)
    }
    
    /// Removes one or more trailing path elements from active and backup paths.
    func removeLastPath(_ k: Int = 1) {
        guard path.count >= k else { return }
        
        path.removeLast(k)
        backupPath.removeLast(k)
    }
    
    // MARK: History
    /// Add current state to history
    private func addToHistory() {
        guard !isNavigating else { return }
        defer { isNavigatingFromBookmarks = false }
        
        if history.isEmpty {
            isStartingHistory = true
        }
        defer { isStartingHistory = false }
        
        // Remove future history if we're adding a new state
        if currentIndex < history.count - 1, currentIndex >= 0 {
            history = Array(history.prefix(currentIndex+1))
        }
        
        if isNavigatingFromBookmarks {
            if isShowingAllBookmarkCollections, _addBookmarkToHistory() {
                return
            }
        } else {
            isNavigating = true
            defer { isNavigating = false }
            
            setBookmarkCollection(nil)
            isShowingAllBookmarkCollections = false
        }
        
        _addTechnologyToHistory()
    }
    
    /// Handle Bookmark History Additions
    /// - Returns:
    /// A boolean value describing if the function added anything to history.
    private func _addBookmarkToHistory() -> Bool {
        if history.last?.isAllBookmarkCollections != true {
            let element = History(technology: technology, reference: reference, bookmarkCollection: bookmarkCollection, isBookmarkCollection: isShowingBookmarkCollection, isAllBookmarkCollections: isShowingAllBookmarkCollections, isHomepage: false)
            
            history.append(element)
            appendPath(.bookmarkCollections)
            if let bookmarkCollection {
                appendPath(.bookmark(bookmarkCollection))
            }
            goForward()
            return true
        } else if let bookmarkCollection {
            if history.last?.bookmarkCollection != bookmarkCollection {
                appendPath(.bookmark(bookmarkCollection))
            }
            
            // Remove Stale Paths
            if history.last?.bookmarkCollection == bookmarkCollection, isUsingSplitView, !path.isEmpty {
                let collectionIndex = path.lastIndex(of: .bookmark(bookmarkCollection)) ?? 0
                removeLastPath(path.count-1-collectionIndex)
            }
            
            // Update history
            if history.last?.reference != reference && history.last?.reference != nil {
                history.append(History(technology: technology, reference: reference, bookmarkCollection: bookmarkCollection, isBookmarkCollection: true, isAllBookmarkCollections: true, isHomepage: false))
            } else {
                history[history.count-1].bookmarkCollection = bookmarkCollection
                history[history.count-1].isBookmarkCollection = true
                history[history.count-1].technology = technology
                history[history.count-1].reference = reference
            }
            
            // Add new paths
            if history.last?.bookmarkCollection == bookmarkCollection, isUsingSplitView {
                goForward()
            } else {
                if let technology, path.last != .technology(technology), !isUsingSplitView {
                    appendPath(.technology(technology))
                }
                if let reference, path.last != .reference(reference), !isUsingSplitView {
                    appendPath(.reference(reference))
                }
            }
            
            return true
        }
        
        return false
    }
    
    /// Handles Documentation History Additions
    private func _addTechnologyToHistory() {
        guard let technology else {
            if let technology {
                appendPath(.technology(technology))
            }
            if self.technology == nil && self.reference == nil && self.bookmarkCollection == nil && history.last?.isHomepage == false {
                history.append(.init(technology: nil, reference: nil, bookmarkCollection: nil, isBookmarkCollection: false, isAllBookmarkCollections: false, isHomepage: true))
                goForward()
            }
            return
        }
        
        let didRectify = rectifyHistory()
        if didRectify {
            return
        }
        
        // Prevent Duplicates
        if let reference, history.last?.reference?.isEqual(to: reference) == true {
            return
        }
        if let reference, history.last?.technology?.isEqual(to: technology) == true, history.last?.reference == nil {
            history[history.count-1].reference = reference
            appendPath(.reference(reference))
            return
        }
        if reference == nil, history.last?.technology?.isEqual(to: technology) == true {
            return
        }
        
        history.append(History(technology: technology, reference: reference, bookmarkCollection: bookmarkCollection, isBookmarkCollection: isShowingBookmarkCollection, isAllBookmarkCollections: isShowingAllBookmarkCollections, isHomepage: false))
        goForward()
    }
    
    /// Attempts to coalesce incoming technology/reference changes into the most recent history entry.
    private func rectifyHistory() -> Bool {
        guard let lastState = history.last, let technology else {
            return false
        }
        if (lastState.technology?.isEqual(to: technology) == true),
           let reference,
           lastState.reference?.isEqual(to: reference) == true,
           technologyHistoryUpdatingIsEnabled {
            history[history.count - 1].technology = technology
            
            return true
        }
        
        if let reference,
           lastState.reference == nil,
           lastState.technology?.isEqual(to: technology) == true,
           technologyHistoryUpdatingIsEnabled {
            history[history.count - 1].reference = reference
            
            if history.last?.reference?.isEqual(to: reference) == true {
                appendPath(.reference(reference))
            }
            
            return true
        }
        
        return false
    }
    
    // Navigate backward in history
    /// Navigates backward through history and optionally updates the navigation path.
    func goBackward(updatePath: Bool = true) {
        if !isUsingSplitView && isShowingAllBookmarkCollections && isShowingBookmarkCollection {
            isNavigating = true
            defer { isNavigating = false }
            
            if reference != nil {
                setReference(nil)
                history[history.count-1].reference = nil
            } else if technology != nil {
                setTechnology(nil)
                history[history.count-1].technology = nil
            } else if isShowingBookmarkCollection {
                setBookmarkCollection(nil)
                history[history.count-1].bookmarkCollection = nil
                history[history.count-1].isBookmarkCollection = false
            } else {
                history[history.count-1].isAllBookmarkCollections = false
                isShowingAllBookmarkCollections = false
            }
            return
        }
        
        currentIndex -= 1
        navigateToCurrentHistory()
        
        // Update navigation stack path
        guard updatePath else { return }
        let oldState = history[previousIndex]
        
        if let technology, let oldTechnology = oldState.technology, !technology.isEqual(to: oldTechnology) {
            removeLastPath()
        }
        if let reference, let oldReference = oldState.reference, !reference.isEqual(to: oldReference) {
            removeLastPath()
        }
    }
    
    /// Navigates forward in history
    ///
    /// - Parameter updatePath: Whether to mutate `path`/`backupPath` for UI synchronization.
    func goForward(updatePath: Bool = true) {
        if currentIndex < history.count - 1 {
            currentIndex += 1
            navigateToCurrentHistory()
        }
        
        // Update navigation stack path
        guard updatePath, let technology, previousIndex >= 0 else {
            return
        }
        let oldState = history[previousIndex]
        
        if let oldTechnology = oldState.technology {
            if !technology.isEqual(to: oldTechnology) || isStartingHistory {
                appendPath(.technology(technology))
            }
        } else {
            appendPath(.technology(technology))
        }
        
        if let reference,
           let currentUrl = URL(string: reference.identifier),
           let technologyUrl = URL(string: technology.destination.identifier),
           currentUrl.deletingPathExtension().path().lowercased().contains(technologyUrl.deletingPathExtension().path().lowercased()) {
            if let oldReference = oldState.reference {
                if !reference.isEqual(to: oldReference) || history.count == 1 {
                    appendPath(.reference(reference))
                }
            } else {
                appendPath(.reference(reference))
            }
        }
        
        if isShowingAllBookmarkCollections, history.last?.isAllBookmarkCollections != true {
            appendPath(.bookmarkCollections)
        }
        if let bookmarkCollection, isShowingBookmarkCollection, history.last?.bookmarkCollection != bookmarkCollection {
            appendPath(.bookmark(bookmarkCollection))
        }
    }
    
    // Helper function to update technology and reference based on the current history state
    /// Applies the current history entry to active selection state and bookmark flags.
    private func navigateToCurrentHistory() {
        isNavigating = true
        defer { isNavigating = false }
        
        guard currentIndex >= 0 else {
            history = []
            currentIndex = 0
            technology = nil
            reference = nil
            bookmarkCollection = nil
            isShowingBookmarkCollection = false
            isShowingAllBookmarkCollections = false
            return
        }
        let currentState = history[currentIndex]
        reference = currentState.reference
        technology = currentState.technology
        bookmarkCollection = currentState.bookmarkCollection
        isShowingBookmarkCollection = currentState.isBookmarkCollection
        isShowingAllBookmarkCollections = currentState.isAllBookmarkCollections
    }
    
    /// Returns whether the current history state matches the given reference.
    func shouldRemoveReferenceFromPath(_ reference: Reference?) -> Bool {
        history[currentIndex].reference == reference
    }
    
    /// Returns whether the current history state matches the given technology and has no reference.
    func shouldRemoveTechnologyFromPath(_ technology: AppleTechnologies.FrameworkSection?) -> Bool {
        history[currentIndex].technology == technology && history[currentIndex].reference == nil
    }
    
    /// Returns whether the current history entry represents the homepage.
    func homepageIsCurrent() -> Bool {
        history[currentIndex].isHomepage
    }
    
    /// Inserts or removes homepage state at the start of history based on layout mode.
    func toggleHomepageInBeginingOfHistory() {
        if isUsingSplitView && history.first?.isHomepage != true {
            history.insert(.init(technology: nil, reference: nil, bookmarkCollection: nil, isBookmarkCollection: false, isAllBookmarkCollections: false, isHomepage: true), at: 0)
            currentIndex += 1
        } else if !isUsingSplitView && history.first?.isHomepage == true {
            history.remove(at: 0)
            if currentIndex > 0 {
                currentIndex -= 1
            }
        }
    }
    
    /// Returns the last history index where a matching reference appears.
    func getHistoryIndexOfReference(_ reference: Reference) -> Int? {
        history.lastIndex(where: { history in
            guard let ref = history.reference else {
                return history.reference == reference
            }
            
            return ref.isEqual(to: reference)
        })
    }
    
    /// Returns the technology at a history index when valid.
    func getHistoryTechnology(at index: Int) -> AppleTechnologies.FrameworkSection? {
        if index < history.count - 1 && index >= 0 {
            return history[index].technology
        } else {
            return nil
        }
    }
    
    /// Handles cleanup when a visible reference should be removed from history/path state.
    func handleHistoryRemoval(for reference: Reference) {
        isNavigating = true
        defer { isNavigating = false }
        
        guard !isUsingSplitView else { return }
        
        // Handle Switch from NavigationSplitView to NavigationStack
        if history.contains(where: { $0.isAllBookmarkCollections == true }) {
            let currentItem = history[currentIndex]
            history.removeAll(where: { $0.isAllBookmarkCollections == true && $0.id != currentItem.id })
            let newIndex = history.firstIndex(of: currentItem)!
            currentIndex = newIndex
        }
        
        guard shouldRemoveReferenceFromPath(reference),
           let historyIndex = getHistoryIndexOfReference(reference),
           let technology = technology
        else {
            return
        }
        
        if isShowingAllBookmarkCollections && isShowingBookmarkCollection {
            setReference(nil)
            history[historyIndex].reference = nil
            return
        }
        
        guard let oldTechnology = getHistoryTechnology(at: historyIndex-1), !oldTechnology.isEqual(to: technology) else {
            history[historyIndex].reference = nil
            setReference(nil)
            return
        }
        
        goBackward(updatePath: false)
    }
    
    // Equatibility
    /// Compares navigation models by selected technology/reference identity.
    static func == (lhs: NavigationViewModel, rhs: NavigationViewModel) -> Bool {
        guard let lhsTech = lhs.technology, let lhsReference = lhs.reference,
              let rhsTech = rhs.technology, let rhsReference = rhs.reference
        else {
            return lhs.technology == rhs.technology && lhs.reference == rhs.reference
        }
        
        return lhsTech.isEqual(to: rhsTech) && lhsReference.isEqual(to: rhsReference)
    }
    
}

/// Small dictionary helpers used by navigation deep-linking merges.
extension Dictionary {
    /// Merges key/value pairs from another dictionary, replacing existing values on conflict.
    mutating func merge(dict: [Key: Value]) {
        for (k, v) in dict {
            updateValue(v, forKey: k)
        }
    }
}

/// Snapshot of navigation selection state used for back/forward history traversal.
private struct History: Identifiable, Hashable {
    /// Stable identifier for diffable/history list usage.
    let id = UUID()
    
    /// Technology selected at this history point.
    var technology: AppleTechnologies.FrameworkSection?
    /// Reference selected at this history point.
    var reference: Reference?
    /// Bookmark collection selected at this history point, if any.
    var bookmarkCollection: BookmarkCollection?
    /// Whether this history entry is inside a specific bookmark collection context.
    var isBookmarkCollection: Bool
    /// Whether this history entry represents the bookmark collections root.
    var isAllBookmarkCollections: Bool
    /// Whether this history entry represents homepage state.
    let isHomepage: Bool
}

/// NavigationPath element wrapper used for strongly typed stack and split navigation.
enum PathElement: Hashable {
    case reference(Reference)
    case technology(AppleTechnologies.FrameworkSection)
    case homepage
    case bookmarkCollections
    case bookmark(BookmarkCollection)
}

/// Convenience initializer for value-based navigation links that use `PathElement`.
extension NavigationLink where Destination == Never {
    /// Creates a value-based `NavigationLink` for a typed `PathElement`.
    init(element: PathElement, @ViewBuilder  label: () -> Label) {
        self.init(value: element, label: label)
    }
}

// MARK: Deeplinking
/// Deep-link routing and URL handling behavior for navigation state.
extension NavigationViewModel {
    /// Handles an inbound URL and invokes a completion closure after routing is attempted.
    func handleURL(_ url: URL, documentationViewModel: DocumentationViewModel, completion: (() -> Void)? = nil) {
        Task {
            await handleURL(url, documentationViewModel: documentationViewModel)
            completion?()
        }
    }
    
    /// Handles an inbound URL by resolving redirects and routing to framework/article destinations.
    ///
    /// - Important: `welcome` URLs are normalized through a redirect lookup before routing.
    func handleURL(_ url: URL, documentationViewModel: DocumentationViewModel) async {        
        let updatedUrl: URL
        if url.pathComponents.contains(where: { $0.lowercased() == "welcome" }) {
            do {
                let fetchUrl = Constants.basePath.appending(path: url.path()).appendingPathExtension("json")
                let url = try await documentationViewModel.getRedirectedURL(for: fetchUrl)
                let updateUrlPathComponents = Array(url.pathComponents.dropFirst(3))
                
                if let updateUrl = URL(string: "doc://\(url.host() ?? "com.apple.documentation")/\(updateUrlPathComponents.joined(separator: "/"))") {
                    updatedUrl = updateUrl.deletingPathExtension()
                } else {
                    throw URLError(.badURL)
                }
            } catch {
                print(error)
                updatedUrl = url
            }
        } else {
            updatedUrl = url
        }
        
        await handleFrameworkURL(updatedUrl, documentationViewModel: documentationViewModel)
        await handleArticleURL(updatedUrl, documentationViewModel: documentationViewModel)
    }
    
    /// Attempts to route a URL to a framework destination across known technology sources.
    private func handleFrameworkURL(_ url: URL, documentationViewModel: DocumentationViewModel) async {
        for technology in documentationViewModel.technologies {
            switch technology {
            case .apple(let technologies):
                let didHandle = await handleAppleFrameworkURL(url, for: technologies, documentationViewModel: documentationViewModel)
                if didHandle {
                    return
                }
            case .docC(let site):
                let didHandle = await handleDocCFrameworkURL(url, for: site, documentationViewModel: documentationViewModel)
                if didHandle {
                    return
                }
            }
        }
    }
    
    /// Attempts to match and route a URL to a custom DocC framework.
    @discardableResult
    private func handleDocCFrameworkURL(_ url: URL, for site: DocCSiteDTO, documentationViewModel: DocumentationViewModel) async -> Bool {
        let groups: [DocCIndex.InterfaceLanguage] = site.index.interfaceLanguages.flatMap({ $0.value })
        let identifier = url.path()
        
        guard let technologyGroup = groups.first(where: { $0.children?.contains(where: { $0.path?.lowercased() == identifier.lowercased() }) ?? false }),
              let technology = technologyGroup.children?.first(where: { $0.path?.lowercased() == identifier.lowercased() })
        else {
            return false
        }
        
        let technologyDTO = site.frameworkSection(for: technology)
        
        await MainActor.run {
            withAnimation(.snappy) {
                guard let technologyDTO, self.technology?.isEqual(to: technologyDTO) != true else {
                    return
                }
                
                self.setTechnology(technologyDTO)
            } completion: {
#if (os(macOS) || targetEnvironment(macCatalyst))
                self.splitViewColumnVisibility = .all // Mac crashes from error otherwise
#endif
            }
            
#if !(os(macOS) || targetEnvironment(macCatalyst))
            self.splitViewColumnVisibility = .all // Better experience
#endif
        }
        
        return true
    }
    
    /// Attempts to match and route a URL to an Apple-hosted framework.
    @discardableResult
    private func handleAppleFrameworkURL(_ url: URL, for technologies: AppleTechnologies, documentationViewModel: DocumentationViewModel) async -> Bool {
        guard let moduleString = Array(url.pathComponents.dropFirst(2)).first,
              let groups = technologies.groups
        else {
            return false
        }
        let identifier = "doc://com.apple.documentation/documentation/\(moduleString)".lowercased()
        
        guard let technologyGroup = groups.first(where: { $0.technologies.contains(where: { $0.destination.identifier.lowercased() == identifier }) }),
              let technology = technologyGroup.technologies.first(where: { $0.destination.identifier.lowercased() == identifier })
        else {
            print("\(identifier) Not Found")
            return false
        }
        
        guard self.technology?.destination.identifier.lowercased() != technology.destination.identifier.lowercased() else {
            return false
        }
        
        await MainActor.run {
            withAnimation(.snappy) {
                guard self.technology?.isEqual(to: technology) != true else {
                    return
                }
                self.setTechnology(technology)
            } completion: {
#if (os(macOS) || targetEnvironment(macCatalyst))
                self.splitViewColumnVisibility = .all // Mac crashes from error otherwise
#endif
            }
            
#if !(os(macOS) || targetEnvironment(macCatalyst))
            self.splitViewColumnVisibility = .all // Better experience
#endif
        }
        
        return true
    }
    
    /// Attempts to route a URL to an article destination across known technology sources.
    private func handleArticleURL(_ url: URL, documentationViewModel: DocumentationViewModel) async {
        for technology in documentationViewModel.technologies {
            switch technology {
            case .apple(let technologies):
                let didHandle = await handleAppleArticleURL(url, for: technologies, documentationViewModel: documentationViewModel)
                if didHandle {
                    return
                }
            case .docC(let site):
                let didHandle = await handleDocCArticleURL(url, for: site, documentationViewModel: documentationViewModel)
                if didHandle {
                    return
                }
            }
        }
    }
    
    /// Attempts to match and route a URL to an article in a custom DocC site.
    @discardableResult
    private func handleDocCArticleURL(_ url: URL, for site: DocCSiteDTO, documentationViewModel: DocumentationViewModel) async -> Bool {
        let articlePath = Array(url.pathComponents.dropFirst(2))
        var articleIdentifier = "doc://\(url.host() ?? "com.docc.documentation")/documentation"
        
        var references: [String : Reference] = [:]
        
        for article in articlePath {
            articleIdentifier.append("/\(article)")
            
            if let framework = documentationViewModel.frameworks[articleIdentifier] {
                references.merge(dict: framework.references)
            } else {
                await documentationViewModel.fetchFramework(for: articleIdentifier, site: site)
                if let framework = documentationViewModel.frameworks[articleIdentifier] {
                    references.merge(dict: framework.references)
                }
                
                if let article = try? await documentationViewModel.fetchArticle(for: articleIdentifier, site: site) {
                    references.merge(dict: article.references)
                }
            }
        }
        
        var article: Reference?
        
        if let reference = references[articleIdentifier] {
            article = reference
        } else if let referece = references.values.first(where: { URL(string: $0.identifier)?.path() == URL(string: articleIdentifier)?.path() }) {
            article = referece
        } else {
            do {
                let fullArticle = try await documentationViewModel.fetchArticle(for: articleIdentifier, site: site)
                
                // swiftlint:disable line_length
                let reference = Reference(title: fullArticle.metadata.title, abstract: fullArticle.abstract, identifier: articleIdentifier, kind: nil, type: "", url: nil, role: fullArticle.metadata.role, fragments: nil, deprecated: nil, beta: nil, variants: nil, images: nil, docCSite: site)
                // swiftlint:enable line_length
                
                article = reference
            } catch {
                article = nil
            }
        }
        
        article?.docCSite = site
        
        func getAllChildren(for group: [DocCIndex.InterfaceLanguage], descendant: Bool = false) -> [DocCIndex.InterfaceLanguage] {
            group.flatMap({ (descendant ? [] : [$0]) + ($0.children ?? []) + getAllChildren(for: ($0.children ?? []), descendant: true) })
        }
        
        guard article?.identifier.contains("com.apple") != true, getAllChildren(for: site.groups).contains(where: {
            $0.path?.lowercased() == "/\(Array(url.pathComponents.dropFirst()).joined(separator: "/"))".lowercased()
        }) == true else {
            // Actually Apple Article
            return false
        }
        
        guard let article else {
            print("\(articleIdentifier) Not Found")
            return false
        }
        
        await MainActor.run {
            guard self.reference?.isEqual(to: article) != true else {
                return
            }
            
            self.setReference(article)
        }
        
        return true
    }
    
    /// Attempts to match and route a URL to an Apple-hosted article.
    @discardableResult
    private func handleAppleArticleURL(_ url: URL, for technologies: AppleTechnologies, documentationViewModel: DocumentationViewModel) async -> Bool {
        let articlePath = Array(url.pathComponents.dropFirst(2))
        var articleIdentifier = "doc://\(url.host() ?? "com.apple.documentation")/documentation"
        
        var references: [String : Reference] = [:]
        
        for article in articlePath {
            articleIdentifier.append("/\(article)")
            
            if let framework = documentationViewModel.frameworks[articleIdentifier] {
                references.merge(dict: framework.references)
            } else {
                await documentationViewModel.fetchFramework(for: articleIdentifier, site: nil)
                if let framework = documentationViewModel.frameworks[articleIdentifier] {
                    references.merge(dict: framework.references)
                }
                
                if let article = try? await documentationViewModel.fetchArticle(for: articleIdentifier, site: nil) {
                    references.merge(dict: article.references)
                }
            }
        }
        
        let article: Reference?
        
        if let reference = references[articleIdentifier] {
            article = reference
        } else if let referece = references.values.first(where: { URL(string: $0.identifier)?.path() == URL(string: articleIdentifier)?.path() }) {
            article = referece
        } else {
            do {
                let fullArticle = try await documentationViewModel.fetchArticle(for: articleIdentifier, site: nil)
                
                // swiftlint:disable line_length
                let reference = Reference(title: fullArticle.metadata.title, abstract: fullArticle.abstract, identifier: articleIdentifier, kind: nil, type: "", url: nil, role: fullArticle.metadata.role, fragments: nil, deprecated: nil, beta: nil, variants: nil, images: nil, docCSite: nil)
                // swiftlint:enable line_length
                
                article = reference
            } catch {
                article = nil
            }
        }
        
        guard article?.identifier.contains("com.apple") == true || article?.identifier.contains("apple.com") == true else {
            // Not Apple Article
            return false
        }
        
        guard let article else {
            print("\(articleIdentifier) Not Found")
            return false
        }
        
        await MainActor.run {
            guard self.reference?.isEqual(to: article) != true else {
                return
            }
            
            self.setReference(article)
        }
        
        return true
    }
}
