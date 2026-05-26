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
import FactoryKit

/// Central state and networking coordinator for DocC technologies, frameworks, and articles.
@Observable
public final class DocumentationViewModel {
    @ObservationIgnored @Injected(\.documentationContentLoader) private var contentLoader
    @ObservationIgnored @Injected(\.documentationSwiftDataStore) private var swiftDataStore
    
    public init() {}
    
    /// The currently selected language used for language-specific DocC requests.
    @MainActor
    public var preferedProgrammingLanguage: PreferredProgrammingLanguage = UserDefaults.standard.string(forKey: "preferedProgrammingLanguage").flatMap(PreferredProgrammingLanguage.init(rawValue:)) ?? .swift {
        didSet {
            UserDefaults.standard.set(preferedProgrammingLanguage.rawValue, forKey: "preferedProgrammingLanguage")
            clearFrameworkCache()
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
    ///   - overrideName: Optional custom display name for the site.
    @MainActor
    public func addTechnology(baseUrl: URL, overrideName: String? = nil) async throws {
        guard !baseUrl.absoluteString.lowercased().contains("developer.apple.com") else {
            let index = DocCIndex(interfaceLanguages: [:])
            let insertedSource = try await swiftDataStore.insertDocCSite(
                url: baseUrl,
                overrideName: nil,
                index: index
            )
            appleDocCSiteRef = insertedSource.persistedSource(index: index)
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
            
            let insertedSource = try await swiftDataStore.insertDocCSite(
                url: baseUrl,
                overrideName: overrideName,
                index: .init(interfaceLanguages: [:])
            )
            let persistedSource = insertedSource.persistedSource(index: index)
            technologies.appendOrUpdate(.docC(persistedSource.docCSource))
            persistDocCIndex(index, for: baseUrl)
        } catch {
            print(error)
        }
    }
    
    /// Loads all persisted technology sites and refreshes the in-memory technology list.
    ///
    /// - Parameter sites: Persisted DocC source snapshots.
    @MainActor
    public func loadTechnologies(_ sites: [PersistedDocCSource]) async {
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
            if loadedSource.shouldPersistRemoteIndex {
                persistDocCIndex(loadedSource.index, for: loadedSource.snapshot.url)
            }
        }
    }
    
    /// Removes a technology from memory and deletes persisted source data using a background context.
    ///
    /// - Parameter site: The technology to remove.
    @MainActor
    public func deleteTechnology(_ site: TechnologyTypes) async throws {
        guard technologies.contains(where: { $0.id == site.id }) else {
            return
        }
        
        switch site {
        case .apple:
            try await swiftDataStore.deleteDocCSite(url: appleDocCSiteRef?.url ?? site.url)
            appleDocCSiteRef = nil
        case .docC(let source):
            try await swiftDataStore.deleteDocCSite(url: source.url)
        }

        technologies.removeAll { $0.id == site.id }
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
    
    /// Clears all cached framework payloads.
    @MainActor
    public func clearFrameworkCache() {
        frameworks.removeAll()
    }

    /// Stores framework payloads discovered by background filtering into the observed cache.
    ///
    /// - Parameter frameworks: Framework payloads keyed by their documentation identifier.
    @MainActor
    public func cacheFrameworks(_ frameworks: [String : Framework]) {
        self.frameworks.merge(frameworks) { _, newValue in
            newValue
        }
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
    
    /// Publishes Apple technologies into the observed technology list without creating duplicate Apple entries.
    ///
    /// - Parameter appleTechnologies: Apple documentation technology payload to insert or replace.
    @MainActor
    private func publishAppleTechnologies(_ appleTechnologies: AppleTechnologies) {
        if let index = technologies.firstIndex(where: { $0.isApple }) {
            technologies[index] = .apple(appleTechnologies)
        } else {
            technologies.append(.apple(appleTechnologies))
        }
    }
    
    /// Checks whether the observed technology list already includes a custom DocC source for a URL.
    ///
    /// - Parameter url: Root URL of the DocC source to find.
    /// - Returns: `true` when a matching custom DocC source is already loaded.
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
    
    /// Loads Apple homepage and technology payloads concurrently, then publishes both results together.
    ///
    /// - Parameter preferredLanguage: Language to use for Apple documentation requests.
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
    
    /// Loads fresh custom DocC source indexes concurrently from sendable persisted-source snapshots.
    ///
    /// - Parameters:
    ///   - snapshots: Value snapshots derived from persisted sources on the main actor.
    ///   - loader: Background content actor used to fetch source indexes.
    /// - Returns: Loaded source values sorted by their original timestamp.
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
    
    /// Fetches a framework through the content actor and optionally publishes it into the observed cache.
    ///
    /// - Parameters:
    ///   - identifier: Documentation identifier for the framework.
    ///   - site: Optional custom DocC site used for URL resolution.
    ///   - publishesToCache: Whether the fetched framework should update `frameworks`.
    /// - Returns: The decoded framework payload.
    @MainActor
    private func fetchFrameworkValue(for identifier: String, site: DocCSource?, publishesToCache: Bool) async throws -> Framework {
        let framework = try await contentLoader.fetchFramework(for: identifier, site: site, preferredLanguage: preferedProgrammingLanguage)
        
        if publishesToCache {
            frameworks[identifier] = framework
        }
        
        return framework
    }
    
    /// Creates a sendable resolver that can fetch nested frameworks without capturing the observable view model.
    ///
    /// - Returns: A resolver configured with the current preferred language and content loader.
    @MainActor
    func frameworkResolver() -> DocumentationFrameworkResolver {
        DocumentationFrameworkResolver(contentLoader: contentLoader, preferredLanguage: preferedProgrammingLanguage)
    }
    
    /// Schedules background persistence for a full DocC index using the SwiftData store actor.
    ///
    /// - Parameters:
    ///   - index: Decoded index to persist for offline navigation and search.
    ///   - url: Source URL used to locate the persisted `DocCSite`.
    private func persistDocCIndex(_ index: DocCIndex, for url: URL) {
        let store = swiftDataStore
        Task(priority: .utility) {
            do {
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

/// Cache key used to deduplicate in-flight documentation content requests.
private struct DocumentationContentCacheKey: Hashable, Sendable {
    /// Documentation identifier being requested.
    var identifier: String
    /// Root URL of the custom DocC source, or `nil` for Apple-hosted documentation.
    var sourceURL: URL?
    /// Preferred language used for Apple-hosted and variant-aware requests.
    var preferredLanguage: PreferredProgrammingLanguage
}

/// Sendable value snapshot of a persisted DocC source for background index refresh work.
private struct PersistedDocCSourceSnapshot: Sendable {
    /// Stable source identifier copied from the persisted source.
    var id: UUID
    /// Creation timestamp copied from the persisted source.
    var timestamp: Date
    /// Root URL for the DocC source.
    var url: URL
    /// Optional display-name override for the source.
    var overrideName: String?
    /// Last persisted index used to detect whether a fresh remote index should be saved.
    var index: DocCIndex
    
    /// Creates a sendable snapshot from the main-actor persisted source wrapper.
    ///
    /// - Parameter source: Persisted source wrapper reconstructed from SwiftData.
    @MainActor
    init(_ source: PersistedDocCSource) {
        self.id = source.id
        self.timestamp = source.timestamp
        self.url = source.url
        self.overrideName = source.overrideName
        self.index = source.index
    }
}

/// Sendable inserted source metadata returned from the SwiftData store actor.
struct InsertedDocCSource: Sendable {
    /// Stable source identifier created by SwiftData.
    var id: UUID
    /// Creation timestamp persisted with the source.
    var timestamp: Date
    /// Root URL for the DocC source.
    var url: URL
    /// Optional display-name override for the source.
    var overrideName: String?
    
    /// Creates the runtime source snapshot used by the UI model.
    ///
    /// - Parameter index: Runtime index to attach to the source snapshot.
    /// - Returns: A persisted source snapshot for UI and DocCKit use.
    @MainActor
    func persistedSource(index: DocCIndex) -> PersistedDocCSource {
        PersistedDocCSource(
            id: id,
            timestamp: timestamp,
            url: url,
            overrideName: overrideName,
            index: index
        )
    }
}

/// Result of loading a custom DocC source index away from the main actor.
private struct LoadedDocCSource: Sendable {
    /// Original persisted-source snapshot used for identity and metadata.
    var snapshot: PersistedDocCSourceSnapshot
    /// Freshly fetched source index.
    var index: DocCIndex
    /// Whether the fetched index differs from the persisted index.
    var shouldPersistRemoteIndex: Bool
    
    /// Runtime DocCKit source value ready for UI navigation and rendering.
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

/// Sendable framework resolver used by filtering tasks without capturing `DocumentationViewModel`.
struct DocumentationFrameworkResolver: Sendable {
    /// Background content loader shared with the documentation view model.
    fileprivate var contentLoader: DocumentationContentLoader
    /// Preferred language captured from the view model when the resolver is created.
    var preferredLanguage: PreferredProgrammingLanguage
    
    /// Fetches a framework using the captured language and shared content loader.
    ///
    /// - Parameters:
    ///   - identifier: Documentation identifier for the framework.
    ///   - site: Optional custom DocC site used for URL resolution.
    /// - Returns: The decoded framework payload.
    func fetchFramework(for identifier: String, site: DocCSource?) async throws -> Framework {
        try await contentLoader.fetchFramework(for: identifier, site: site, preferredLanguage: preferredLanguage)
    }
}

/// Actor that owns documentation network and decoding work away from the main actor.
actor DocumentationContentLoader {
    /// In-flight framework requests keyed by identifier, source, and preferred language.
    private var frameworkTasks: [DocumentationContentCacheKey : Task<Framework, Error>] = [:]
    /// Completed article payloads keyed by identifier, source, and preferred language.
    private var articles: [DocumentationContentCacheKey : Article] = [:]
    /// In-flight article requests keyed by identifier, source, and preferred language.
    private var articleTasks: [DocumentationContentCacheKey : Task<Article, Error>] = [:]
    /// In-flight custom DocC index requests keyed by source root URL.
    private var indexTasks: [URL : Task<DocCIndex, Error>] = [:]
    
    /// Resolves the final destination URL after redirects.
    ///
    /// - Parameter url: URL to request.
    /// - Returns: Final URL reported by the server response.
    func redirectedURL(for url: URL) async throws -> URL {
        try await DocCClient.redirectedURL(for: url)
    }
    
    /// Fetches the Apple documentation homepage payload.
    ///
    /// - Parameter preferredLanguage: Preferred language used for Apple documentation requests.
    /// - Returns: Decoded homepage payload.
    func fetchHomepage(preferredLanguage: PreferredProgrammingLanguage) async throws -> HomepageParser {
        try await AppleDocsClient(preferredLanguage: preferredLanguage).fetchHomepage()
    }
    
    /// Fetches the Apple documentation technologies payload.
    ///
    /// - Parameter preferredLanguage: Preferred language used for Apple documentation requests.
    /// - Returns: Decoded Apple technologies payload.
    func fetchTechnologies(preferredLanguage: PreferredProgrammingLanguage) async throws -> AppleTechnologies {
        try await AppleDocsClient(preferredLanguage: preferredLanguage).fetchTechnologies()
    }
    
    /// Fetches and deduplicates a custom DocC index request.
    ///
    /// - Parameter baseURL: Root URL of the custom DocC source.
    /// - Returns: Decoded DocC index.
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
    
    /// Fetches and deduplicates a framework payload request.
    ///
    /// - Parameters:
    ///   - identifier: Documentation identifier for the framework.
    ///   - site: Optional custom DocC site used for URL resolution.
    ///   - preferredLanguage: Preferred language used for Apple-hosted and variant-aware requests.
    /// - Returns: Decoded framework payload.
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
    
    /// Fetches and deduplicates an article payload request.
    ///
    /// - Parameters:
    ///   - identifier: Documentation identifier for the article.
    ///   - site: Optional custom DocC site used for URL resolution.
    ///   - preferredLanguage: Preferred language used for variant overrides.
    /// - Returns: Decoded article payload.
    func fetchArticle(
        for identifier: String,
        site: DocCSource?,
        preferredLanguage: PreferredProgrammingLanguage
    ) async throws -> Article {
        let key = DocumentationContentCacheKey(identifier: identifier, sourceURL: site?.url, preferredLanguage: preferredLanguage)
        if let article = articles[key] {
            return article
        }

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
            articles[key] = article
            articleTasks[key] = nil
            return article
        } catch {
            articleTasks[key] = nil
            throw error
        }
    }
}

/// SwiftData model actor used for DocC source persistence that does not need the UI model context.
@ModelActor
actor DocumentationSwiftDataStore {
    /// Inserts a persisted DocC source.
    ///
    /// - Parameters:
    ///   - url: Root URL of the DocC source.
    ///   - overrideName: Optional display-name override.
    ///   - index: Index value to persist with the source.
    /// - Returns: Sendable metadata for the inserted source.
    func insertDocCSite(url: URL, overrideName: String?, index: DocCIndex) throws -> InsertedDocCSource {
        let site = DocCSite(url: url, overrideName: overrideName, index: index)
        modelContext.insert(site)
        try modelContext.save()
        
        return InsertedDocCSource(
            id: site.id,
            timestamp: site.timestamp ?? .init(),
            url: url,
            overrideName: overrideName
        )
    }
    
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
