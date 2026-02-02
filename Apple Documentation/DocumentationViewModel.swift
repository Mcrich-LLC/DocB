//
//  DocumentationViewModel.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/6/24.
//

import Foundation
import SwiftUI
import SwiftData

/// Enum representing the user's preferred programming language.
enum PreferedProgrammingLanguage: String, Codable, CaseIterable {
    /// Swift programming language.
    case swift
    /// Objective-C programming language.
    case objectivec = "objc"
    /// Data representation (raw JSON).
    case data
    
    /// A human-readable string representation of the language.
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
    
    /// The string value used for JSON coding (API requests).
    var jsonCodingValue: String {
        switch self {
        case .swift:
            "swift"
        case .objectivec:
            "occ"
        case .data:
            "data"
        }
    }
    
    /// Initializes from a raw string value, handling variations like "occ".
    init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "swift":
            self = .swift
        case "objc", "occ":
            self = .objectivec
        case "data":
            self = .data
        default:
            return nil
        }
    }
}

/// The main view model for managing documentation data and application state.
@Observable
@MainActor
class DocumentationViewModel {
    /// The user's preferred programming language, persisted in `UserDefaults`.
    var preferedProgrammingLanguage: PreferedProgrammingLanguage = UserDefaults.standard.string(forKey: "preferedProgrammingLanguage").flatMap(PreferedProgrammingLanguage.init(rawValue:)) ?? .swift {
        didSet {
            UserDefaults.standard.set(preferedProgrammingLanguage.rawValue, forKey: "preferedProgrammingLanguage")
        }
    }
    
    // MARK: URL Functions
    /// Constructs the URL for fetching JSON documentation for a given identifier.
    ///
    /// - Parameters:
    ///   - identifier: The identifier of the documentation topic.
    ///   - site: The optional DocC site configuration.
    /// - Returns: A `URL` pointing to the JSON data, or `nil` if the URL cannot be constructed.
    func jsonUrl(for identifier: String, site: DocCSiteDTO?) -> URL? {
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
    
    /// Resolves the final redirected URL for a given URL.
    ///
    /// - Parameter url: The initial URL to check.
    /// - Returns: The final URL after following redirects.
    /// - Throws: `URLError` if the server response is invalid.
    func getRedirectedURL(for url: URL) async throws -> URL {
        let (_, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, let url = httpResponse.url else {
            throw URLError(.badServerResponse)
        }
        
        return url
    }
    
    // MARK: Homepage
    private let homepageUrl = URL(string: "https://developer.apple.com/tutorials/data/documentation.json")!
    /// The parsed homepage data.
    var homepage: HomepageParser?
    
    /// Fetches the homepage data from the Apple Developer website.
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
    
    /// The list of available technologies (e.g., frameworks, libraries).
    private(set) var technologies: [TechnologyTypes] = []
    
    /// Fetches the list of technologies from the Apple Developer website.
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
    
    /// Adds a custom technology (DocC site) to the app.
    ///
    /// - Parameters:
    ///   - baseUrl: The base URL of the DocC site.
    ///   - modelContext: The SwiftData model context for persistence.
    func addTechnology(baseUrl: URL, modelContext: ModelContext) async {
        do {
            let indexUrl = baseUrl.appending(path: "index/index.json")
            let (data, _) = try await URLSession.shared.data(from: indexUrl)
            
            let index = try JSONDecoder().decode(DocCIndex.self, from: data)
            let site = DocCSite(url: baseUrl, index: index)
            modelContext.insert(site)
            await MainActor.run {
                withAnimation {
                    self.technologies.insert(.docC(site.dto), at: self.technologies.count-1)
                }
            }
        } catch {
            print(error)
        }
    }
    
    /// Loads existing custom technologies from saved DocC sites.
    ///
    /// - Parameter sites: An array of `DocCSiteDTO` representing saved sites.
    func loadTechnologies(_ sites: [DocCSiteDTO]) async {
        for site in sites {
            do {
                let indexUrl = site.url.appending(path: "index/index.json")
                let (data, _) = try await URLSession.shared.data(from: indexUrl)
                
                let index = try JSONDecoder().decode(DocCIndex.self, from: data)
                site.setIndex(index)
                await MainActor.run {
                    withAnimation {
                        self.technologies.append(.docC(site))
                    }
                }
            } catch {
                print(error)
            }
        }
    }
    
    /// Deletes a custom technology.
    ///
    /// - Parameters:
    ///   - site: The `DocCSiteDTO` to delete.
    ///   - modelContext: The SwiftData model context.
    func deleteTechnology(_ site: DocCSiteDTO, modelContext: ModelContext) {
        technologies.removeAll { $0.id == site.id }
        site.deleteSite(modelContext: modelContext)
    }
    
    // MARK: Frameworks
    
    /// A cache of fetched frameworks, keyed by their identifier.
    var frameworks: [String : Framework] = [:]
    
    /// Fetches a framework's documentation asynchronously and executes a completion handler.
    ///
    /// - Parameters:
    ///   - identifier: The identifier of the framework.
    ///   - site: The optional DocC site configuration.
    ///   - completion: A closure executed when the fetch is complete.
    func fetchFramework(for identifier: String, site: DocCSiteDTO?, completion: @escaping () -> Void) {
        Task {
            await fetchFramework(for: identifier, site: site)
            completion()
        }
    }
    
    /// Fetches a framework's documentation asynchronously.
    ///
    /// The fetched framework is stored in the `frameworks` dictionary.
    ///
    /// - Parameters:
    ///   - identifier: The identifier of the framework.
    ///   - site: The optional DocC site configuration.
    func fetchFramework(for identifier: String, site: DocCSiteDTO?) async {
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
    
    /// Fetches an article's documentation asynchronously and executes a completion handler.
    ///
    /// - Parameters:
    ///   - identifier: The identifier of the article.
    ///   - site: The optional DocC site configuration.
    ///   - completion: A closure executed with the fetched `Article`.
    func fetchArticle(for identifier: String, site: DocCSiteDTO?, completion: @escaping (Article) -> Void) {
        Task {
            do {
                let article = try await fetchArticle(for: identifier, site: site)
                completion(article)
            } catch {
                print(error)
            }
        }
    }
    
    /// Fetches an article's documentation asynchronously.
    ///
    /// This method also handles language-specific variants and overrides, updating the article's content
    /// based on the `preferedProgrammingLanguage`.
    ///
    /// - Parameters:
    ///   - identifier: The identifier of the article.
    ///   - site: The optional DocC site configuration.
    /// - Returns: The fetched and processed `Article`.
    /// - Throws: `URLError` or decoding errors.
    func fetchArticle(for identifier: String, site: DocCSiteDTO?) async throws -> Article {
//        do {
        guard let url = jsonUrl(for: identifier, site: site) else { throw URLError(.badURL) }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        var article = try JSONDecoder().decode(Article.self, from: data)
        
        for variant in (article.variantOverrides ?? []) where variant.patch.contains(where: {
            ($0.value?.declarations ?? []).contains(where: {
                $0.languages.contains(preferedProgrammingLanguage.jsonCodingValue)
            })
        }) {
            for patch in variant.patch where (patch.value?.declarations ?? []).contains(where: { $0.languages.contains(preferedProgrammingLanguage.jsonCodingValue) }) {
                let pathComponents = patch.path.split(separator: "/")
                // Handle primaryContentSections
                if pathComponents.contains(where: { $0 == "primaryContentSections" }), let indexString = pathComponents.last, let index = Int(indexString) {
                    article.primaryContentSections?[index].declarations = patch.value?.declarations
                }
            }
        }
        
        return article
//        } catch {
//            print(error)
//        }
    }
}
