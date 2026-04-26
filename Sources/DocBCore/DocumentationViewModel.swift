//
//  DocumentationViewModel.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/6/24.
//

import Foundation
import SwiftUI
import SwiftData
import DocCKit

/// Central state and networking coordinator for DocC technologies, frameworks, and articles.
@Observable
@MainActor
public class DocumentationViewModel {
    public init() {}
    
    /// The currently selected language used for language-specific DocC requests.
    public var preferedProgrammingLanguage: PreferredProgrammingLanguage = UserDefaults.standard.string(forKey: "preferedProgrammingLanguage").flatMap(PreferredProgrammingLanguage.init(rawValue:)) ?? .swift {
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
    public func jsonUrl(for identifier: String, site: DocCSource?) -> URL? {
        if let site {
            return DocCClient().jsonURL(for: identifier, source: site)
        }
        
        return AppleDocsClient(preferredLanguage: preferedProgrammingLanguage).jsonURL(for: identifier)
    }
    
    /// Resolves the final destination URL after redirects.
    ///
    /// - Parameter url: The URL to request.
    /// - Returns: The final URL returned by the server response.
    /// - Throws: `URLError.badServerResponse` when no valid HTTP response URL is available.
    public func getRedirectedURL(for url: URL) async throws -> URL {
        try await DocCClient().redirectedURL(for: url)
    }
    
    // MARK: Homepage
    /// Parsed homepage payload for Apple documentation.
    public var homepage: HomepageParser?
    
    public func fetchHomepage() async {
        do {
            let homepage = try await AppleDocsClient(preferredLanguage: preferedProgrammingLanguage).fetchHomepage()
            await MainActor.run {
                self.homepage = homepage
            }
        } catch {
            print(error)
        }
    }
    
    // MARK: Technologies
    /// The in-memory list of loaded technologies from Apple and custom DocC sources.
    public private(set) var technologies: [TechnologyTypes] = []
    /// Stored reference to the Apple site entry persisted in SwiftData.
    public private(set) var appleDocCSiteRef: DocCSiteDTO?
    
    public func fetchTechnologies() async {
        do {
            let technologies = try await AppleDocsClient(preferredLanguage: preferedProgrammingLanguage).fetchTechnologies()
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
            let index = try await DocCClient().fetchIndex(baseURL: baseUrl)
            let site = DocCSite(url: baseUrl, overrideName: overrideName, index: .init(interfaceLanguages: [:]))
            modelContext.insert(site)
            try modelContext.save()
            let modelContainer = modelContext.container
            let dto = DocCSiteDTO(
                id: site.id,
                timestamp: site.timestamp ?? .init(),
                url: baseUrl,
                overrideName: overrideName,
                index: index,
                persistentModelID: site.persistentModelID
            )
            technologies.appendOrUpdate(.docC(dto))
            Task.detached(priority: .utility) {
                do {
                    try await Self.persistDocCIndex(index, for: baseUrl, modelContainer: modelContainer)
                } catch {
                    print(error)
                }
            }
        } catch {
            print(error)
        }
    }
    
    /// Loads all persisted technology sites and refreshes the in-memory technology list.
    ///
    /// - Parameters:
    ///   - sites: Persisted DocC site DTOs.
    ///   - modelContainer: Optional SwiftData container used to persist remote index updates.
    public func loadTechnologies(_ sites: [DocCSiteDTO], modelContainer: ModelContainer? = nil) async {
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
            
            guard !technologies.contains(where: { technology in
                switch technology {
                case .apple:
                    return false
                case .docC(let loadedSite):
                    return loadedSite.url == site.url
                }
            }) else {
                continue
            }
            
            do {
                let index = try await DocCClient().fetchIndex(baseURL: site.url)
                let shouldPersistRemoteIndex = site.index != index
                site.setIndex(index)
                technologies.appendOrUpdate(.docC(site))
                if shouldPersistRemoteIndex, let modelContainer {
                    let siteURL = site.url
                    Task.detached(priority: .utility) {
                        do {
                            try await Self.persistDocCIndex(index, for: siteURL, modelContainer: modelContainer)
                        } catch {
                            print(error)
                        }
                    }
                }
            } catch {
                print(error)
            }
        }
    }
    
    /// Fetches and decodes a DocC index away from the main actor.
    ///
    /// - Parameter indexUrl: URL for the source's `index/index.json` payload.
    /// - Returns: A decoded DocC index.
    private nonisolated static func fetchDocCIndex(from indexUrl: URL) async throws -> DocCIndex {
        try await DocCClient().fetchIndex(from: indexUrl)
    }
    
    /// Persists a full DocC index after the source has already appeared in the UI.
    ///
    /// - Parameters:
    ///   - index: Decoded index to store for offline use and persisted search.
    ///   - url: Source URL used to find the persisted source record.
    ///   - modelContainer: Container used to create the background context.
    private nonisolated static func persistDocCIndex(
        _ index: DocCIndex,
        for url: URL,
        modelContainer: ModelContainer
    ) async throws {
        try await Task.detached(priority: .utility) {
            let context = ModelContext(modelContainer)
            let descriptor = FetchDescriptor<DocCSite>(
                predicate: #Predicate { site in
                    site.url == url
                }
            )
            
            guard let site = try context.fetch(descriptor).first else {
                return
            }
            
            site.indexV2 = DocCSite.DocCIndexModel(index)
            try context.save()
        }.value
    }
    
    /// Removes a technology from memory and deletes persisted source data using a background context.
    ///
    /// - Parameters:
    ///   - site: The technology to remove.
    ///   - modelContainer: SwiftData container used to create a background deletion context.
    public func deleteTechnology(_ site: TechnologyTypes, modelContainer: ModelContainer) async throws {
        guard technologies.contains(where: { $0.id == site.id }) else {
            return
        }
        
        switch site {
        case .apple:
            technologies.removeAll { $0.id == site.id }
            if let site = appleDocCSiteRef {
                try await Self.deleteDocCSite(
                    persistentModelID: site.persistentModelID,
                    url: site.url,
                    modelContainer: modelContainer
                )
            }
        case .docC(let docCSiteDTO):
            technologies.removeAll { $0.id == site.id }
            try await Self.deleteDocCSite(
                persistentModelID: docCSiteDTO.persistentModelID,
                url: docCSiteDTO.url,
                modelContainer: modelContainer
            )
        }
    }
    
    /// Deletes a persisted DocC site away from the main actor.
    ///
    /// - Parameters:
    ///   - persistentModelID: Preferred persistent identifier for the site.
    ///   - url: Source URL used as a fallback lookup.
    ///   - modelContainer: Container used to create the background context.
    private nonisolated static func deleteDocCSite(
        persistentModelID: PersistentIdentifier?,
        url: URL,
        modelContainer: ModelContainer
    ) async throws {
        try await Task.detached(priority: .userInitiated) {
            let context = ModelContext(modelContainer)
            
            if let persistentModelID {
                let model = context.model(for: persistentModelID)
                context.delete(model)
            } else {
                let descriptor = FetchDescriptor<DocCSite>(
                    predicate: #Predicate { site in
                        site.url == url
                    }
                )
                for site in try context.fetch(descriptor) {
                    context.delete(site)
                }
            }
            
            try context.save()
        }.value
    }
    
    /// Removes a technology from memory after SwiftData reports that its source record disappeared.
    ///
    /// - Parameters:
    ///   - id: Persisted source identifier.
    ///   - url: Persisted source URL.
    public func removeTechnologyFromMemory(id: UUID, url: URL?) {
        technologies.removeAll { technology in
            switch technology {
            case .apple:
                return appleDocCSiteRef?.id == id || appleDocCSiteRef?.url == url
            case .docC(let site):
                return site.id == id || site.url == url
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
    public func fetchFramework(for identifier: String, site: DocCSource?, completion: @escaping () -> Void) {
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
    public func fetchFramework(for identifier: String, site: DocCSource?) async {
        do {
            let client = site.map { DocCClientBridge.docC($0) } ?? .apple(preferredLanguage: preferedProgrammingLanguage)
            let framework = try await client.fetchFramework(for: identifier)
            
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
    public func fetchArticle(for identifier: String, site: DocCSource?, completion: @escaping (Article) -> Void) {
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
    public func fetchArticle(for identifier: String, site: DocCSource?) async throws -> Article {
        let client = site.map { DocCClientBridge.docC($0) } ?? .apple(preferredLanguage: preferedProgrammingLanguage)
        return try await client.fetchArticle(for: identifier, preferredLanguage: preferedProgrammingLanguage)
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
