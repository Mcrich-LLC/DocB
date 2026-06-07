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
    @ObservationIgnored @MainActor private var hasStartedAppleIndexRefresh = false
    @ObservationIgnored @MainActor private var hasStartedAppleMetadataRefresh = false
    @ObservationIgnored @MainActor private var hasCompletedInitialTechnologyLoad = false
    
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
    /// Whether persisted documentation sources are still being restored for the initial app load.
    @MainActor
    public private(set) var isPreparingSearchSources = true

    /// Cache of framework payloads keyed by their documentation identifier.
    @MainActor
    public private(set) var frameworks: [String : Framework] = [:]
    
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
}

extension DocumentationViewModel {
    /// Returns a technology snapshot suitable for rebuilding search when no flattened cache exists.
    ///
    /// This keeps the large Apple symbol index out of launch and normal UI state, loading it only for a search rebuild.
    @MainActor
    public func searchTechnologySnapshot() async -> [TechnologyTypes] {
        guard let appleURL = appleDocCSiteRef?.url,
              let appleTechnologyIndex = technologies.firstIndex(where: { $0.isApple }),
              case .apple(let appleTechnologies) = technologies[appleTechnologyIndex],
              appleTechnologies.index?.isSearchIndexEmpty != false
        else {
            return technologies
        }

        do {
            guard let persistedSource = try await swiftDataStore.fetchAppleDocCIndex(preferredURL: appleURL),
                  !persistedSource.index.isSearchIndexEmpty
            else {
                return technologies
            }

            appleDocCSiteRef = persistedSource.persistedSource(index: persistedSource.index.identityIndex)
            var snapshot = technologies
            snapshot[appleTechnologyIndex] = .apple(appleTechnologies.withIndex(persistedSource.index))
            return snapshot
        } catch {
            print(error)
            return technologies
        }
    }

    /// Cheap fingerprint for rebuilding search indexes when source content changes.
    @MainActor
    public var searchContentFingerprint: String {
        technologies.map { technology in
            switch technology {
            case .apple(let appleTechnologies):
                let sourceID = appleDocCSiteRef?.id.uuidString
                    ?? appleDocCSiteRef?.url.absoluteString
                    ?? "apple"
                let groupFingerprint = appleTechnologies.groups?.map { group in
                    let frameworkIdentifiers = group.technologies
                        .map(\.destination.identifier)
                        .joined(separator: ",")
                    return "\(group.name):\(frameworkIdentifiers)"
                }
                .joined(separator: ";") ?? "missing"
                let indexFingerprint = [
                    appleTechnologies.index,
                    appleDocCSiteRef?.index
                ]
                .compactMap { index -> String? in
                    guard let index, !index.isSearchIndexEmpty else {
                        return nil
                    }

                    return index.id.uuidString
                }
                .first ?? "missing"
                return "apple:\(sourceID):\(indexFingerprint):\(groupFingerprint)"
            case .docC(let source):
                return "docc:\(source.id.uuidString):\(source.index.id.uuidString)"
            }
        }
        .joined(separator: "|")
    }
}

extension DocumentationViewModel {
    
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
            guard !technologies.contains(where: { $0.isApple }) else {
                return
            }

            let preferredLanguage = preferedProgrammingLanguage
            let loader = contentLoader
            async let homepage = loader.fetchHomepage(preferredLanguage: preferredLanguage)
            let appleTechnologies = try await loader.fetchTechnologies(preferredLanguage: preferredLanguage)
            let insertedSource = try await swiftDataStore.insertDocCSite(
                url: baseUrl,
                overrideName: nil,
                index: .init(interfaceLanguages: [:])
            )
            appleDocCSiteRef = insertedSource.persistedSource(index: .init(interfaceLanguages: [:]))
            self.homepage = try? await homepage
            publishAppleTechnologies(appleTechnologies)
            refreshAppleIndexIfNeeded(using: appleTechnologies, force: true)
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
    
    /// Loads all persisted technology sites from lightweight metadata and refreshes the in-memory technology list.
    ///
    /// - Parameter siteSnapshots: Persisted DocC site metadata that does not require decoding local indexes on the main actor.
    @MainActor
    public func loadTechnologies(_ siteSnapshots: [DocCSiteSnapshot]) async {
        let isInitialTechnologyLoad = !hasCompletedInitialTechnologyLoad
        if isInitialTechnologyLoad {
            isPreparingSearchSources = true
        }

        defer {
            if isInitialTechnologyLoad {
                hasCompletedInitialTechnologyLoad = true
                isPreparingSearchSources = false
            }
        }

        let preferredLanguage = preferedProgrammingLanguage
        var customSnapshots: [PersistedDocCSourceSnapshot] = []
        var shouldLoadAppleDocumentation = false
        
        for siteSnapshot in siteSnapshots {
            guard let snapshot = PersistedDocCSourceSnapshot(siteSnapshot) else {
                continue
            }

            guard !snapshot.url.absoluteString.contains("developer.apple.com") else {
                guard !technologies.contains(where: { $0.isApple }) else {
                    continue
                }
                appleDocCSiteRef = snapshot.persistedSource
                shouldLoadAppleDocumentation = true
                continue
            }
            
            guard !containsDocCSite(with: snapshot.url) else {
                continue
            }
            
            customSnapshots.append(snapshot)
        }
        
        if shouldLoadAppleDocumentation {
            publishOfflineAppleDocumentationIfNeeded()
            await loadPersistedAppleIndexOrRefresh(preferredLanguage: preferredLanguage)
        }
        
        let loadedSources = await Self.loadPersistedDocCSources(customSnapshots, using: swiftDataStore)
        for loadedSource in loadedSources {
            technologies.appendOrUpdate(.docC(loadedSource.docCSource))
        }

        refreshPersistedDocCSources(customSnapshots)
    }

    /// Loads all persisted technology sites and refreshes the in-memory technology list.
    ///
    /// - Parameter sites: Persisted DocC source snapshots.
    @MainActor
    public func loadTechnologies(_ sites: [PersistedDocCSource]) async {
        await loadTechnologies(sites.map(DocCSiteSnapshot.init(source:)))
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
    
    /// Clears completed and in-flight article payloads retained by background search preloading.
    @MainActor
    public func clearArticleCache() {
        Task {
            await contentLoader.clearArticleCache()
        }
    }
}

extension DocumentationViewModel {

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

    /// Publishes a lightweight Apple entry backed by the persisted offline search index.
    @MainActor
    private func publishOfflineAppleDocumentationIfNeeded() {
        guard !technologies.contains(where: { $0.isApple }) else {
            return
        }

        publishAppleTechnologies(AppleTechnologies())
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
    
    /// Loads the persisted Apple search index first, then refreshes Apple metadata in the background.
    ///
    /// - Parameter preferredLanguage: Language to use for Apple documentation requests.
    @MainActor
    private func loadPersistedAppleIndexOrRefresh(preferredLanguage: PreferredProgrammingLanguage) async {
        guard !hasStartedAppleMetadataRefresh else {
            return
        }

        guard appleDocCSiteRef != nil else {
            return
        }

        hasStartedAppleMetadataRefresh = true
        let loader = contentLoader

        Task(priority: .background) {
            do {
                async let homepage = loader.fetchHomepage(preferredLanguage: preferredLanguage)
                let loadedTechnologies = try await loader.fetchTechnologies(preferredLanguage: preferredLanguage)
                let loadedHomepage = try? await homepage

                await MainActor.run {
                    if let loadedHomepage {
                        self.homepage = loadedHomepage
                    }
                    self.publishAppleTechnologies(loadedTechnologies)
                    self.refreshAppleIndexIfNeeded(using: loadedTechnologies)
                }
            } catch {
                print(error)
            }
        }
    }

    /// Starts the large Apple framework index refresh once per launch when offline search data is missing.
    ///
    /// - Parameters:
    ///   - appleTechnologies: Apple technologies payload used to discover framework indexes.
    ///   - force: Whether to refresh even when the persisted Apple index already has entries.
    @MainActor
    private func refreshAppleIndexIfNeeded(using appleTechnologies: AppleTechnologies, force: Bool = false) {
        guard !hasStartedAppleIndexRefresh else {
            return
        }

        guard force || appleDocCSiteRef?.index.isSearchIndexEmpty != false else {
            return
        }

        hasStartedAppleIndexRefresh = true
        let loader = contentLoader
        Task(priority: .utility) {
            do {
                let loadedAppleIndex = try await loader.fetchAppleIndex(technologies: appleTechnologies)
                await MainActor.run {
                    guard !loadedAppleIndex.isSearchIndexEmpty else {
                        return
                    }

                    self.appleDocCSiteRef?.setIndex(loadedAppleIndex)
                    let appleURL = self.appleDocCSiteRef?.url ?? URL(string: "\(DocCConstants.aDeveloperURLBase)/documentation")!
                    self.persistDocCIndex(loadedAppleIndex, for: appleURL)
                    self.publishAppleTechnologies(appleTechnologies.withIndex(loadedAppleIndex))
                }
            } catch {
                print(error)
            }
        }
    }

    /// Attaches an Apple search index to the existing Apple technology entry without replacing sidebar metadata.
    ///
    /// - Parameter index: Persisted Apple DocC search index.
    @MainActor
    private func publishAppleIndex(_ index: DocCIndex) {
        guard let technologyIndex = technologies.firstIndex(where: { $0.isApple }),
              case .apple(let appleTechnologies) = technologies[technologyIndex]
        else {
            publishAppleTechnologies(AppleTechnologies(index: index))
            return
        }

        technologies[technologyIndex] = .apple(appleTechnologies.withIndex(index))
    }
    
    /// Loads fresh custom DocC source indexes concurrently from sendable persisted-source snapshots.
    ///
    /// - Parameters:
    ///   - snapshots: Value snapshots derived from persisted sources on the main actor.
    ///   - loader: Background content actor used to fetch source indexes.
    /// - Returns: Loaded source values sorted by their original timestamp.
    static func loadDocCSources(_ snapshots: [PersistedDocCSourceSnapshot], using loader: DocumentationContentLoader) async -> [LoadedDocCSource] {
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

    /// Loads persisted custom DocC source indexes without refreshing them from the network.
    ///
    /// - Parameters:
    ///   - snapshots: Lightweight source metadata collected on the main actor.
    ///   - store: SwiftData store actor used to decode persisted indexes off the main actor.
    /// - Returns: Persisted source values sorted by their original timestamp.
    private static func loadPersistedDocCSources(
        _ snapshots: [PersistedDocCSourceSnapshot],
        using store: DocumentationSwiftDataStore
    ) async -> [LoadedDocCSource] {
        do {
            let persistedSources = try await store.fetchDocCIndexes(preferredURLs: snapshots.map(\.url))
            let persistedSourceByURL = persistedSources.reduce(into: [URL: LoadedPersistedDocCIndex]()) { result, source in
                result[source.url, default: source] = source
            }

            return snapshots.compactMap { snapshot in
                guard let persistedSource = persistedSourceByURL[snapshot.url] else {
                    return nil
                }

                return LoadedDocCSource(
                    snapshot: snapshot,
                    index: persistedSource.index,
                    shouldPersistRemoteIndex: false
                )
            }
            .sorted { lhs, rhs in
                lhs.snapshot.timestamp < rhs.snapshot.timestamp
            }
        } catch {
            print(error)
            return []
        }
    }

    /// Refreshes persisted custom DocC indexes from their source URLs after the local snapshot is restored.
    ///
    /// - Parameter snapshots: Source metadata to refresh from the network.
    @MainActor
    private func refreshPersistedDocCSources(_ snapshots: [PersistedDocCSourceSnapshot]) {
        guard !snapshots.isEmpty else {
            return
        }

        let loader = contentLoader
        Task(priority: .utility) {
            let refreshedSources = await loader.refreshDocCSources(snapshots)
            publishRefreshedDocCSources(refreshedSources)
        }
    }

    /// Publishes refreshed custom DocC source indexes after background refresh work completes.
    ///
    /// - Parameter refreshedSources: Fresh source indexes loaded by the content actor.
    @MainActor
    private func publishRefreshedDocCSources(_ refreshedSources: [LoadedDocCSource]) {
        for refreshedSource in refreshedSources {
            technologies.appendOrUpdate(.docC(refreshedSource.docCSource))
            if refreshedSource.shouldPersistRemoteIndex {
                persistDocCIndex(refreshedSource.index, for: refreshedSource.snapshot.url)
            }
        }
    }
}

extension DocumentationViewModel {
    
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
