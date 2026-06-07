import Foundation
import FactoryKit
import Observation
import DocCKit
import Synchronization

/// Flattened sidebar search index used to keep keystroke matching off the main actor.
public struct SidebarSearchIndex: Sendable, Codable {
    /// Maximum number of rows published for a single sidebar query.
    public static let defaultResultLimit = 250
    /// Minimum query length before scanning the streamed Apple symbol index.
    private static let minimumStreamingAppleQueryLength = 3

    /// Empty index used before documentation sources are loaded.
    public static let empty = SidebarSearchIndex(id: UUID(), entries: [])

    /// Stable identity for this index snapshot.
    public let id: UUID

    /// Number of searchable entries in this snapshot.
    public var entryCount: Int {
        entries.count
    }

    /// Flattened, pre-normalized entries.
    let entries: [Entry]
    /// Apple DocC indexes searched on demand without flattening every symbol into memory.
    let streamingAppleIndexes: [StreamingAppleIndex]
    /// Bounded in-memory cache of streamed Apple query results.
    let streamingAppleQueryCache: StreamingAppleQueryCache
    /// Entry indexes grouped by searchable ASCII byte for faster substring candidates.
    let entryIndexesByASCIIByte: [[Int]]

    private enum CodingKeys: String, CodingKey {
        case id
        case entries
    }

    /// Creates a sidebar search index from loaded technology snapshots.
    ///
    /// - Parameters:
    ///   - technologies: Runtime technology sources from `DocumentationViewModel`.
    ///   - progress: Optional build-progress callback reported from `0...1`.
    public init(technologies: [TechnologyTypes], progress: (@Sendable (Double) -> Void)? = nil) {
        let docCSites = technologies.docCSites.sorted { lhs, rhs in
            lhs.timestamp < rhs.timestamp
        }
        var entries: [Entry] = []
        var streamingAppleIndexes: [StreamingAppleIndex] = []
        var completedEntries = 0
        let estimatedEntryCount = max(Self.estimatedEntryCount(in: docCSites, appleTechnologies: technologies.appleTechnologies), 1)

        func reportEntryProgress() {
            completedEntries += 1
            guard completedEntries == estimatedEntryCount || completedEntries.isMultiple(of: 512) else { return }

            progress?(0.6 * min(Double(completedEntries) / Double(estimatedEntryCount), 1))
        }

        progress?(0)

        for site in docCSites {
            let source = Source(
                id: "docc-\(site.id.uuidString)",
                title: site.overrideName ?? site.groups.first?.title ?? "Unknown"
            )
            Self.appendDocCEntries(from: site, source: source, to: &entries, onAppendEntry: reportEntryProgress)
        }

        for appleTechnologies in technologies.appleTechnologies {
            let source = Source(id: "apple-\(appleTechnologies.id.uuidString)", title: "Apple Documentation")
            entries.append(.init(
                id: "\(source.id)-homepage",
                source: source,
                title: "Discover",
                normalizedTitle: Self.normalize("Discover"),
                normalizedTags: [],
                kindRank: 1,
                row: .homepage(id: "\(source.id)-homepage", title: "Discover")
            ))
            reportEntryProgress()

            for group in appleTechnologies.groups ?? [] {
                for framework in group.technologies where framework.destination.isActive {
                    entries.append(.init(
                        id: "\(source.id)-\(framework.destination.identifier)",
                        source: source,
                        title: framework.title,
                        normalizedTitle: Self.normalize(framework.title),
                        normalizedTags: framework.tags.map(Self.normalize),
                        kindRank: 0,
                        row: .technology(.init(
                            id: "\(source.id)-\(framework.destination.identifier)",
                            title: framework.title,
                            framework: framework,
                            badgeReference: appleTechnologies.references[framework.destination.identifier]
                        ))
                    ))
                    reportEntryProgress()
                }
            }

            if let index = appleTechnologies.index {
                streamingAppleIndexes.append(StreamingAppleIndex(source: source, index: index))
            }
        }

        self.init(id: UUID(), entries: entries, streamingAppleIndexes: streamingAppleIndexes, progress: progress)
        progress?(1)
    }

    /// Normalizes user-facing search strings to match the existing case-insensitive semantics.
    ///
    /// - Parameter value: Raw search text or title text.
    /// - Returns: A trimmed, lowercased string.
    public static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Searches the flattened index.
    ///
    /// - Parameters:
    ///   - query: Raw or normalized query text.
    ///   - limit: Maximum number of rows to return.
    /// - Returns: Grouped search results capped to `limit`.
    public func search(_ query: String, limit: Int = defaultResultLimit) -> SidebarSearchResults {
        let normalizedQuery = Self.normalize(query)
        guard !normalizedQuery.isEmpty else { return .empty }

        var matches: [Entry] = []
        let resultLimit = max(0, limit)
        let collectionLimit = resultLimit + 1

        var scoreBuckets = Array(repeating: [Entry](), count: SearchScore.bucketCount)
        var totalMatches = 0

        func appendMatch(_ entry: Entry) {
            guard let score = entry.matchScore(for: normalizedQuery) else {
                return
            }

            totalMatches += 1
            let bucketIndex = score.bucketIndex
            if scoreBuckets[bucketIndex].count < collectionLimit {
                scoreBuckets[bucketIndex].append(entry)
            }
        }

        for entryIndex in candidateEntryIndexes(for: normalizedQuery) {
            appendMatch(entries[entryIndex])
        }

        appendStreamingAppleMatches(
            normalizedQuery: normalizedQuery,
            collectionLimit: collectionLimit,
            scoreBuckets: &scoreBuckets,
            totalMatches: &totalMatches
        )

        for bucket in scoreBuckets {
            guard matches.count < collectionLimit else { break }

            for entry in bucket {
                matches.append(entry)
                guard matches.count < collectionLimit else { break }
            }
        }

        let visibleMatches = resultLimit == 0 ? [] : matches.prefix(resultLimit)
        var sections: [SidebarSearchResultSection] = []
        var sectionIndexesBySourceID: [String: Int] = [:]
        for entry in visibleMatches {
            let sectionIndex: Int
            if let existingIndex = sectionIndexesBySourceID[entry.source.id] {
                sectionIndex = existingIndex
            } else {
                sections.append(SidebarSearchResultSection(id: entry.source.id, title: entry.source.title, rows: []))
                sectionIndex = sections.endIndex - 1
                sectionIndexesBySourceID[entry.source.id] = sectionIndex
            }

            sections[sectionIndex].rows.append(entry.row)
        }

        return SidebarSearchResults(
            sections: sections,
            totalMatches: min(totalMatches, collectionLimit),
            isTruncated: totalMatches > resultLimit
        )
    }

    /// Warms the streamed Apple symbol result cache for a query without publishing search results.
    ///
    /// - Parameters:
    ///   - query: Raw or normalized query text.
    ///   - limit: Maximum number of rows the matching search will request.
    public func warmStreamingAppleMatches(for query: String, limit: Int = defaultResultLimit) {
        let normalizedQuery = Self.normalize(query)
        guard normalizedQuery.count >= Self.minimumStreamingAppleQueryLength, !streamingAppleIndexes.isEmpty else { return }

        let collectionLimit = max(0, limit) + 1
        var scoreBuckets = Array(repeating: [Entry](), count: SearchScore.bucketCount)
        var totalMatches = 0
        appendStreamingAppleMatches(
            normalizedQuery: normalizedQuery,
            collectionLimit: collectionLimit,
            scoreBuckets: &scoreBuckets,
            totalMatches: &totalMatches
        )
    }

    /// Prepares in-memory Apple symbol lookup buckets for faster streamed searches.
    public func prepareStreamingAppleSymbolSearch() {
        for streamingAppleIndex in streamingAppleIndexes {
            streamingAppleIndex.prepare()
        }
    }

    /// Creates an index from a prebuilt entry array.
    ///
    /// - Parameters:
    ///   - id: Snapshot identity.
    ///   - entries: Flattened searchable entries.
    private init(
        id: UUID,
        entries: [Entry],
        streamingAppleIndexes: [StreamingAppleIndex] = [],
        progress: (@Sendable (Double) -> Void)? = nil
    ) {
        let entries = Self.deduplicatedEntries(entries)
        let searchBuckets = Self.makeSearchBuckets(entries, progress: progress)
        self.init(
            id: id,
            entries: entries,
            streamingAppleIndexes: streamingAppleIndexes,
            searchBuckets: searchBuckets
        )
    }

    /// Creates an index from prebuilt entries and lookup buckets.
    ///
    /// - Parameters:
    ///   - id: Snapshot identity.
    ///   - entries: Flattened searchable entries.
    ///   - streamingAppleIndexes: Apple indexes searched on demand.
    ///   - searchBuckets: Prebuilt ASCII lookup buckets matching `entries`.
    private init(
        id: UUID,
        entries: [Entry],
        streamingAppleIndexes: [StreamingAppleIndex] = [],
        streamingAppleQueryCache: StreamingAppleQueryCache = StreamingAppleQueryCache(),
        searchBuckets: [[Int]]
    ) {
        self.id = id
        self.entries = entries
        self.streamingAppleIndexes = streamingAppleIndexes
        self.streamingAppleQueryCache = streamingAppleQueryCache
        self.entryIndexesByASCIIByte = searchBuckets
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let entries = try container.decode([Entry].self, forKey: .entries)
        self.init(id: id, entries: entries)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(entries, forKey: .entries)
    }

    /// Creates compact binary data for the offline search cache.
    ///
    /// - Returns: Binary data containing only the fields required to restore search rows.
    public func cacheData() -> Data {
        let cachedEntries = flattenedEntriesForCache()

        var writer = CacheWriter()
        writer.writeString("DocBSearchIndex")
        writer.writeUInt32(5)
        writer.writeString(id.uuidString)
        writer.writeUInt32(UInt32(cachedEntries.count))

        for entry in cachedEntries {
            writer.writeString(entry.id)
            writer.writeString(entry.source.id)
            writer.writeString(entry.source.title)
            writer.writeString(entry.title)
            writer.writeString(entry.normalizedTitle)
            writer.writeStrings(entry.normalizedTags)
            writer.writeInt32(Int32(entry.kindRank))
            writer.writeRow(entry.row)
        }

        return writer.data
    }

    /// Restores an index from compact binary offline search-cache data.
    ///
    /// - Parameter data: Binary cache data previously produced by `cacheData()`.
    public init(cacheData data: Data) throws {
        var reader = CacheReader(data: data)
        guard try reader.readString() == "DocBSearchIndex" else {
            throw CacheError.invalidHeader
        }

        let version = try reader.readUInt32()
        guard version == 3 || version == 4 || version == 5,
              let id = UUID(uuidString: try reader.readString()) else {
            throw CacheError.invalidHeader
        }

        let entryCount = Int(try reader.readUInt32())
        var entries: [Entry] = []
        entries.reserveCapacity(entryCount)

        for _ in 0..<entryCount {
            let id = try reader.readString()
            let source = Source(id: try reader.readString(), title: try reader.readString())
            let title = try reader.readString()
            let normalizedTitle = try reader.readString()
            let normalizedTags = try reader.readStrings()
            let kindRank = Int(try reader.readInt32())
            let row = try reader.readRow()
            entries.append(Entry(
                id: id,
                source: source,
                title: title,
                normalizedTitle: normalizedTitle,
                normalizedTags: normalizedTags,
                kindRank: kindRank,
                row: row
            ))
        }

        let searchBuckets: [[Int]]
        if version == 4 {
            searchBuckets = try reader.readSearchBuckets(entryCount: entries.count)
        } else {
            searchBuckets = Self.makeSearchBuckets(entries)
        }

        self.init(id: id, entries: entries, searchBuckets: searchBuckets)
    }

    private func flattenedEntriesForCache() -> [Entry] {
        guard !streamingAppleIndexes.isEmpty else {
            return entries
        }

        var cachedEntries = entries
        for streamingAppleIndex in streamingAppleIndexes {
            streamingAppleIndex.appendCacheEntries(to: &cachedEntries)
        }

        return Self.deduplicatedEntries(cachedEntries)
    }

    private func appendStreamingAppleMatches(
        normalizedQuery: String,
        collectionLimit: Int,
        scoreBuckets: inout [[Entry]],
        totalMatches: inout Int
    ) {
        guard normalizedQuery.count >= Self.minimumStreamingAppleQueryLength else { return }

        if let cachedResult = streamingAppleQueryCache.value(for: normalizedQuery, collectionLimit: collectionLimit) {
            totalMatches += cachedResult.totalMatches
            for bucketIndex in cachedResult.buckets.indices {
                scoreBuckets[bucketIndex].append(contentsOf: cachedResult.buckets[bucketIndex])
            }
            return
        }

        guard !streamingAppleIndexes.isEmpty else { return }

        var streamedBuckets = Array(repeating: [Entry](), count: SearchScore.bucketCount)
        var streamedTotalMatches = 0
        for streamingAppleIndex in streamingAppleIndexes {
            streamingAppleIndex.appendMatches(
                normalizedQuery: normalizedQuery,
                collectionLimit: collectionLimit,
                scoreBuckets: &streamedBuckets,
                totalMatches: &streamedTotalMatches
            )
        }

        streamingAppleQueryCache.store(
            StreamingAppleQueryCache.Value(buckets: streamedBuckets, totalMatches: streamedTotalMatches),
            for: normalizedQuery,
            collectionLimit: collectionLimit
        )
        totalMatches += streamedTotalMatches
        for bucketIndex in streamedBuckets.indices {
            scoreBuckets[bucketIndex].append(contentsOf: streamedBuckets[bucketIndex])
        }
    }

    /// Removes repeated logical rows while preserving first-match ordering.
    ///
    /// - Parameter entries: Flattened searchable entries.
    /// - Returns: Entries with duplicate result keys removed.
}
