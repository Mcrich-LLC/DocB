//
//  NavigationViewModel.swift
//  Apple Documentation
//
//  Created by Franco Miguel Guevarra on 10/7/24.
//
// swiftlint:disable file_length

import Foundation
import SwiftUI

/// A view model that manages the application's navigation state, history, and deep linking.
@Observable
@MainActor
class NavigationViewModel: @MainActor Equatable {
    /// Controls whether updating the technology history is enabled.
    var technologyHistoryUpdatingIsEnabled: Bool = false
    /// Indicates if a technology is currently being shown.
    var isShowingTechnology = false
    /// The currently selected technology framework section.
    private(set) var technology: AppleTechnologies.FrameworkSection? {
        didSet {
            if !isNavigating {
                addToHistory()
            }
        }
    }
    
    /// Sets the current technology and updates the state.
    ///
    /// - Parameter technology: The `AppleTechnologies.FrameworkSection` to set.
    func setTechnology(_ technology: AppleTechnologies.FrameworkSection?) {
        self.technology = technology
        self.isShowingTechnology = true
    }
    
    /// The currently selected reference (article or symbol).
    private(set) var reference: Reference? {
        didSet {
            if !isNavigating {
                addToHistory()
            }
        }
    }
    
    /// Sets the current reference.
    ///
    /// - Parameter reference: The `Reference` to set.
    func setReference(_ reference: Reference?) {
        self.reference = reference
    }
        
    /// The visibility of the split view columns.
    var splitViewColumnVisibility = NavigationSplitViewVisibility.automatic
    /// The horizontal size class of the user interface.
    var horizontalSizeClass: UserInterfaceSizeClass? = .regular
    /// Determines if the split view layout should be used based on device and orientation.
    var isUsingSplitView: Bool {
        #if os(macOS)
        true
        #else
        UIDevice.current.userInterfaceIdiom != .phone && horizontalSizeClass == .regular
        #endif
    }
    
    /// Handles changes to `isUsingSplitView` to adjust navigation state.
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
    
    /// Indicates if the history is starting (to prevent duplicates or loops).
    var isStartingHistory: Bool = false
    private var history: [History] = []// [.init(technology: nil, reference: nil, isHomepage: true)]
    /// Checks if there is a previous history state to go back to.
    var previousHistoryExists: Bool { currentIndex > 0 }
    /// Checks if there is a future history state to go forward to.
    var futureHistoryExists: Bool { currentIndex < history.count - 1 }
    
    private var currentIndex = -1 {
        willSet {
            guard currentIndex >= 0 else { return }
            previousIndex = currentIndex
        }
    }
    private var previousIndex = 0
    private var isNavigating = false
    
    /// The navigation path for the stack.
    var path: [PathElement] = []
    private var backupPath: [PathElement] = []
    
    /// Appends an element to the navigation path.
    /// - Parameter element: The `PathElement` to append.
    func appendPath(_ element: PathElement) {
        path.append(element)
        backupPath.append(element)
    }
    
    /// Removes the last `k` elements from the navigation path.
    /// - Parameter k: The number of elements to remove. Default is 1.
    func removeLastPath(_ k: Int = 1) {
        guard path.count >= k else { return }
        
        path.removeLast(k)
        backupPath.removeLast(k)
    }
    
    // MARK: History
    /// Adds the current state to the navigation history.
    ///
    /// This method manages the history stack, preventing duplicates and handling forward/backward navigation logic.
    func addToHistory() {
        guard !isNavigating else { return }
        
        guard let technology else {
            if let technology {
                appendPath(.technology(technology))
            }
            if self.technology == nil && self.reference == nil && history.last?.isHomepage == false {
                history.append(.init(technology: nil, reference: nil, isHomepage: true))
                goForward()
            }
            return
        }
        
        // Remove future history if we're adding a new state
        if currentIndex < history.count - 1, currentIndex >= 0 {
            history = Array(history.prefix(currentIndex+1))
        }
        
        let didRectify = rectifyHistory()
        if didRectify {
            return
        }
        
        // Prevent Duplicates
        if let reference, history.last?.reference?.isEqual(to: reference) == true {
            return
        }
        if reference == nil, history.last?.technology?.isEqual(to: technology) == true {
            return
        }
        
        if history.isEmpty {
            isStartingHistory = true
        }
        history.append(History(technology: technology, reference: reference, isHomepage: false))
        goForward()
        isStartingHistory = false
    }
    
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
    /// Navigates to the previous state in the history stack.
    ///
    /// - Parameter updatePath: Whether to update the navigation path (default is `true`).
    func goBackward(updatePath: Bool = true) {
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
    
    // Navigate forward in history
    /// Navigates to the next state in the history stack.
    ///
    /// - Parameter updatePath: Whether to update the navigation path (default is `true`).
    func goForward(updatePath: Bool = true) {
        guard currentIndex < history.count - 1 else { return }
        currentIndex += 1
        navigateToCurrentHistory()
        
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
    }
    
    // Helper function to update technology and reference based on the current history state
    private func navigateToCurrentHistory() {
        isNavigating = true
        defer { isNavigating = false }
        
        guard currentIndex >= 0 else {
            history = []
            currentIndex = -1
            technology = nil
            reference = nil
            return
        }
        let currentState = history[currentIndex]
        reference = currentState.reference
        technology = currentState.technology
    }
    
    /// Determines if a reference should be removed from the navigation path.
    /// - Parameter reference: The reference to check.
    /// - Returns: `true` if the reference matches the current history state.
    func shouldRemoveReferenceFromPath(_ reference: Reference?) -> Bool {
        history[currentIndex].reference == reference
    }
    
    /// Determines if a technology should be removed from the navigation path.
    /// - Parameter technology: The technology to check.
    /// - Returns: `true` if the technology matches the current history state and there is no active reference.
    func shouldRemoveTechnologyFromPath(_ technology: AppleTechnologies.FrameworkSection?) -> Bool {
        history[currentIndex].technology == technology && history[currentIndex].reference == nil
    }
    
    /// Checks if the current history state represents the homepage.
    /// - Returns: `true` if the current state is the homepage.
    func homepageIsCurrent() -> Bool {
        history[currentIndex].isHomepage
    }
    
    /// Toggles the presence of the homepage at the beginning of the history based on split view usage.
    func toggleHomepageInBeginingOfHistory() {
        if isUsingSplitView && history.first?.isHomepage != true {
            history.insert(.init(technology: nil, reference: nil, isHomepage: true), at: 0)
            currentIndex += 1
        } else if !isUsingSplitView && history.first?.isHomepage == true {
            history.remove(at: 0)
            if currentIndex > 0 {
                currentIndex -= 1
            }
        }
    }
    
    /// Finds the index of a specific reference in the history stack.
    /// - Parameter reference: The reference to search for.
    /// - Returns: The index of the reference if found, otherwise `nil`.
    func getHistoryIndexOfReference(_ reference: Reference) -> Int? {
        history.lastIndex(where: { history in
            guard let ref = history.reference else {
                return history.reference == reference
            }
            
            return ref.isEqual(to: reference)
        })
    }
    
    /// Retrieves the technology at a specific index in the history.
    /// - Parameter index: The index to retrieve from.
    /// - Returns: The `AppleTechnologies.FrameworkSection` at the index, or `nil` if invalid.
    func getHistoryTechnology(at index: Int) -> AppleTechnologies.FrameworkSection? {
        if index < history.count - 1 && index >= 0 {
            return history[index].technology
        } else {
            return nil
        }
    }
    
    /// Handles the removal of a reference from the history and path.
    /// - Parameter reference: The reference being removed.
    func handleHistoryRemoval(for reference: Reference) {
        isNavigating = true
        defer { isNavigating = false }
        
        guard !isUsingSplitView else { return }
        
        guard shouldRemoveReferenceFromPath(reference),
           let historyIndex = getHistoryIndexOfReference(reference),
           let technology = technology
        else {
            return
        }
        
        guard let oldTechnology = getHistoryTechnology(at: historyIndex-1), !oldTechnology.isEqual(to: technology) else {
            isNavigating = true
            history[historyIndex].reference = nil
            setReference(nil)
            isNavigating = false
            return
        }
        
        goBackward(updatePath: false)
    }
    
    // Equatibility
    static func == (lhs: NavigationViewModel, rhs: NavigationViewModel) -> Bool {
        guard let lhsTech = lhs.technology, let lhsReference = lhs.reference,
              let rhsTech = rhs.technology, let rhsReference = rhs.reference
        else {
            return lhs.technology == rhs.technology && lhs.reference == rhs.reference
        }
        
        return lhsTech.isEqual(to: rhsTech) && lhsReference.isEqual(to: rhsReference)
    }
    
}

extension Dictionary {
    mutating func merge(dict: [Key: Value]) {
        for (k, v) in dict {
            updateValue(v, forKey: k)
        }
    }
}

/// A private structure representing a state in the navigation history.
private struct History: Identifiable, Hashable {
    /// A unique identifier for the history item.
    let id = UUID()
    
    /// The technology associated with this history state.
    var technology: AppleTechnologies.FrameworkSection?
    /// The reference associated with this history state.
    var reference: Reference?
    /// Indicates if this history state represents the homepage.
    let isHomepage: Bool
}

/// An enum representing an element in the navigation path.
enum PathElement: Hashable {
    /// A reference path element.
    case reference(Reference)
    /// A technology path element.
    case technology(AppleTechnologies.FrameworkSection)
    /// The homepage path element.
    case homepage
}

// MARK: Deeplinking
extension NavigationViewModel {
    /// Handles a deep link URL asynchronously.
    ///
    /// - Parameters:
    ///   - url: The URL to handle.
    ///   - documentationViewModel: The view model used for data fetching.
    ///   - completion: An optional closure executed after handling the URL.
    func handleURL(_ url: URL, documentationViewModel: DocumentationViewModel, completion: (() -> Void)? = nil) {
        Task {
            await handleURL(url, documentationViewModel: documentationViewModel)
            completion?()
        }
    }
    
    /// Handles a deep link URL.
    ///
    /// This method parses the URL, resolves redirects, and navigates to the appropriate framework or article.
    ///
    /// - Parameters:
    ///   - url: The URL to handle.
    ///   - documentationViewModel: The view model used for data fetching.
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
