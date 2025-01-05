//
//  DocumentationViewModel.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/6/24.
//

import Foundation
import SwiftUI

enum PreferedProgrammingLanguage: String, Codable, CaseIterable {
    case swift
    case objectivec = "occ"
    case data
    
    var humanReadable: String? {
        switch self {
        case .swift:
            "Swift"
        case .objectivec:
            "Objective-C"
        case .data:
            nil
        }
    }
}

class DocumentationViewModel: ObservableObject {
    @AppStorage("preferedProgrammingLanguage") var preferedProgrammingLanguage = PreferedProgrammingLanguage.swift
    
    // MARK: URL Functions
    func jsonUrl(for identifier: String, site: DocCSite?) -> URL? {
        if let site {
            var identifier: String = identifier.lowercased()
            if let index = identifier.firstRange(of: "/documentation") {
                identifier = identifier.suffix(from: index.lowerBound).lowercased()
            }
            
            let url = site.url
                .appending(path: "data")
                .appending(path: identifier)
                .appendingPathExtension("json")
            
            return url
        }
        
        guard let identifier = URL(string: identifier) else {
            return nil
        }
        
        let queryItems: [URLQueryItem] = [
            .init(name: "language", value: preferedProgrammingLanguage.rawValue)
        ]
        
        let url = Constants.basePath.appending(path: identifier.path)
            .appendingPathExtension("json")
            .appending(queryItems: queryItems)
        
        return url
    }
    
    func getRedirectedURL(for url: URL) async throws -> URL {
        let (_, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, let url = httpResponse.url else {
            throw URLError(.badServerResponse)
        }
        
        return url
    }
    
    // MARK: Homepage
    private let homepageUrl = URL(string: "https://developer.apple.com/tutorials/data/documentation.json")!
    @Published var homepage: HomepageParser?
    
    func fetchHomepage() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: homepageUrl)
            
            let homepage = try JSONDecoder().decode(HomepageParser.self, from: data)
            await MainActor.run {
                self.homepage = homepage
            }
        } catch {
            print(error)
        }
    }
    
    // MARK: Technologies
    private let technologiesUrl = URL(string: "https://developer.apple.com/tutorials/data/documentation/technologies.json")!
    
    @Published var technologies: [TechnologyTypes] = []
    
    func fetchTechnologies() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: technologiesUrl)
            
            let technologies = try JSONDecoder().decode(AppleTechnologies.self, from: data)
            await MainActor.run {
                self.technologies.append(.apple(technologies))
            }
        } catch {
            print(error)
        }
    }
    
    func addTechnology(named name: String, baseUrl: URL) async {
        do {
            let indexUrl = baseUrl.appending(path: "index/index.json")
            let (data, _) = try await URLSession.shared.data(from: indexUrl)
            
            let index = try JSONDecoder().decode(DocCIndex.self, from: data)
            let site = DocCSite(title: name, url: baseUrl, index: index)
            await MainActor.run {
                withAnimation {
                    self.technologies.insert(.docC(site), at: self.technologies.count-1)
                }
            }
        } catch {
            print(error)
        }
    }
    
    // MARK: Frameworks
    
    @Published var frameworks: [String : Framework] = [:]
    
    func fetchFramework(for identifier: String, site: DocCSite?, completion: @escaping () -> Void) {
        Task {
            await fetchFramework(for: identifier, site: site)
            completion()
        }
    }
    
    func fetchFramework(for identifier: String, site: DocCSite?) async {
        do {
            guard let url = jsonUrl(for: identifier, site: site) else { return }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            
            let framework = try JSONDecoder().decode(Framework.self, from: data)
            
            await MainActor.run {
                self.frameworks[identifier] = framework
            }
        } catch {
            print(error)
        }
    }
    
    // MARK: Articles
    
    func fetchArticle(for identifier: String, site: DocCSite?, completion: @escaping (Article) -> Void) {
        Task {
            do {
                let article = try await fetchArticle(for: identifier, site: site)
                completion(article)
            } catch {
                print(error)
            }
        }
    }
    
    func fetchArticle(for identifier: String, site: DocCSite?) async throws -> Article {
//        do {
        guard let url = jsonUrl(for: identifier, site: site) else { throw URLError(.badURL) }
            
            let (data, response) = try await URLSession.shared.data(from: url)
            
            let article = try JSONDecoder().decode(Article.self, from: data)
            
            return article
//        } catch {
//            print(error)
//        }
    }
}
