//
//  NavigationViewModel.swift
//  Apple Documentation
//
//  Created by Franco Miguel Guevarra on 10/7/24.
//

import Foundation
import SwiftUI

class NavigationViewModel: ObservableObject, Equatable {
    
    @Published var technologyHistoryUpdatingIsEnabled: Bool = false
    @Published private(set) var technology: Technologies.FrameworkSection? {
        didSet {
            if !isNavigating {
                addToHistory()
            }
        }
    }
    
    func setTechnology(_ technology: Technologies.FrameworkSection?) {
        if self.technology != technology {
            self.technology = technology
        }
    }
    
    @Published private(set) var reference: Reference? {
        didSet {
            if !isNavigating {
                addToHistory()
            }
        }
    }
    
    func setReference(_ reference: Reference?) {
        if self.reference != reference {
            self.reference = reference
        }
    }
        
    @Published var splitViewColumnVisibility = NavigationSplitViewVisibility.automatic
    @Published var horizontalSizeClass: UserInterfaceSizeClass? = .regular
    var isUsingSplitView: Bool {
        UIDevice.current.userInterfaceIdiom != .phone && horizontalSizeClass == .regular
    }
    
    func handleIsUsingSplitViewChanged() {
        path = backupPath
        if isUsingSplitView {
            let reference = reference
            
            if reference == nil, let frameworkReference = technology?.frameworkReference {
                setReference(frameworkReference)
            }
            if UIDevice.current.orientation.isPortrait && reference == nil {
                splitViewColumnVisibility = .all
            } else if UIDevice.current.orientation.isLandscape {
                splitViewColumnVisibility = .all
            }
        }
        toggleHomepageInBeginingOfHistory()
    }
    
    @Published var isStartingHistory: Bool = false
    @Published private var history: [History] = []// [.init(technology: nil, reference: nil, isHomepage: true)]
    var previousHistoryExists: Bool { currentIndex > 0 }
    var futureHistoryExists: Bool { currentIndex < history.count - 1 }
    
    private var currentIndex = -1 {
        willSet {
            guard currentIndex >= 0 else { return }
            previousIndex = currentIndex
        }
    }
    private var previousIndex = 0
    private var isNavigating = false
    
    @Published var path: [PathElement] = []
    @Published private var backupPath: [PathElement] = []
    
    func appendPath(_ element: PathElement, overrideGaurds: Bool = false) {
        guard UIDevice.current.userInterfaceIdiom != .phone || overrideGaurds else { return }
        
        switch path.last {
        case .reference:
            switch element {
            case .reference:
                removeLastPath()
            default: break
            }
        default: break
        }
        path.append(element)
        backupPath.append(element)
    }
    
    func removeLastPath(_ k: Int = 1, overrideGaurds: Bool = false) {
        guard UIDevice.current.userInterfaceIdiom != .phone || overrideGaurds else {
            return
        }
        
        path.removeLast(k)
        backupPath.removeLast(k)
    }
    
    // MARK: History
    // Add current state to history
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
    
    func shouldRemoveReferenceFromPath(_ reference: Reference?) -> Bool {
        history[currentIndex].reference == reference
    }
    
    func shouldRemoveTechnologyFromPath(_ technology: Technologies.FrameworkSection?) -> Bool {
        history[currentIndex].technology == technology && history[currentIndex].reference == nil
    }
    
    func homepageIsCurrent() -> Bool {
        history[currentIndex].isHomepage
    }
    
    func toggleHomepageInBeginingOfHistory() {
        if isUsingSplitView && history.first != .init(technology: nil, reference: nil, isHomepage: true) {
            history.insert(.init(technology: nil, reference: nil, isHomepage: true), at: 0)
            currentIndex += 1
        } else if !isUsingSplitView && history.first == .init(technology: nil, reference: nil, isHomepage: true) {
            history.remove(at: 0)
            currentIndex -= 1
        }
    }
    
    func getHistoryIndexOfReference(_ reference: Reference) -> Int? {
        history.lastIndex(where: { history in
            guard let ref = history.reference else {
                return history.reference == reference
            }
            
            return ref.isEqual(to: reference)
        })
    }
    
    func getHistoryTechnology(at index: Int) -> Technologies.FrameworkSection? {
        if index < history.count - 1 && index >= 0 {
            return history[index].technology
        } else {
            return nil
        }
    }
    
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

private struct History: Identifiable, Hashable {
    let id = UUID()
    
    var technology: Technologies.FrameworkSection?
    var reference: Reference?
    let isHomepage: Bool
}

enum PathElement: Hashable {
    case reference(Reference)
    case technology(Technologies.FrameworkSection)
    case homepage
}

// MARK: Deeplinking
extension NavigationViewModel {
    func handleURL(_ url: URL, documentationViewModel: DocumentationViewModel, completion: (() -> Void)? = nil) {
        Task {
            await handleURL(url, documentationViewModel: documentationViewModel)
            completion?()
        }
    }
    
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
        guard let moduleString = Array(url.pathComponents.dropFirst(2)).first,
              let technologies = documentationViewModel.technologies,
              let groups = technologies.groups
        else {
            return
        }
        let identifier = "doc://com.apple.documentation/documentation/\(moduleString)".lowercased()
        
        guard let technologyGroup = groups.first(where: { $0.technologies.contains(where: { $0.destination.identifier.lowercased() == identifier }) }),
              let technology = technologyGroup.technologies.first(where: { $0.destination.identifier.lowercased() == identifier })
        else {
            print("\(identifier) Not Found")
            return
        }
        
        if self.technology?.destination.identifier.lowercased() != technology.destination.identifier.lowercased() {
            await MainActor.run {
                guard UIDevice.current.userInterfaceIdiom != .phone else {
                    appendPath(.technology(technology), overrideGaurds: true)
                    return
                }
                
                withAnimation(.snappy) {
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
        }
    }
    
    private func handleArticleURL(_ url: URL, documentationViewModel: DocumentationViewModel) async {
        let articlePath = Array(url.pathComponents.dropFirst(2))
        var articleIdentifier = "doc://\(url.host() ?? "com.apple.documentation")/documentation"
        
        var references: [String : Reference] = [:]
        
        for article in articlePath {
            articleIdentifier.append("/\(article)")
            
            if let framework = documentationViewModel.frameworks[articleIdentifier] {
                references.merge(dict: framework.references)
            } else {
                await documentationViewModel.fetchFramework(for: articleIdentifier)
                if let framework = documentationViewModel.frameworks[articleIdentifier] {
                    references.merge(dict: framework.references)
                }
                
                if let article = try? await documentationViewModel.fetchArticle(for: articleIdentifier) {
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
                let fullArticle = try await documentationViewModel.fetchArticle(for: articleIdentifier)
                
                // swiftlint:disable line_length
                let reference = Reference(title: fullArticle.metadata.title, abstract: fullArticle.abstract, identifier: articleIdentifier, kind: nil, type: "", url: nil, role: fullArticle.metadata.role, fragments: nil, deprecated: nil, beta: nil, variants: nil, images: nil)
                // swiftlint:enable line_length
                
                article = reference
            } catch {
                article = nil
            }
        }
        
        guard let article else {
            print("\(articleIdentifier) Not Found")
            return
        }
        
        await MainActor.run {
            if UIDevice.current.userInterfaceIdiom == .phone {
                self.appendPath(.reference(article), overrideGaurds: true)
            } else {
                self.setReference(article)
            }
        }
    }
}
