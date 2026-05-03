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
public final class DocumentationViewModel {
    @ObservationIgnored private let contentLoader = DocumentationContentLoader()
    
    public init() {}
    
    /// The currently selected language used for language-specific DocC requests.
    @MainActor
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
    @MainActor
    public func jsonUrl(for identifier: String, site: DocCSource?) -> URL? {
        if let site {
            return DocCClient.jsonURL(for: identifier, source: site)
        }
        
        return AppleDocsClient(preferredLanguage: preferedProgrammingLanguage).jsonURL(for: identifier)
    }
    
    /// Resolves the final destination URL after redirects.
    ///
    /// - Parameter url: The URL to request.
    /// - Returns: The final URL returned by the server response.
    /// - Throws: `URLError.badServerResponse` when no valid HTTP response URL is available.
    @MainActor
    public func getRedirectedURL(for url: URL) async throws -> URL {
        try await contentLoader.redirectedURL(for: url)
    }
    
    // MARK: Homepage
    /// Parsed homepage payload for Apple documentation.
    @MainActor
    public var homepage: HomepageParser?
    
    @MainActor
    public func fetchHomepage() async {
        do {
            homepage = try await contentLoader.fetchHomepage(preferredLanguage: preferedProgrammingLanguage)
        } catch {
            print(error)
        }
    }
    
    // MARK: Technologies
    /// The in-memory list of loaded technologies from Apple and custom DocC sources.
    @MainActor
    public private(set) var technologies: [TechnologyTypes] = []
    /// Stored reference to the Apple site entry persisted in SwiftData.
    @MainActor
    public private(set) var appleDocCSiteRef: PersistedDocCSource?
    
    @MainActor
    public func fetchTechnologies() async {
        do {
            let technologies = try await contentLoader.fetchTechnologies(preferredLanguage: preferedProgrammingLanguage)
            publishAppleTechnologies(technologies)
        } catch {
            print(error)
        }
    }
    
    /// Returns the currently loaded technologies as a main-actor snapshot.
    @MainActor
    public func technologySnapshot() -> [TechnologyTypes] {
        technologies
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
    @MainActor
    public func addTechnology(baseUrl: URL, modelContext: ModelContext, overrideName: String? = nil) async throws {
        guard !baseUrl.absoluteString.lowercased().contains("developer.apple.com") else {
            let site = DocCSite(url: baseUrl, index: .init(interfaceLanguages: [:]))
            modelContext.insert(site)
            try modelContext.save()
            await loadAppleDocumentation(preferredLanguage: preferedProgrammingLanguage)
            return
        }
        
        do {
            guard !containsDocCSite(with: baseUrl) else {
                return
            }
            
            let index = try await contentLoader.fetchIndex(baseURL: baseUrl)
            
            guard !containsDocCSite(with: baseUrl) else {
                return
            }
            
            let site = DocCSite(url: baseUrl, overrideName: overrideName, index: .init(interfaceLanguages: [:]))
            modelContext.insert(site)
            try modelContext.save()
            
            let modelContainer = modelContext.container
            let persistedSource = PersistedDocCSource(
                id: site.id,
                timestamp: site.timestamp ?? .init(),
                url: baseUrl,
                overrideName: overrideName,
                index: index,
                persistentModelID: site.persistentModelID
            )
            technologies.appendOrUpdate(.docC(persistedSource.docCSource))
            Self.persistDocCIndex(index, for: baseUrl, modelContainer: modelContainer)
        } catch {
            print(error)
        }
    }
    
    /// Loads all persisted technology sites and refreshes the in-memory technology list.
    ///
    /// - Parameters:
    ///   - sites: Persisted DocC source snapshots.
    ///   - modelContainer: Optional SwiftData container used to persist remote index updates.
    @MainActor
    public func loadTechnologies(_ sites: [PersistedDocCSource], modelContainer: ModelContainer? = nil) async {
        let preferredLanguage = preferedProgrammingLanguage
        var customSnapshots: [PersistedDocCSourceSnapshot] = []
        var shouldLoadAppleDocumentation = false
        
        for site in sites {
            let snapshot = PersistedDocCSourceSnapshot(site)
            guard !snapshot.url.absoluteString.contains("developer.apple.com") else {
                guard !technologies.contains(where: { $0.isApple }) else {
                    continue
                }
                appleDocCSiteRef = site
                shouldLoadAppleDocumentation = true
                continue
            }
            
            guard !containsDocCSite(with: snapshot.url) else {
                continue
            }
            
            customSnapshots.append(snapshot)
        }
        
        if shouldLoadAppleDocumentation {
            await loadAppleDocumentation(preferredLanguage: preferredLanguage)
        }
        
        let loadedSources = await Self.loadDocCSources(customSnapshots, using: contentLoader)
        for loadedSource in loadedSources {
            technologies.appendOrUpdate(.docC(loadedSource.docCSource))
            if loadedSource.shouldPersistRemoteIndex, let modelContainer {
                Self.persistDocCIndex(loadedSource.index, for: loadedSource.snapshot.url, modelContainer: modelContainer)
            }
        }
    }
    
    /// Removes a technology from memory and deletes persisted source data using a background context.
    ///
    /// - Parameters:
    ///   - site: The technology to remove.
    ///   - modelContainer: SwiftData container used to create a background deletion context.
    @MainActor
    public func deleteTechnology(_ site: TechnologyTypes, modelContainer: ModelContainer) async throws {
        guard technologies.contains(where: { $0.id == site.id }) else {
            return
        }
        
        technologies.removeAll { $0.id == site.id }
        switch site {
        case .apple:
            guard let site = appleDocCSiteRef else { return }
            let store = DocumentationSwiftDataStore(modelContainer: modelContainer)
            try await store.deleteDocCSite(url: site.url)
        case .docC(let source):
            let store = DocumentationSwiftDataStore(modelContainer: modelContainer)
            try await store.deleteDocCSite(url: source.url)
        }
    }
    
    /// Removes a technology from memory after SwiftData reports that its source record disappeared.
    ///
    /// - Parameters:
    ///   - id: Persisted source identifier.
    ///   - url: Persisted source URL.
    @MainActor
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
    @MainActor
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
        case .docC(let source):
            technologies.removeAll { $0.id == site.id }
            try Self.deleteDocCSite(url: source.url, modelContext: modelContext)
        }
    }
    
    /// Deletes persisted DocC sources matching a URL in the current model context.
    ///
    /// - Parameters:
    ///   - url: Source URL used to locate persisted source records.
    ///   - modelContext: SwiftData context used for deletion.
    @MainActor
    private static func deleteDocCSite(url: URL, modelContext: ModelContext) throws {
        let descriptor = FetchDescriptor<DocCSite>(
            predicate: #Predicate { site in
                site.url == url
            }
        )
        
        for site in try modelContext.fetch(descriptor) {
            modelContext.delete(site)
        }
        
        try modelContext.save()
    }
    
    // MARK: Frameworks
    
    /// Cache of framework payloads keyed by their documentation identifier.
    @MainActor
    public private(set) var frameworks: [String : Framework] = [:]
    
    /// Returns a cached framework payload for a documentation identifier.
    ///
    /// - Parameter identifier: Documentation identifier for the framework.
    /// - Returns: The cached framework payload, if available.
    @MainActor
    public func framework(for identifier: String) -> Framework? {
        frameworks[identifier]
    }
    
    /// Clears a cached framework payload.
    ///
    /// - Parameter identifier: Documentation identifier for the cached framework.
    @MainActor
    public func clearFrameworkCache(for identifier: String) {
        frameworks[identifier] = nil
    }
    
    /// Returns a cached framework or fetches and publishes it when absent.
    ///
    /// - Parameters:
    ///   - identifier: Documentation identifier for the framework.
    ///   - site: Optional custom DocC site used for URL resolution.
    /// - Returns: Cached or newly fetched framework payload.
    @MainActor
    public func cachedOrFetchFramework(for identifier: String, site: DocCSource?) async throws -> Framework {
        if let cached = framework(for: identifier) {
            return cached
        }
        
        return try await fetchFrameworkValue(for: identifier, site: site, publishesToCache: true)
    }
    
    /// Fetches a framework and invokes a completion closure when finished.
    ///
    /// - Parameters:
    ///   - identifier: Documentation identifier for the framework.
    ///   - site: Optional custom DocC site used for URL resolution.
    ///   - completion: Closure called after the fetch attempt completes.
    @MainActor
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
    @MainActor
    public func fetchFramework(for identifier: String, site: DocCSource?) async {
        do {
            _ = try await fetchFrameworkValue(for: identifier, site: site, publishesToCache: true)
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
    @MainActor
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
    @MainActor
    public func fetchArticle(for identifier: String, site: DocCSource?) async throws -> Article {
        try await contentLoader.fetchArticle(for: identifier, site: site, preferredLanguage: preferedProgrammingLanguage)
    }
    
    @MainActor
    private func publishAppleTechnologies(_ appleTechnologies: AppleTechnologies) {
        if let index = technologies.firstIndex(where: { $0.isApple }) {
            technologies[index] = .apple(appleTechnologies)
        } else {
            technologies.append(.apple(appleTechnologies))
        }
    }
    
    @MainActor
    private func containsDocCSite(with url: URL) -> Bool {
        technologies.contains { technology in
            switch technology {
            case .apple:
                return false
            case .docC(let source):
                return source.url == url
            }
        }
    }
    
    @MainActor
    private func loadAppleDocumentation(preferredLanguage: PreferredProgrammingLanguage) async {
        let loader = contentLoader
        async let homepage = loader.fetchHomepage(preferredLanguage: preferredLanguage)
        async let technologies = loader.fetchTechnologies(preferredLanguage: preferredLanguage)
        
        do {
            let (loadedHomepage, loadedTechnologies) = try await (homepage, technologies)
            self.homepage = loadedHomepage
            publishAppleTechnologies(loadedTechnologies)
        } catch {
            print(error)
        }
    }
    
    private static func loadDocCSources(_ snapshots: [PersistedDocCSourceSnapshot], using loader: DocumentationContentLoader) async -> [LoadedDocCSource] {
        return await withTaskGroup(of: LoadedDocCSource?.self, returning: [LoadedDocCSource].self) { group in
            for snapshot in snapshots {
                group.addTask {
                    do {
                        try Task.checkCancellation()
                        let index = try await loader.fetchIndex(baseURL: snapshot.url)
                        return LoadedDocCSource(
                            snapshot: snapshot,
                            index: index,
                            shouldPersistRemoteIndex: snapshot.index != index
                        )
                    } catch is CancellationError {
                        return nil
                    } catch {
                        print(error)
                        return nil
                    }
                }
            }
            
            var loadedSources: [LoadedDocCSource] = []
            for await loadedSource in group {
                if let loadedSource {
                    loadedSources.append(loadedSource)
                }
            }
            
            return loadedSources.sorted { lhs, rhs in
                lhs.snapshot.timestamp < rhs.snapshot.timestamp
            }
        }
    }
    
    @MainActor
    private func fetchFrameworkValue(for identifier: String, site: DocCSource?, publishesToCache: Bool) async throws -> Framework {
        let framework = try await contentLoader.fetchFramework(for: identifier, site: site, preferredLanguage: preferedProgrammingLanguage)
        
        if publishesToCache {
            frameworks[identifier] = framework
        }
        
        return framework
    }
    
    @MainActor
    func frameworkResolver() -> DocumentationFrameworkResolver {
        DocumentationFrameworkResolver(contentLoader: contentLoader, preferredLanguage: preferedProgrammingLanguage)
    }
    
    private static func persistDocCIndex(_ index: DocCIndex, for url: URL, modelContainer: ModelContainer) {
        Task(priority: .utility) {
            do {
                let store = DocumentationSwiftDataStore(modelContainer: modelContainer)
                try await store.persistDocCIndex(index, for: url)
            } catch {
                print(error)
            }
        }
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

private struct DocumentationContentCacheKey: Hashable, Sendable {
    var identifier: String
    var sourceURL: URL?
    var preferredLanguage: PreferredProgrammingLanguage
}

private struct PersistedDocCSourceSnapshot: Sendable {
    var id: UUID
    var timestamp: Date
    var url: URL
    var overrideName: String?
    var index: DocCIndex
    
    @MainActor
    init(_ source: PersistedDocCSource) {
        self.id = source.id
        self.timestamp = source.timestamp
        self.url = source.url
        self.overrideName = source.overrideName
        self.index = source.index
    }
}

private struct LoadedDocCSource: Sendable {
    var snapshot: PersistedDocCSourceSnapshot
    var index: DocCIndex
    var shouldPersistRemoteIndex: Bool
    
    var docCSource: DocCSource {
        DocCSource(
            id: snapshot.id,
            timestamp: snapshot.timestamp,
            url: snapshot.url,
            overrideName: snapshot.overrideName,
            index: index
        )
    }
}

struct DocumentationFrameworkResolver: Sendable {
    fileprivate var contentLoader: DocumentationContentLoader
    var preferredLanguage: PreferredProgrammingLanguage
    
    func fetchFramework(for identifier: String, site: DocCSource?) async throws -> Framework {
        try await contentLoader.fetchFramework(for: identifier, site: site, preferredLanguage: preferredLanguage)
    }
}

actor DocumentationContentLoader {
    private var frameworkTasks: [DocumentationContentCacheKey : Task<Framework, Error>] = [:]
    private var articleTasks: [DocumentationContentCacheKey : Task<Article, Error>] = [:]
    private var indexTasks: [URL : Task<DocCIndex, Error>] = [:]
    
    func redirectedURL(for url: URL) async throws -> URL {
        try await DocCClient.redirectedURL(for: url)
    }
    
    func fetchHomepage(preferredLanguage: PreferredProgrammingLanguage) async throws -> HomepageParser {
        try await AppleDocsClient(preferredLanguage: preferredLanguage).fetchHomepage()
    }
    
    func fetchTechnologies(preferredLanguage: PreferredProgrammingLanguage) async throws -> AppleTechnologies {
        try await AppleDocsClient(preferredLanguage: preferredLanguage).fetchTechnologies()
    }
    
    func fetchIndex(baseURL: URL) async throws -> DocCIndex {
        if let task = indexTasks[baseURL] {
            return try await task.value
        }
        
        let task = Task {
            try await DocCClient.fetchIndex(baseURL: baseURL)
        }
        indexTasks[baseURL] = task
        
        do {
            let index = try await task.value
            indexTasks[baseURL] = nil
            return index
        } catch {
            indexTasks[baseURL] = nil
            throw error
        }
    }
    
    func fetchFramework(
        for identifier: String,
        site: DocCSource?,
        preferredLanguage: PreferredProgrammingLanguage
    ) async throws -> Framework {
        let key = DocumentationContentCacheKey(identifier: identifier, sourceURL: site?.url, preferredLanguage: preferredLanguage)
        if let task = frameworkTasks[key] {
            return try await task.value
        }
        
        let task = Task {
            let client = site.map { DocCClientBridge.docC($0) } ?? .apple(preferredLanguage: preferredLanguage)
            return try await client.fetchFramework(for: identifier)
        }
        frameworkTasks[key] = task
        
        do {
            let framework = try await task.value
            frameworkTasks[key] = nil
            return framework
        } catch {
            frameworkTasks[key] = nil
            throw error
        }
    }
    
    func fetchArticle(
        for identifier: String,
        site: DocCSource?,
        preferredLanguage: PreferredProgrammingLanguage
    ) async throws -> Article {
        let key = DocumentationContentCacheKey(identifier: identifier, sourceURL: site?.url, preferredLanguage: preferredLanguage)
        if let task = articleTasks[key] {
            return try await task.value
        }
        
        let task = Task {
            let client = site.map { DocCClientBridge.docC($0) } ?? .apple(preferredLanguage: preferredLanguage)
            return try await client.fetchArticle(for: identifier, preferredLanguage: preferredLanguage)
        }
        articleTasks[key] = task
        
        do {
            let article = try await task.value
            articleTasks[key] = nil
            return article
        } catch {
            articleTasks[key] = nil
            throw error
        }
    }
}

@ModelActor
private actor DocumentationSwiftDataStore {
    /// Persists a full DocC index after the source has already appeared in the UI.
    ///
    /// - Parameters:
    ///   - index: Decoded index to store for offline use and persisted search.
    ///   - url: Source URL used to find the persisted source record.
    func persistDocCIndex(_ index: DocCIndex, for url: URL) throws {
        let descriptor = FetchDescriptor<DocCSite>(
            predicate: #Predicate { site in
                site.url == url
            }
        )
        
        guard let site = try modelContext.fetch(descriptor).first else {
            return
        }
        
        site.indexV2 = DocCSite.DocCIndexModel(index)
        try modelContext.save()
    }
    
    /// Deletes persisted DocC sources matching a URL.
    ///
    /// - Parameter url: Source URL used to locate persisted source records.
    func deleteDocCSite(url: URL) throws {
        let descriptor = FetchDescriptor<DocCSite>(
            predicate: #Predicate { site in
                site.url == url
            }
        )
        
        for site in try modelContext.fetch(descriptor) {
            modelContext.delete(site)
        }
        
        try modelContext.save()
    }
}
