import Foundation
import SwiftData
import DocCKit

extension DocCIndex {
    /// Empty index that preserves only this index's stable identity.
    var identityIndex: DocCIndex {
        DocCIndex(
            id: id,
            interfaceLanguages: [:],
            includedArchiveIdentifiers: includedArchiveIdentifiers
        )
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
struct DocumentationContentCacheKey: Hashable, Sendable {
    /// Documentation identifier being requested.
    var identifier: String
    /// Root URL of the custom DocC source, or `nil` for Apple-hosted documentation.
    var sourceURL: URL?
    /// Preferred language used for Apple-hosted and variant-aware requests.
    var preferredLanguage: PreferredProgrammingLanguage
}

/// Sendable value snapshot of a persisted DocC source for background index refresh work.
struct PersistedDocCSourceSnapshot: Sendable {
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

    /// Creates a sendable snapshot from lightweight persisted site metadata.
    ///
    /// - Parameter snapshot: Persisted source metadata that does not include decoded index content.
    init?(_ snapshot: DocCSiteSnapshot) {
        guard let timestamp = snapshot.timestamp, let url = snapshot.url else {
            return nil
        }

        self.id = snapshot.id
        self.timestamp = timestamp
        self.url = url
        self.overrideName = snapshot.overrideName
        self.index = DocCIndex(interfaceLanguages: [:])
    }

    /// Lightweight persisted source value with an empty index for identity and URL matching.
    @MainActor
    var persistedSource: PersistedDocCSource {
        persistedSource(index: index)
    }

    /// Runtime persisted source value ready to attach to the UI model.
    ///
    /// - Parameter index: Index payload to attach to the source.
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

/// Result of loading a persisted DocC index from SwiftData.
struct LoadedPersistedDocCIndex: Sendable {
    /// Stable source identifier copied from SwiftData.
    var id: UUID
    /// Creation timestamp copied from SwiftData.
    var timestamp: Date
    /// Root URL for the DocC source.
    var url: URL
    /// Optional display-name override.
    var overrideName: String?
    /// Reconstructed DocC index.
    var index: DocCIndex

    /// Runtime persisted source value ready to attach to the UI model.
    @MainActor
    var persistedSource: PersistedDocCSource {
        persistedSource(index: index)
    }

    /// Runtime persisted source value ready to attach to the UI model.
    ///
    /// - Parameter index: Index payload to attach to the source.
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
struct LoadedDocCSource: Sendable {
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
    var contentLoader: DocumentationContentLoader
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

    /// Fetches the Apple Developer Documentation index.
    ///
    /// - Parameter technologies: Apple technologies payload used to discover framework index URLs.
    /// - Returns: Decoded DocC index.
    func fetchAppleIndex(technologies: AppleTechnologies) async throws -> DocCIndex {
        let url = URL(string: "\(DocCConstants.aDeveloperURLBase)/tutorials/data/index/apple-technologies.json")!
        if let task = indexTasks[url] {
            return try await task.value
        }

        let task = Task {
            try await AppleDocsClient().fetchIndex(for: technologies)
        }
        indexTasks[url] = task

        do {
            let index = try await task.value
            indexTasks[url] = nil
            return index
        } catch {
            indexTasks[url] = nil
            throw error
        }
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

    /// Refreshes custom DocC source indexes on the content actor.
    ///
    /// - Parameter snapshots: Persisted source metadata to refresh.
    /// - Returns: Refreshed source indexes sorted by their original timestamp.
    func refreshDocCSources(_ snapshots: [PersistedDocCSourceSnapshot]) async -> [LoadedDocCSource] {
        await DocumentationViewModel.loadDocCSources(snapshots, using: self)
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

    /// Clears article payloads retained for search preloading.
    func clearArticleCache() {
        for task in articleTasks.values {
            task.cancel()
        }
        articleTasks.removeAll()
        articles.removeAll()
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
        
        site.indexData = DocCSite.encodeIndex(index)
        site.indexV2 = nil
        try modelContext.save()
    }

    /// Reconstructs a persisted custom DocC index on the model actor.
    ///
    /// - Parameter preferredURL: Source URL used to find the persisted source record.
    /// - Returns: The persisted source and index when one exists.
    func fetchDocCIndex(preferredURL: URL) throws -> LoadedPersistedDocCIndex? {
        let descriptor = FetchDescriptor<DocCSite>(
            predicate: #Predicate { site in
                site.url == preferredURL
            }
        )

        guard let site = try modelContext.fetch(descriptor).first else {
            return nil
        }

        return loadedPersistedIndex(from: site)
    }

    /// Reconstructs persisted custom DocC indexes in one SwiftData fetch.
    ///
    /// - Parameter preferredURLs: Source URLs to restore from local persistence.
    /// - Returns: Persisted sources and indexes matching the requested URLs.
    func fetchDocCIndexes(preferredURLs: [URL]) throws -> [LoadedPersistedDocCIndex] {
        guard !preferredURLs.isEmpty else {
            return []
        }

        let preferredURLSet = Set(preferredURLs)
        let sites = try modelContext.fetch(FetchDescriptor<DocCSite>())
        var loadedIndexes: [LoadedPersistedDocCIndex] = []
        loadedIndexes.reserveCapacity(preferredURLSet.count)

        for site in sites {
            guard let url = site.url, preferredURLSet.contains(url),
                  let loadedIndex = loadedPersistedIndex(from: site)
            else {
                continue
            }

            loadedIndexes.append(loadedIndex)
        }

        return loadedIndexes
    }

    /// Reconstructs a persisted Apple DocC index on the model actor instead of the main actor.
    ///
    /// - Parameter preferredURL: Preferred source URL to try before falling back to any Apple source.
    /// - Returns: The persisted Apple source and index when one exists.
    func fetchAppleDocCIndex(preferredURL: URL) throws -> LoadedPersistedDocCIndex? {
        let descriptor = FetchDescriptor<DocCSite>(
            predicate: #Predicate { site in
                site.url == preferredURL
            }
        )

        if let preferredSite = try modelContext.fetch(descriptor).first,
           let loadedIndex = loadedPersistedIndex(from: preferredSite) {
            return loadedIndex
        }

        let allSites = try modelContext.fetch(FetchDescriptor<DocCSite>())
        for site in allSites {
            guard site.url?.absoluteString.lowercased().contains("developer.apple.com") == true else {
                continue
            }

            if let loadedIndex = loadedPersistedIndex(from: site) {
                return loadedIndex
            }
        }

        return nil
    }

    /// Reconstructs a persisted source/index pair from a SwiftData model if its required fields are valid.
    ///
    /// - Parameter site: Persisted site model to read.
    /// - Returns: Sendable source/index data when the persisted model is complete.
    private func loadedPersistedIndex(from site: DocCSite) -> LoadedPersistedDocCIndex? {
        guard let timestamp = site.timestamp, let url = site.url else {
            return nil
        }

        guard let index = site.decodedIndex ?? site.indexV2?.asIndex else {
            return nil
        }

        return LoadedPersistedDocCIndex(
            id: site.id,
            timestamp: timestamp,
            url: url,
            overrideName: site.overrideName,
            index: index
        )
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
