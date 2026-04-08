//
//  DocumentationViewModel.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/6/24.
//

import Foundation
import SwiftUI
import SwiftData

/// Represents the preferred programming language used when requesting language-specific DocC content.
public enum PreferedProgrammingLanguage: String, Codable, CaseIterable, Sendable {
    case swift
    case objectivec = "objc"
    case data
    
    /// A user-facing language label used in UI surfaces.
    public var humanReadable: String? {
        switch self {
        case .swift:
            "Swift"
        case .objectivec:
            "Objective-C"
        case .data:
            nil
        }
    }
    
    /// The language token expected in certain DocC variant payloads.
    public var jsonCodingValue: String {
        switch self {
        case .swift:
            "swift"
        case .objectivec:
            "occ"
        case .data:
            "data"
        }
    }
    
    /// Creates a language from persisted and legacy raw values.
    ///
    /// This initializer accepts both current and historical values such as `objc` and `occ`.
    public init?(rawValue: String) {
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

@Observable
@MainActor
/// Central state and networking coordinator for DocC technologies, frameworks, and articles.
public class DocumentationViewModel {
    public init() {}
    
    /// The currently selected language used for language-specific DocC requests.
    public var preferedProgrammingLanguage: PreferedProgrammingLanguage = UserDefaults.standard.string(forKey: "preferedProgrammingLanguage").flatMap(PreferedProgrammingLanguage.init(rawValue:)) ?? .swift {
        didSet {
            UserDefaults.standard.set(preferedProgrammingLanguage.rawValue, forKey: "preferedProgrammingLanguage")
        }
    }
    
    // MARK: URL Functions
    /// Builds the JSON endpoint for a documentation identifier.
    ///
    /// - Parameters:
    ///   - identifier: A documentation identifier or URL-like identifier.
    ///   - site: The custom DocC site context when resolving non-Apple documentation.
    /// - Returns: A JSON URL for the requested identifier, or `nil` if the identifier is invalid.
    public func jsonUrl(for identifier: String, site: DocCSiteDTO?) -> URL? {
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
    
    /// Resolves the final destination URL after redirects.
    ///
    /// - Parameter url: The URL to request.
    /// - Returns: The final URL returned by the server response.
    /// - Throws: `URLError.badServerResponse` when no valid HTTP response URL is available.
    public func getRedirectedURL(for url: URL) async throws -> URL {
        let (_, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, let url = httpResponse.url else {
            throw URLError(.badServerResponse)
        }
        
        return url
    }
    
    // MARK: Homepage
    private let homepageUrl = URL(string: "\(Constants.aDeveloperURLBase)/tutorials/data/documentation.json")!
    /// Parsed homepage payload for Apple documentation.
    public var homepage: HomepageParser?
    
    public func fetchHomepage() async {
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
    private let technologiesUrl = URL(string: "\(Constants.aDeveloperURLBase)/tutorials/data/documentation/technologies.json")!
    
    /// The in-memory list of loaded technologies from Apple and custom DocC sources.
    public private(set) var technologies: [TechnologyTypes] = []
    /// Stored reference to the Apple site entry persisted in SwiftData.
    public private(set) var appleDocCSiteRef: DocCSiteDTO?
    
    public func fetchTechnologies() async {
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
    
    /// Adds a new technology source and updates in-memory technology listings.
    ///
    /// Apple sources are treated specially and mapped to the built-in homepage and technologies endpoints.
    /// If a custom DocC source with the same URL already exists, this method quietly returns without adding a duplicate.
    ///
    /// - Parameters:
    ///   - baseUrl: Root URL of the DocC site.
    ///   - modelContext: SwiftData context used for persistence.
    ///   - overrideName: Optional custom display name for the site.
    public func addTechnology(baseUrl: URL, modelContext: ModelContext, overrideName: String? = nil) async throws {
        guard !baseUrl.absoluteString.lowercased().contains("developer.apple.com") else {
            let site = DocCSite(url: baseUrl, index: .init(interfaceLanguages: [:]))
            modelContext.insert(site)
            try modelContext.save()
            await fetchHomepage()
            await fetchTechnologies()
            return
        }
        do {
            guard !technologies.contains(where: { tech in
                switch tech {
                case .apple:
                    return false
                case .docC(let docCSiteDTO):
                    return docCSiteDTO.url == baseUrl
                }
            }) else {
                return
            }
            let indexUrl = baseUrl.appending(path: "index/index.json")
            let (data, _) = try await URLSession.shared.data(from: indexUrl)
            
            let index = try JSONDecoder().decode(DocCIndex.self, from: data)
            let site = DocCSite(url: baseUrl, overrideName: overrideName, index: index)
            modelContext.insert(site)
            try modelContext.save()
            let dto = try site.dto
            await MainActor.run {
                withAnimation {
                    self.technologies.appendOrUpdate(.docC(dto))
                }
            }
        } catch {
            print(error)
        }
    }
    
    /// Loads all persisted technology sites and refreshes the in-memory technology list.
    ///
    /// - Parameter sites: Persisted DocC site DTOs.
    public func loadTechnologies(_ sites: [DocCSiteDTO]) async {
        for site in sites {
            guard !site.url.absoluteString.contains("developer.apple.com") else {
                guard !technologies.contains(where: { $0.isApple }) else {
                    continue
                }
                appleDocCSiteRef = site
                await fetchHomepage()
                await fetchTechnologies()
                continue
            }
            do {
                let indexUrl = site.url.appending(path: "index/index.json")
                let (data, _) = try await URLSession.shared.data(from: indexUrl)
                
                let index = try JSONDecoder().decode(DocCIndex.self, from: data)
                site.setIndex(index)
                await MainActor.run {
                    withAnimation {
                        self.technologies.appendOrUpdate(.docC(site))
                    }
                }
            } catch {
                print(error)
            }
        }
    }
    
    /// Removes a technology from memory and persistence.
    ///
    /// - Parameters:
    ///   - site: The technology to remove.
    ///   - modelContext: SwiftData context used for deletion.
    public func deleteTechnology(_ site: TechnologyTypes, modelContext: ModelContext) throws {
        guard technologies.contains(where: { $0.id == site.id }) else {
            return
        }
        
        switch site {
        case .apple:
            technologies.removeAll { $0.id == site.id }
            if let site = appleDocCSiteRef {
                try site.deleteSite(modelContext: modelContext)
            }
        case .docC(let docCSiteDTO):
            technologies.removeAll { $0.id == site.id }
            try docCSiteDTO.deleteSite(modelContext: modelContext)
        }
    }
    
    // MARK: Frameworks
    
    /// Cache of framework payloads keyed by their documentation identifier.
    public var frameworks: [String : Framework] = [:]
    
    /// Fetches a framework and invokes a completion closure when finished.
    ///
    /// - Parameters:
    ///   - identifier: Documentation identifier for the framework.
    ///   - site: Optional custom DocC site used for URL resolution.
    ///   - completion: Closure called after the fetch attempt completes.
    public func fetchFramework(for identifier: String, site: DocCSiteDTO?, completion: @escaping () -> Void) {
        Task {
            await fetchFramework(for: identifier, site: site)
            completion()
        }
    }
    
    /// Fetches and caches a framework payload for a documentation identifier.
    ///
    /// - Parameters:
    ///   - identifier: Documentation identifier for the framework.
    ///   - site: Optional custom DocC site used for URL resolution.
    public func fetchFramework(for identifier: String, site: DocCSiteDTO?) async {
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
    
    /// Fetches an article and delivers it using a completion closure.
    ///
    /// - Parameters:
    ///   - identifier: Documentation identifier for the article.
    ///   - site: Optional custom DocC site used for URL resolution.
    ///   - completion: Closure receiving the decoded article.
    public func fetchArticle(for identifier: String, site: DocCSiteDTO?, completion: @escaping (Article) -> Void) {
        Task {
            do {
                let article = try await fetchArticle(for: identifier, site: site)
                completion(article)
            } catch {
                print(error)
            }
        }
    }
    
    /// Fetches and decodes a documentation article, applying variant overrides for the selected language.
    ///
    /// Variant patches currently update declaration overrides in `primaryContentSections`.
    /// When a patch includes an index for that section, the index from the payload is used directly.
    ///
    /// - Parameters:
    ///   - identifier: Documentation identifier for the article.
    ///   - site: Optional custom DocC site used for URL resolution.
    /// - Returns: A decoded article with applicable language-specific declaration overrides applied.
    /// - Throws: URL and decoding errors encountered while fetching or parsing the article.
    public func fetchArticle(for identifier: String, site: DocCSiteDTO?) async throws -> Article {
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

extension [TechnologyTypes] {
    /// Appends a technology when absent, or replaces the existing matching item by identifier.
    ///
    /// - Parameter new: The technology entry to insert or update.
    public mutating func appendOrUpdate(_ new: TechnologyTypes) {
        guard let index = firstIndex(where: { $0.id == new.id }) else {
            append(new)
            return
        }
        
        self[index] = new
    }
}
