//
//  NavigationViewModel.swift
//  Apple Documentation
//
//  Created by Franco Miguel Guevarra on 10/7/24.
//

import Foundation
import SwiftUI

class NavigationViewModel: ObservableObject, Equatable {
    
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
    
    @Published var history: [(technology: Technologies.FrameworkSection?, reference: Reference?)] = []
    
    private var currentIndex = -1
    private var isNavigating = false
    
    @Published var path: NavigationPath = .init()
    
    func handleURL(_ url: URL, documentationViewModel: DocumentationViewModel) {
        guard let moduleString = Array(url.pathComponents.dropFirst(2)).first,
              let technologies = documentationViewModel.technologies,
              let groups = technologies.groups
        else {
            return
        }
        let identifier = "\(url.scheme ?? "doc")://com.apple.documentation/documentation/\(moduleString)".lowercased()
        
        guard let technologyGroup = groups.first(where: { $0.technologies.contains(where: { $0.destination.identifier.lowercased() == identifier }) }),
              let technology = technologyGroup.technologies.first(where: { $0.destination.identifier.lowercased() == identifier })
        else {
            return
        }
        
        if self.technology?.destination.identifier.lowercased() != technology.destination.identifier.lowercased() {
            withAnimation(.snappy) {
                self.technology = technology
            }
            path.append(technology)
        }
        
        let articlePath = Array(url.pathComponents.dropFirst(2))
        var articleIdentifier = "\(url.scheme ?? "doc")://\(url.host() ?? "com.apple.documentation")/documentation"
        
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
            
            dump(references)
            print(articleIdentifier)
            guard let article = references[articleIdentifier] else {
                return
            }
            
            DispatchQueue.main.async {
                self.reference = article
                self.path.append(article)
            }
        }
    }
    
    var iphoneArticleDestinationBinding: Binding<Reference?> {
        Binding {
            guard UIDevice.current.userInterfaceIdiom == .phone else {
                return nil
            }
            return self.reference
        } set: { reference in
            self.reference = reference
        }
    }
    
    // Add current state to history
    private func addToHistory() {
        // Remove future history if we're adding a new state
        if currentIndex < history.count - 1 {
            history = Array(history.prefix(currentIndex + 1))
        }
        history.append((technology, reference))
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
        technology = currentState.technology
        reference = currentState.reference
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
