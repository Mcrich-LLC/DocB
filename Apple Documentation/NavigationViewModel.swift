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
    @Published var technology: Technologies.FrameworkSection? {
        didSet {
            if !isNavigating {
                addToHistory()
            }
        }
    }
    
    @Published var reference: Reference? {
        didSet {
            if !isNavigating {
                addToHistory()
            }
        }
    }
    
    @Published var splitViewColumnVisibility = NavigationSplitViewVisibility.automatic
    @Published var horizontalSizeClass: UserInterfaceSizeClass? = .regular
    var isUsingSplitView: Bool {
        UIDevice.current.userInterfaceIdiom != .phone && horizontalSizeClass == .regular
    }
    
    @Published private var history: [History] = [.init(technology: nil, reference: nil, isHomepage: true)]
    var previousHistoryExists: Bool { currentIndex > 0 }
    var futureHistoryExists: Bool { currentIndex < history.count - 1 }
    
    private var currentIndex = 0
    private var isNavigating = false
    
    @Published var path: NavigationPath = .init()
    
    func handleURL(_ url: URL, documentationViewModel: DocumentationViewModel) {
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
            return
        }
        
        if self.technology?.destination.identifier.lowercased() != technology.destination.identifier.lowercased() {
            withAnimation(.snappy) {
                self.technology = technology
            } completion: {
#if (os(macOS) || targetEnvironment(macCatalyst))
            self.splitViewColumnVisibility = .all // Mac crashes from error otherwise
            #endif
            }
            path.append(technology)
            
#if !(os(macOS) || targetEnvironment(macCatalyst))
            self.splitViewColumnVisibility = .all // Better experience
            #endif
        }
        
        let articlePath = Array(url.pathComponents.dropFirst(2))
        var articleIdentifier = "doc://\(url.host() ?? "com.apple.documentation")/documentation"
        
        var references: [String : Reference] = [:]
        
        Task {
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
                article = nil
            }
            
            guard let article else {
                return
            }
            
            DispatchQueue.main.async {
                self.reference = article
                self.path.append(article)
            }
        }
    }
    
    // Add current state to history
    func addToHistory() {
        guard !isNavigating else { return }
        
        guard let technology, let reference else {
            if self.technology == nil && self.reference == nil && history.last?.isHomepage == false {
                history.append(.init(technology: nil, reference: nil, isHomepage: true))
                currentIndex += 1
            }
            return
        }
        
        // Remove future history if we're adding a new state
        if currentIndex < history.count - 1 {
            history = Array(history.prefix(currentIndex + 1))
        }
        
        if let lastState = history.last,
            let lastStateTechnologyIdentifier = lastState.technology?.destination.identifier,
           let lastStateReferenceIdentifier = lastState.reference?.identifier,
           URL(string: lastStateReferenceIdentifier)?.pathComponents.dropFirst(2).first != URL(string: lastStateTechnologyIdentifier)?.pathComponents.dropFirst(2).first,
            lastState.reference?.identifier == reference.identifier,
           technologyHistoryUpdatingIsEnabled {
            history[history.count - 1].technology = technology
            return
        }
        
        // Prevent Duplicates
        guard history.last?.reference?.identifier != reference.identifier else {
            return
        }
        
        history.append(History(technology: technology, reference: reference, isHomepage: false))
        currentIndex += 1
    }
    
    // Navigate backward in history
    func goBackward() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        navigateToCurrentHistory()
    }
    
    // Navigate forward in history
    func goForward() {
        guard currentIndex < history.count - 1 else { return }
        currentIndex += 1
        navigateToCurrentHistory()
    }
    
    // Helper function to update technology and reference based on the current history state
    private func navigateToCurrentHistory() {
        isNavigating = true
        let currentState = history[currentIndex]
        reference = currentState.reference
        technology = currentState.technology
        isNavigating = false
    }
    
    static func == (lhs: NavigationViewModel, rhs: NavigationViewModel) -> Bool {
        lhs.technology == rhs.technology && lhs.reference == rhs.reference
    }
    
}

extension Dictionary {
    mutating func merge(dict: [Key: Value]) {
        for (k, v) in dict {
            updateValue(v, forKey: k)
        }
    }
}

private struct History: Identifiable {
    let id = UUID()
    
    var technology: Technologies.FrameworkSection?
    let reference: Reference?
    let isHomepage: Bool
}
