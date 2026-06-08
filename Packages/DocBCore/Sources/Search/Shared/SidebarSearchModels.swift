import Foundation
import FactoryKit
import Observation
import DocCKit

public struct SidebarSearchResults: Sendable {
    /// Empty result set.
    public static let empty = SidebarSearchResults(sections: [], totalMatches: 0, isTruncated: false)

    /// Grouped result sections.
    public var sections: [SidebarSearchResultSection]
    /// Known matching row count before the search stopped collecting rows.
    public var totalMatches: Int
    /// Whether rows were omitted because the result limit was reached.
    public var isTruncated: Bool

    /// Indicates whether the current result set has no visible rows.
    public var isEmpty: Bool {
        sections.allSatisfy(\.rows.isEmpty)
    }

    /// Creates a grouped sidebar search result set.
    ///
    /// - Parameters:
    ///   - sections: Grouped result sections.
    ///   - totalMatches: Known matching row count before the search stopped collecting rows.
    ///   - isTruncated: Whether rows were omitted because the result limit was reached.
    public init(sections: [SidebarSearchResultSection], totalMatches: Int, isTruncated: Bool) {
        self.sections = sections
        self.totalMatches = totalMatches
        self.isTruncated = isTruncated
    }
}

/// Local, unsynced cache for flattened search indexes.
public actor SidebarSearchIndexCache {
    private static let cacheVersion = 4

    private let fileManager: FileManager
    private let cacheDirectory: URL

    /// Creates a search index cache rooted in the user's Application Support directory.
    ///
    /// - Parameters:
    ///   - fileManager: File manager used for cache reads and writes.
    ///   - applicationSupportDirectory: Optional Application Support override used by tests.
    public init(fileManager: FileManager = .default, applicationSupportDirectory: URL? = nil) {
        self.fileManager = fileManager

        let baseDirectory = applicationSupportDirectory
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        self.cacheDirectory = baseDirectory
            .appendingPathComponent("DocB", isDirectory: true)
            .appendingPathComponent("SearchIndexCache", isDirectory: true)
    }

    /// Loads a cached flattened search index for a source fingerprint.
    ///
    /// - Parameter fingerprint: Source fingerprint associated with the cache entry.
    /// - Returns: Cached index when present and valid.
    public func index(for fingerprint: String) -> SidebarSearchIndex? {
        guard !fingerprint.isEmpty else { return nil }

        do {
            let data = try Data(contentsOf: cacheURL(for: fingerprint))
            let payload = try Payload(data: data)
            guard payload.version == Self.cacheVersion,
                  payload.fingerprint == fingerprint
            else {
                return nil
            }

            return payload.index
        } catch {
            return nil
        }
    }

    /// Returns whether a valid cache file exists for a source fingerprint.
    ///
    /// - Parameter fingerprint: Source fingerprint associated with the cache entry.
    public func containsIndex(for fingerprint: String) -> Bool {
        guard !fingerprint.isEmpty else { return false }

        do {
            let data = try Data(contentsOf: cacheURL(for: fingerprint))
            var reader = SidebarSearchIndex.CacheReader(data: data)
            guard try reader.readString() == "DocBSearchIndexCache" else {
                return false
            }

            let version = Int(try reader.readUInt32())
            let cachedFingerprint = try reader.readString()
            return version == Self.cacheVersion && cachedFingerprint == fingerprint
        } catch {
            return false
        }
    }

    /// Returns whether the search-index cache directory contains any local index payloads.
    public func containsAnyIndexFiles() -> Bool {
        do {
            return try fileManager.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            .contains { $0.pathExtension == "bin" }
        } catch {
            return false
        }
    }

    /// Stores a flattened search index for a source fingerprint.
    ///
    /// - Parameters:
    ///   - index: Flattened search index to cache.
    ///   - fingerprint: Source fingerprint associated with the cache entry.
    public func store(_ index: SidebarSearchIndex, for fingerprint: String) {
        guard !fingerprint.isEmpty else { return }

        do {
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            let url = cacheURL(for: fingerprint)
            let payload = Payload(version: Self.cacheVersion, fingerprint: fingerprint, index: index)
            try payload.data().write(to: url, options: .atomic)
            try removeStaleCacheFiles(keeping: url)
        } catch {
            print(error)
        }
    }

    private func removeStaleCacheFiles(keeping currentCacheURL: URL) throws {
        let cacheFileURLs = try fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        let currentCachePath = currentCacheURL.standardizedFileURL.path

        for cacheFileURL in cacheFileURLs where cacheFileURL.pathExtension == "bin" {
            guard cacheFileURL.standardizedFileURL.path != currentCachePath else { continue }

            try fileManager.removeItem(at: cacheFileURL)
        }
    }

    private func cacheURL(for fingerprint: String) -> URL {
        cacheDirectory.appendingPathComponent("\(Self.cacheKey(for: fingerprint)).bin")
    }

    private static func cacheKey(for fingerprint: String) -> String {
        let hash = fingerprint.utf8.reduce(UInt64(14_695_981_039_346_656_037)) { partialResult, byte in
            (partialResult ^ UInt64(byte)) &* 1_099_511_628_211
        }

        return String(hash, radix: 16)
    }

    private struct Payload {
        let version: Int
        let fingerprint: String
        let index: SidebarSearchIndex

        init(version: Int, fingerprint: String, index: SidebarSearchIndex) {
            self.version = version
            self.fingerprint = fingerprint
            self.index = index
        }

        init(data: Data) throws {
            var reader = SidebarSearchIndex.CacheReader(data: data)
            guard try reader.readString() == "DocBSearchIndexCache" else {
                throw SidebarSearchIndex.CacheError.invalidHeader
            }

            self.version = Int(try reader.readUInt32())
            self.fingerprint = try reader.readString()
            self.index = try SidebarSearchIndex(cacheData: try reader.readData())
        }

        func data() -> Data {
            var writer = SidebarSearchIndex.CacheWriter()
            writer.writeString("DocBSearchIndexCache")
            writer.writeUInt32(UInt32(version))
            writer.writeString(fingerprint)
            writer.writeData(index.cacheData())
            return writer.data
        }
    }
}

/// A section of sidebar search results from one documentation source.
public struct SidebarSearchResultSection: Identifiable, Sendable {
    /// Stable source identifier.
    public let id: String
    /// Section display title.
    public let title: String
    /// Rows in this section.
    public var rows: [SidebarSearchResultRow]

    /// Creates a sidebar search result section.
    ///
    /// - Parameters:
    ///   - id: Stable source identifier.
    ///   - title: Section display title.
    ///   - rows: Rows in this section.
    public init(id: String, title: String, rows: [SidebarSearchResultRow]) {
        self.id = id
        self.title = title
        self.rows = rows
    }
}

/// A flat sidebar search result row.
public enum SidebarSearchResultRow: Identifiable, Sendable, Codable {
    case homepage(id: String, title: String)
    case reference(SidebarSearchReferenceResult)
    case technology(SidebarSearchTechnologyResult)

    /// Stable row identifier.
    public var id: String {
        switch self {
        case .homepage(let id, _):
            id
        case .reference(let result):
            result.id
        case .technology(let result):
            result.id
        }
    }

    /// Display title.
    public var title: String {
        switch self {
        case .homepage(_, let title):
            title
        case .reference(let result):
            result.title
        case .technology(let result):
            result.title
        }
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case id
        case title
        case reference
        case technology
    }

    private enum Kind: String, Codable {
        case homepage
        case reference
        case technology
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        switch kind {
        case .homepage:
            self = .homepage(
                id: try container.decode(String.self, forKey: .id),
                title: try container.decode(String.self, forKey: .title)
            )
        case .reference:
            self = .reference(try container.decode(SidebarSearchReferenceResult.self, forKey: .reference))
        case .technology:
            self = .technology(try container.decode(SidebarSearchTechnologyResult.self, forKey: .technology))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .homepage(let id, let title):
            try container.encode(Kind.homepage, forKey: .kind)
            try container.encode(id, forKey: .id)
            try container.encode(title, forKey: .title)
        case .reference(let result):
            try container.encode(Kind.reference, forKey: .kind)
            try container.encode(result, forKey: .reference)
        case .technology(let result):
            try container.encode(Kind.technology, forKey: .kind)
            try container.encode(result, forKey: .technology)
        }
    }
}

/// DocC reference result payload.
public struct SidebarSearchReferenceResult: Identifiable, Sendable, Codable {
    /// Stable row identifier.
    public let id: String
    /// Display title.
    public let title: String
    /// Relative DocC path.
    public let path: String
    /// Node type metadata.
    public let type: String
    /// Best-effort Xcode documentation symbol badge kind.
    public let symbolKind: SidebarSearchSymbolKind
    /// Optional custom icon identifier from a custom DocC index node.
    public let customIconIdentifier: String?
    /// Owning custom DocC source, or `nil` for Apple-hosted documentation.
    public let site: DocCSource?

    /// Creates a DocC reference search result.
    ///
    /// - Parameters:
    ///   - id: Stable row identifier.
    ///   - title: Display title.
    ///   - path: Relative DocC path.
    ///   - type: Node type metadata.
    ///   - symbolKind: Best-effort Xcode documentation symbol badge kind.
    ///   - customIconIdentifier: Optional custom icon identifier from a custom DocC index node.
    ///   - site: Owning custom DocC source, or `nil` for Apple-hosted documentation.
    public init(
        id: String,
        title: String,
        path: String,
        type: String,
        symbolKind: SidebarSearchSymbolKind? = nil,
        customIconIdentifier: String? = nil,
        site: DocCSource?
    ) {
        self.id = id
        self.title = title
        self.path = path
        self.type = type
        self.symbolKind = symbolKind ?? SidebarSearchSymbolKind(title: title, path: path, type: type)
        self.customIconIdentifier = customIconIdentifier
        self.site = site
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case path
        case type
        case symbolKind
        case customIconIdentifier
        case site
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.path = try container.decode(String.self, forKey: .path)
        self.type = try container.decode(String.self, forKey: .type)
        self.symbolKind = try container.decode(SidebarSearchSymbolKind.self, forKey: .symbolKind)
        self.customIconIdentifier = try container.decodeIfPresent(String.self, forKey: .customIconIdentifier)
        self.site = try container.decodeIfPresent(CachedDocCSource.self, forKey: .site)?.docCSource
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(path, forKey: .path)
        try container.encode(type, forKey: .type)
        try container.encode(symbolKind, forKey: .symbolKind)
        try container.encodeIfPresent(customIconIdentifier, forKey: .customIconIdentifier)
        try container.encodeIfPresent(site.map(CachedDocCSource.init(site:)), forKey: .site)
    }

    /// Creates a navigation reference for the active deep-link scheme.
    ///
    /// - Parameter deepLinkScheme: Scheme used by the app for DocC navigation.
    /// - Returns: A reference suitable for `ReferenceNavigationLinkButton`.
    public func reference(deepLinkScheme: DocCDeepLinkScheme) -> Reference {
        let identifier: String
        if site == nil {
            identifier = "\(deepLinkScheme.urlPrefix)com.apple.documentation\(path)"
        } else {
            identifier = "\(deepLinkScheme.urlPrefix)nav\(path)"
        }

        return Reference(
            title: title,
            identifier: identifier,
            type: type,
            docCSite: site
        )
    }
}

/// Lightweight DocC source context stored in flattened search caches.
private struct CachedDocCSource: Codable {
    /// Stable source identifier.
    let id: UUID
    /// Source insertion date.
    let timestamp: Date
    /// Root source URL.
    let url: URL
    /// Optional display override.
    let overrideName: String?
    /// Source index identity.
    let indexID: UUID
    /// Archive identifiers used by custom icons.
    let includedArchiveIdentifiers: [String]?

    /// Creates a lightweight source cache from a full DocC source.
    ///
    /// - Parameter site: Source to cache.
    init(site: DocCSource) {
        self.id = site.id
        self.timestamp = site.timestamp
        self.url = site.url
        self.overrideName = site.overrideName
        self.indexID = site.index.id
        self.includedArchiveIdentifiers = site.index.includedArchiveIdentifiers
    }

    /// Recreates a source with only the context needed for search-result navigation.
    var docCSource: DocCSource {
        DocCSource(
            id: id,
            timestamp: timestamp,
            url: url,
            overrideName: overrideName,
            index: DocCIndex(
                id: indexID,
                interfaceLanguages: [:],
                includedArchiveIdentifiers: includedArchiveIdentifiers
            )
        )
    }
}

/// Apple framework result payload.
public struct SidebarSearchTechnologyResult: Identifiable, Sendable, Codable {
    /// Stable row identifier.
    public let id: String
    /// Display title.
    public let title: String
    /// Framework navigation payload.
    public let framework: AppleTechnologies.FrameworkSection
    /// Optional reference metadata for beta/deprecation badges.
    public let badgeReference: Reference?

    /// Creates an Apple framework search result.
    ///
    /// - Parameters:
    ///   - id: Stable row identifier.
    ///   - title: Display title.
    ///   - framework: Framework navigation payload.
    ///   - badgeReference: Optional reference metadata for beta/deprecation badges.
    public init(id: String, title: String, framework: AppleTechnologies.FrameworkSection, badgeReference: Reference?) {
        self.id = id
        self.title = title
        self.framework = framework
        self.badgeReference = badgeReference
    }
}

/// Main-actor owner for sidebar search index snapshots and cancellable query tasks.
@MainActor
@Observable
public final class SidebarSearchStore {
    @ObservationIgnored @Injected(\.sidebarSearchIndexCache) private var searchIndexCache

    /// Latest raw search text received from the sidebar field.
    public private(set) var rawSearchText = ""
    /// Current visible search results.
    public private(set) var results = SidebarSearchResults.empty
    /// Whether a query task is waiting or computing.
    public private(set) var isSearching = false
    /// Whether a fresh index snapshot is being built.
    public private(set) var isRebuildingIndex = false
    /// Progress for the active index build, or `nil` when no build is running.
    public private(set) var indexBuildProgress: Double?
    /// Number of installed index snapshots, used by tests to guard against query-time rebuilds.
    public private(set) var indexBuildCount = 0
    /// Whether a non-empty search index is currently installed.
    public var hasInstalledIndex: Bool {
        indexBuildCount > 0 && index.entryCount > 0
    }

    /// User-facing title for the current index-build phase.
    public var indexBuildTitle: String {
        if isRebuildingIndex && indexBuildProgress == nil {
            return hasInstalledIndex ? "Updating Index" : "Loading Index"
        }

        return hasInstalledIndex ? "Updating Index" : "Indexing"
    }

    /// Current flattened index.
    private var index = SidebarSearchIndex.empty
    /// Current query task.
    private var searchTask: Task<Void, Never>?
    /// Current index build task.
    private var indexBuildTask: Task<Void, Never>?
    /// Token used to reject stale query publications.
    private var searchRequestID = UUID()
    /// Token used to reject stale index publications.
    private var indexBuildRequestID = UUID()

    /// Creates an empty sidebar search store.
    public init() {}

    /// Rebuilds the flattened index from captured source snapshots.
    ///
    /// - Parameters:
    ///   - technologies: Runtime technology snapshots.
    ///   - searchText: Current query to re-run when the index is installed.
    ///   - sourceFingerprint: Stable source fingerprint used to restore and save the local search cache.
    public func rebuildIndex(
        technologies: [TechnologyTypes],
        searchText: String,
        sourceFingerprint: String? = nil
    ) {
        rawSearchText = searchText
        indexBuildTask?.cancel()
        let requestID = UUID()
        indexBuildRequestID = requestID
        isRebuildingIndex = sourceFingerprint != nil
        indexBuildProgress = nil
        let searchIndexCache = searchIndexCache
        let preservesExistingResults = hasInstalledIndex

        indexBuildTask = Task(priority: .utility) {
            if let sourceFingerprint,
               let cachedIndex = await searchIndexCache.index(for: sourceFingerprint) {
                await MainActor.run {
                    guard self.indexBuildRequestID == requestID else { return }

                    self.installIndex(cachedIndex, preserveExistingResults: preservesExistingResults)
                }
                return
            }

            await MainActor.run {
                guard self.indexBuildRequestID == requestID else { return }

                self.isRebuildingIndex = true
                self.indexBuildProgress = 0
            }

            let progress: @Sendable (Double) -> Void = { value in
                Task { @MainActor in
                    guard self.indexBuildRequestID == requestID else { return }

                    self.indexBuildProgress = min(max(value, 0), 1)
                }
            }

            let index = await Task.detached(priority: .utility) {
                SidebarSearchIndex(technologies: technologies, progress: progress)
            }.value

            await MainActor.run {
                guard self.indexBuildRequestID == requestID else { return }

                if let sourceFingerprint {
                    Task.detached(priority: .utility) {
                        await searchIndexCache.store(index, for: sourceFingerprint)
                    }
                }
                self.indexBuildTask = nil
                self.installIndex(index, preserveExistingResults: preservesExistingResults)
            }
        }
    }

    /// Installs an already-built index.
    ///
    /// - Parameters:
    ///   - index: Search index snapshot to publish.
    ///   - searchDebounce: Delay before re-running the current query against the installed index.
    ///   - preserveExistingResults: Whether visible rows should remain while the current query reruns.
    public func installIndex(
        _ index: SidebarSearchIndex,
        searchDebounce: Duration = .milliseconds(120),
        preserveExistingResults: Bool = false
    ) {
        searchTask?.cancel()
        indexBuildTask?.cancel()
        searchRequestID = UUID()
        indexBuildRequestID = UUID()
        self.index = index
        isRebuildingIndex = false
        indexBuildProgress = nil
        indexBuildCount += 1
        updateSearchText(rawSearchText, debounce: searchDebounce, preserveExistingResults: preserveExistingResults)
    }

    /// Releases the installed flattened index and any visible results.
    public func releaseIndex() {
        searchTask?.cancel()
        indexBuildTask?.cancel()
        searchRequestID = UUID()
        indexBuildRequestID = UUID()
        index = .empty
        results = .empty
        isSearching = false
        isRebuildingIndex = false
        indexBuildProgress = nil
    }

    /// Updates the active query and schedules a cancellable search.
    ///
    /// - Parameters:
    ///   - searchText: Raw sidebar search text.
    ///   - debounce: Delay before non-empty queries are evaluated.
    ///   - preserveExistingResults: Whether visible rows should remain while the search is running.
    public func updateSearchText(
        _ searchText: String,
        debounce: Duration = .milliseconds(120),
        preserveExistingResults: Bool = false
    ) {
        rawSearchText = searchText
        searchTask?.cancel()
        searchRequestID = UUID()

        let normalizedQuery = SidebarSearchIndex.normalize(searchText)
        guard !normalizedQuery.isEmpty else {
            results = .empty
            isSearching = false
            return
        }

        let requestID = searchRequestID
        let index = index
        isSearching = true
        if !preserveExistingResults {
            results = .empty
        }

        searchTask = Task(priority: .userInitiated) {
            do {
                try await Task.sleep(for: debounce)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }

            let results = await Task.detached(priority: .userInitiated) {
                index.search(normalizedQuery)
            }.value

            await MainActor.run {
                guard self.searchRequestID == requestID,
                      self.index.id == index.id,
                      SidebarSearchIndex.normalize(self.rawSearchText) == normalizedQuery
                else {
                    return
                }

                self.results = results
                self.isSearching = false
            }
        }
    }
}
