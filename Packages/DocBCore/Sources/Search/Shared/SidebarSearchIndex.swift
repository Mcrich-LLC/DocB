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
    private let entries: [Entry]
    /// Apple DocC indexes searched on demand without flattening every symbol into memory.
    private let streamingAppleIndexes: [StreamingAppleIndex]
    /// Bounded in-memory cache of streamed Apple query results.
    private let streamingAppleQueryCache: StreamingAppleQueryCache
    /// Entry indexes grouped by searchable ASCII byte for faster substring candidates.
    private let entryIndexesByASCIIByte: [[Int]]

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
        let cachedSearchBuckets = streamingAppleIndexes.isEmpty ? entryIndexesByASCIIByte : Self.makeSearchBuckets(cachedEntries)

        var writer = CacheWriter()
        writer.writeString("DocBSearchIndex")
        writer.writeUInt32(4)
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

        writer.writeSearchBuckets(cachedSearchBuckets)
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
        guard version == 3 || version == 4,
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
        if version >= 4 {
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
    private static func deduplicatedEntries(_ entries: [Entry]) -> [Entry] {
        var seenKeys: Set<String> = []

        return entries.filter { entry in
            seenKeys.insert(entry.deduplicationKey).inserted
        }
    }

    /// Returns the smallest likely candidate slice for a normalized query.
    ///
    /// - Parameter normalizedQuery: Query already passed through `normalize(_:)`.
    /// - Returns: Entry indexes whose searchable text can contain the query.
    private func candidateEntryIndexes(for normalizedQuery: String) -> AnySequence<Int> {
        let queryBytes = Array(normalizedQuery.utf8)
        guard queryBytes.allSatisfy({ $0 < 128 }) else {
            return AnySequence(entries.indices)
        }

        guard let firstByte = queryBytes.first else { return AnySequence([].lazy) }

        var candidateIndexes = entryIndexesByASCIIByte[Int(firstByte)]
        for byte in queryBytes.dropFirst() {
            let indexes = entryIndexesByASCIIByte[Int(byte)]
            if indexes.count < candidateIndexes.count {
                candidateIndexes = indexes
            }
        }

        return AnySequence(candidateIndexes)
    }

    /// Builds compact ASCII lookup buckets while preserving original entry order inside each bucket.
    ///
    /// - Parameter entries: Flattened searchable entries.
    /// - Returns: A complete set of ASCII lookup buckets keyed by byte.
    private static func makeSearchBuckets(
        _ entries: [Entry],
        progress: (@Sendable (Double) -> Void)? = nil
    ) -> [[Int]] {
        var buckets = Array(repeating: [Int](), count: 128)
        let entryCount = max(entries.count, 1)

        for (entryIndex, entry) in entries.enumerated() {
            var keys = SearchKeyCollector()
            entry.collectSearchKeys(into: &keys)

            for byte in keys.bytes {
                buckets[Int(byte)].append(entryIndex)
            }

            let completedEntries = entryIndex + 1
            if completedEntries == entryCount || completedEntries.isMultiple(of: 512) {
                progress?(0.6 + (0.4 * Double(completedEntries) / Double(entryCount)))
            }
        }

        return buckets
    }

    /// Appends flattened DocC node entries for one custom source.
    ///
    /// - Parameters:
    ///   - site: Custom DocC source to flatten.
    ///   - source: Result grouping metadata for the source.
    ///   - entries: Destination entry buffer.
    private static func appendDocCEntries(
        from site: DocCSource,
        source: Source,
        to entries: inout [Entry],
        onAppendEntry: () -> Void = {}
    ) {
        appendDocCEntries(from: site, index: site.index, source: source, to: &entries, onAppendEntry: onAppendEntry)
    }

    /// Appends flattened DocC node entries for one source index.
    ///
    /// - Parameters:
    ///   - site: Custom DocC source context, or `nil` for Apple-hosted documentation.
    ///   - index: DocC index to flatten.
    ///   - source: Result grouping metadata for the source.
    ///   - entries: Destination entry buffer.
    private static func appendDocCEntries(
        from site: DocCSource?,
        index: DocCIndex,
        source: Source,
        to entries: inout [Entry],
        onAppendEntry: () -> Void = {}
    ) {
        func append(_ interfaceLanguage: DocCIndex.InterfaceLanguage) {
            if interfaceLanguage.type.lowercased() != "module", let path = interfaceLanguage.path {
                let id = "\(source.id)-\(Self.normalizedPath(path))-\(Self.normalize(interfaceLanguage.title))"
                let symbolKind = SidebarSearchSymbolKind(interfaceLanguage: interfaceLanguage)
                entries.append(.init(
                    id: id,
                    source: source,
                    title: interfaceLanguage.title,
                    normalizedTitle: normalize(interfaceLanguage.title),
                    normalizedTags: [],
                    kindRank: Self.kindRank(for: symbolKind),
                    row: .reference(.init(
                        id: id,
                        title: interfaceLanguage.title,
                        path: path,
                        type: interfaceLanguage.type,
                        symbolKind: symbolKind,
                        customIconIdentifier: interfaceLanguage.icon,
                        site: site
                    ))
                ))
                onAppendEntry()
            }

            for child in interfaceLanguage.children ?? [] {
                append(child)
            }
        }

        for languageKey in Self.sortedLanguageKeys(index.interfaceLanguages.keys) {
            for language in index.interfaceLanguages[languageKey] ?? [] {
                append(language)
            }
        }
    }

    /// Estimates the number of rows that will be flattened into the search index.
    ///
    /// - Parameters:
    ///   - docCSites: Custom DocC sources.
    ///   - appleTechnologies: Apple technology snapshots.
    /// - Returns: Expected searchable row count before duplicate collapse.
    private static func estimatedEntryCount(
        in docCSites: [DocCSource],
        appleTechnologies: [AppleTechnologies]
    ) -> Int {
        let docCEntryCount = docCSites.reduce(0) { total, site in
            total + estimatedEntryCount(in: site.index)
        }

        let appleEntryCount = appleTechnologies.reduce(0) { total, appleTechnologies in
            let frameworkCount = appleTechnologies.groups?.reduce(0) { groupTotal, group in
                groupTotal + group.technologies.filter { $0.destination.isActive }.count
            } ?? 0

            return total + 1 + frameworkCount + (appleTechnologies.index.map(estimatedEntryCount(in:)) ?? 0)
        }

        return docCEntryCount + appleEntryCount
    }

    /// Counts searchable DocC entries in an index.
    ///
    /// - Parameter index: DocC index to count.
    /// - Returns: Count of non-module nodes that have paths.
    private static func estimatedEntryCount(in index: DocCIndex) -> Int {
        func count(_ interfaceLanguage: DocCIndex.InterfaceLanguage) -> Int {
            let currentCount = interfaceLanguage.type.lowercased() != "module" && interfaceLanguage.path != nil ? 1 : 0
            return currentCount + (interfaceLanguage.children ?? []).reduce(0) { $0 + count($1) }
        }

        return index.interfaceLanguages.values.reduce(0) { total, languages in
            total + languages.reduce(0) { $0 + count($1) }
        }
    }

    /// Sorts DocC language keys with Swift first, then alphabetically.
    ///
    /// - Parameter keys: Interface-language dictionary keys.
    /// - Returns: Stable language order for indexing and duplicate preference.
    private static func sortedLanguageKeys(_ keys: Dictionary<String, [DocCIndex.InterfaceLanguage]>.Keys) -> [String] {
        keys.sorted { lhs, rhs in
            if lhs == "swift" { return true }
            if rhs == "swift" { return false }
            return lhs < rhs
        }
    }

    /// Normalizes DocC paths for identity and deduplication.
    ///
    /// - Parameter path: A DocC path from an index entry.
    /// - Returns: A lowercased path with one leading slash and no trailing slash.
    private static func normalizedPath(_ path: String) -> String {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let pathWithLeadingSlash = trimmedPath.hasPrefix("/") ? trimmedPath : "/\(trimmedPath)"
        let pathWithoutBoundarySlashes = pathWithLeadingSlash.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return pathWithoutBoundarySlashes.isEmpty ? "/" : "/\(pathWithoutBoundarySlashes.lowercased())"
    }

    /// Returns a coarse ordering for result kinds where type definitions beat members mentioning the query.
    ///
    /// - Parameter symbolKind: Search symbol kind inferred from the DocC index.
    /// - Returns: Lower values rank earlier.
    private static func kindRank(for symbolKind: SidebarSearchSymbolKind) -> Int {
        switch symbolKind {
        case .classSymbol, .structure, .protocolSymbol, .enumeration, .typeAlias:
            return 0
        case .article:
            return 1
        case .function, .method:
            return 3
        case .initializer, .property, .enumerationCase:
            return 4
        default:
            return 2
        }
    }

    /// Pre-normalized searchable row.
    private struct Entry: Sendable, Codable {
        /// Stable row identifier.
        let id: String
        /// Source grouping metadata.
        let source: Source
        /// Display title.
        let title: String
        /// Normalized display title.
        let normalizedTitle: String
        /// Normalized tags.
        let normalizedTags: [String]
        /// Coarse result-kind rank; lower values are usually more helpful.
        let kindRank: Int
        /// UI row payload.
        let row: SidebarSearchResultRow

        /// Stable logical key used to remove duplicate rows.
        var deduplicationKey: String {
            switch row {
            case .homepage:
                return id
            case .reference(let result):
                return "\(source.id)-reference-\(SidebarSearchIndex.normalizedPath(result.path))-\(SidebarSearchIndex.normalize(result.title))"
            case .technology:
                return id
            }
        }

        /// Scores this entry for a normalized query.
        ///
        /// - Parameters:
        ///   - normalizedQuery: Query already passed through `normalize(_:)`.
        /// - Returns: A score when the title or any tag contains the query.
        func matchScore(for normalizedQuery: String) -> SearchScore? {
            if normalizedTitle == normalizedQuery {
                return SearchScore(matchRank: 0, kindRank: kindRank)
            }

            if normalizedTitle.hasPrefix(normalizedQuery) {
                return SearchScore(matchRank: 1, kindRank: kindRank)
            }

            if normalizedTitle.contains(normalizedQuery) {
                return SearchScore(matchRank: 2, kindRank: kindRank)
            }

            if normalizedTags.contains(where: { $0 == normalizedQuery }) {
                return SearchScore(matchRank: 3, kindRank: kindRank)
            }

            if normalizedTags.contains(where: { $0.hasPrefix(normalizedQuery) }) {
                return SearchScore(matchRank: 4, kindRank: kindRank)
            }

            if normalizedTags.contains(where: { $0.contains(normalizedQuery) }) {
                return SearchScore(matchRank: 5, kindRank: kindRank)
            }

            return nil
        }

        /// Collects ASCII keys present in searchable text for candidate lookup.
        ///
        /// - Parameter keys: Destination collector for unique searchable keys.
        func collectSearchKeys(into keys: inout SearchKeyCollector) {
            keys.collect(from: normalizedTitle)

            for tag in normalizedTags {
                keys.collect(from: tag)
            }
        }
    }

    /// Search result source grouping metadata.
    private struct Source: Sendable, Codable {
        /// Stable source identifier.
        let id: String
        /// Display title.
        let title: String
    }

    /// Apple DocC index searched without duplicating every symbol as a retained entry.
    private final class StreamingAppleIndex: Sendable {
        /// Result grouping metadata.
        let source: Source
        /// Apple documentation index to scan per query.
        let index: DocCIndex
        private let preparedIndex = Mutex<PreparedIndex?>(nil)

        init(source: Source, index: DocCIndex) {
            self.source = source
            self.index = index
        }

        /// Prepares in-memory lookup buckets for repeated streamed searches.
        func prepare() {
            if preparedIndexSnapshot != nil {
                return
            }

            var entries: [Entry] = []
            SidebarSearchIndex.appendDocCEntries(from: nil, index: index, source: source, to: &entries)
            let deduplicatedEntries = SidebarSearchIndex.deduplicatedEntries(entries)
            let builtIndex = PreparedIndex(
                entries: deduplicatedEntries,
                searchBuckets: SidebarSearchIndex.makeSearchBuckets(deduplicatedEntries)
            )

            preparedIndex.withLock { preparedIndex in
                if preparedIndex == nil {
                    preparedIndex = builtIndex
                }
            }
        }

        /// Appends all Apple entries for the existing flattened disk cache format.
        ///
        /// - Parameter entries: Destination entry buffer.
        func appendCacheEntries(to entries: inout [Entry]) {
            if let preparedIndex = preparedIndexSnapshot {
                entries.append(contentsOf: preparedIndex.entries)
                return
            }

            SidebarSearchIndex.appendDocCEntries(from: nil, index: index, source: source, to: &entries)
        }

        func appendMatches(
            normalizedQuery: String,
            collectionLimit: Int,
            scoreBuckets: inout [[Entry]],
            totalMatches: inout Int
        ) {
            if let preparedIndex = preparedIndexSnapshot {
                appendPreparedMatches(
                    preparedIndex,
                    normalizedQuery: normalizedQuery,
                    collectionLimit: collectionLimit,
                    scoreBuckets: &scoreBuckets,
                    totalMatches: &totalMatches
                )
                return
            }

            appendStreamingMatches(
                normalizedQuery: normalizedQuery,
                collectionLimit: collectionLimit,
                scoreBuckets: &scoreBuckets,
                totalMatches: &totalMatches
            )
        }

        private var preparedIndexSnapshot: PreparedIndex? {
            preparedIndex.withLock { $0 }
        }

        private func appendPreparedMatches(
            _ preparedIndex: PreparedIndex,
            normalizedQuery: String,
            collectionLimit: Int,
            scoreBuckets: inout [[Entry]],
            totalMatches: inout Int
        ) {
            for entryIndex in preparedIndex.candidateEntryIndexes(for: normalizedQuery) {
                let entry = preparedIndex.entries[entryIndex]
                guard let score = entry.matchScore(for: normalizedQuery) else {
                    continue
                }

                totalMatches += 1
                let bucketIndex = score.bucketIndex
                if scoreBuckets[bucketIndex].count < collectionLimit {
                    scoreBuckets[bucketIndex].append(entry)
                }
            }
        }

        private func appendStreamingMatches(
            normalizedQuery: String,
            collectionLimit: Int,
            scoreBuckets: inout [[Entry]],
            totalMatches: inout Int
        ) {
            var seenKeys: Set<String> = []

            func append(_ interfaceLanguage: DocCIndex.InterfaceLanguage) {
                if interfaceLanguage.type.lowercased() != "module", let path = interfaceLanguage.path {
                    let normalizedTitle = SidebarSearchIndex.normalize(interfaceLanguage.title)
                    guard normalizedTitle.contains(normalizedQuery) else {
                        for child in interfaceLanguage.children ?? [] {
                            append(child)
                        }
                        return
                    }

                    let symbolKind = SidebarSearchSymbolKind(interfaceLanguage: interfaceLanguage)
                    let entry = Entry(
                        id: "\(source.id)-\(SidebarSearchIndex.normalizedPath(path))-\(normalizedTitle)",
                        source: source,
                        title: interfaceLanguage.title,
                        normalizedTitle: normalizedTitle,
                        normalizedTags: [],
                        kindRank: SidebarSearchIndex.kindRank(for: symbolKind),
                        row: .reference(.init(
                            id: "\(source.id)-\(SidebarSearchIndex.normalizedPath(path))-\(normalizedTitle)",
                            title: interfaceLanguage.title,
                            path: path,
                            type: interfaceLanguage.type,
                            symbolKind: symbolKind,
                            customIconIdentifier: interfaceLanguage.icon,
                            site: nil
                        ))
                    )
                    guard let score = entry.matchScore(for: normalizedQuery) else {
                        for child in interfaceLanguage.children ?? [] {
                            append(child)
                        }
                        return
                    }
                    guard seenKeys.insert(entry.deduplicationKey).inserted else {
                        for child in interfaceLanguage.children ?? [] {
                            append(child)
                        }
                        return
                    }

                    totalMatches += 1
                    let bucketIndex = score.bucketIndex
                    if scoreBuckets[bucketIndex].count < collectionLimit {
                        scoreBuckets[bucketIndex].append(entry)
                    }
                }

                for child in interfaceLanguage.children ?? [] {
                    append(child)
                }
            }

            for languageKey in SidebarSearchIndex.sortedLanguageKeys(index.interfaceLanguages.keys) {
                for language in index.interfaceLanguages[languageKey] ?? [] {
                    append(language)
                }
            }
        }

        private struct PreparedIndex: Sendable {
            let entries: [Entry]
            let searchBuckets: [[Int]]

            func candidateEntryIndexes(for normalizedQuery: String) -> AnySequence<Int> {
                let queryBytes = Array(normalizedQuery.utf8)
                guard queryBytes.allSatisfy({ $0 < 128 }) else {
                    return AnySequence(entries.indices)
                }

                guard let firstByte = queryBytes.first else { return AnySequence([].lazy) }

                var candidateIndexes = searchBuckets[Int(firstByte)]
                for byte in queryBytes.dropFirst() {
                    let indexes = searchBuckets[Int(byte)]
                    if indexes.count < candidateIndexes.count {
                        candidateIndexes = indexes
                    }
                }

                return AnySequence(candidateIndexes)
            }
        }
    }

    /// Bounded in-memory cache for streamed Apple query result buckets.
    private final class StreamingAppleQueryCache: Sendable {
        struct Value: Sendable {
            let buckets: [[Entry]]
            let totalMatches: Int
        }

        private let capacity = 16
        private let state = Mutex(State())

        func value(for normalizedQuery: String, collectionLimit: Int) -> Value? {
            let key = key(for: normalizedQuery, collectionLimit: collectionLimit)

            return state.withLock { state in
                state.values[key]
            }
        }

        func store(_ value: Value, for normalizedQuery: String, collectionLimit: Int) {
            let key = key(for: normalizedQuery, collectionLimit: collectionLimit)

            state.withLock { state in
                if state.values[key] == nil {
                    state.keys.append(key)
                }
                state.values[key] = value

                while state.keys.count > capacity {
                    let removedKey = state.keys.removeFirst()
                    state.values[removedKey] = nil
                }
            }
        }

        private func key(for normalizedQuery: String, collectionLimit: Int) -> String {
            "\(collectionLimit)\u{0}\(normalizedQuery)"
        }

        private struct State: Sendable {
            var values: [String: Value] = [:]
            var keys: [String] = []
        }
    }

    /// Collects unique searchable bytes for one entry.
    private struct SearchKeyCollector {
        /// Unique ASCII bytes in the entry.
        var bytes: Set<UInt8> = []

        /// Collects rolling ASCII keys from a normalized searchable string.
        ///
        /// - Parameter value: Normalized searchable text.
        mutating func collect(from value: String) {
            for byte in value.utf8 {
                guard byte < 128 else { continue }
                bytes.insert(byte)
            }
        }
    }

    /// Sortable search score for one matching entry.
    private struct SearchScore: Sendable {
        /// Number of score buckets used by `bucketIndex`.
        static let bucketCount = 48
        /// Match quality rank; lower values are better.
        let matchRank: Int
        /// Result kind rank; lower values are more useful symbol kinds.
        let kindRank: Int

        /// Stable bucket position ordered by match quality, then symbol kind quality.
        var bucketIndex: Int {
            (matchRank * 8) + min(kindRank, 7)
        }
    }

    fileprivate enum CacheError: Error {
        case invalidHeader
        case invalidData
    }

    fileprivate struct CacheWriter {
        var data = Data()

        mutating func writeUInt8(_ value: UInt8) {
            data.append(value)
        }

        mutating func writeBool(_ value: Bool) {
            writeUInt8(value ? 1 : 0)
        }

        mutating func writeUInt32(_ value: UInt32) {
            var value = value.littleEndian
            withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
        }

        mutating func writeInt32(_ value: Int32) {
            var value = value.littleEndian
            withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
        }

        mutating func writeDouble(_ value: Double) {
            var value = value
            withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
        }

        mutating func writeString(_ value: String) {
            let bytes = value.utf8
            writeUInt32(UInt32(bytes.count))
            data.append(contentsOf: bytes)
        }

        mutating func writeOptionalString(_ value: String?) {
            writeBool(value != nil)
            if let value {
                writeString(value)
            }
        }

        mutating func writeStrings(_ values: [String]) {
            writeUInt32(UInt32(values.count))
            for value in values {
                writeString(value)
            }
        }

        mutating func writeData(_ value: Data) {
            writeUInt32(UInt32(value.count))
            data.append(value)
        }

        mutating func writeSearchBuckets(_ buckets: [[Int]]) {
            writeUInt32(UInt32(buckets.count))
            for bucket in buckets {
                writeUInt32(UInt32(bucket.count))
                for entryIndex in bucket {
                    writeUInt32(UInt32(entryIndex))
                }
            }
        }

        mutating func writeRow(_ row: SidebarSearchResultRow) {
            switch row {
            case .homepage(let id, let title):
                writeUInt8(0)
                writeString(id)
                writeString(title)
            case .reference(let result):
                writeUInt8(1)
                writeString(result.id)
                writeString(result.title)
                writeString(result.path)
                writeString(result.type)
                writeString(result.symbolKind.rawValue)
                writeOptionalString(result.customIconIdentifier)
                writeDocCSource(result.site)
            case .technology(let result):
                writeUInt8(2)
                writeString(result.id)
                writeString(result.title)
                writeFramework(result.framework)
            }
        }

        mutating func writeDocCSource(_ source: DocCSource?) {
            writeBool(source != nil)
            guard let source else { return }

            writeString(source.id.uuidString)
            writeDouble(source.timestamp.timeIntervalSinceReferenceDate)
            writeString(source.url.absoluteString)
            writeOptionalString(source.overrideName)
            writeString(source.index.id.uuidString)
            if let includedArchiveIdentifiers = source.index.includedArchiveIdentifiers {
                writeBool(true)
                writeStrings(includedArchiveIdentifiers)
            } else {
                writeBool(false)
            }
        }

        mutating func writeFramework(_ framework: AppleTechnologies.FrameworkSection) {
            writeStrings(framework.languages)
            writeString(framework.title)
            writeStrings(framework.tags)
            writeString(framework.destination.type)
            writeBool(framework.destination.isActive)
            writeString(framework.destination.identifier)
        }
    }

    fileprivate struct CacheReader {
        let data: Data
        var offset = 0

        mutating func readUInt8() throws -> UInt8 {
            guard offset < data.count else { throw CacheError.invalidData }
            defer { offset += 1 }
            return data[offset]
        }

        mutating func readBool() throws -> Bool {
            try readUInt8() != 0
        }

        mutating func readUInt32() throws -> UInt32 {
            guard offset + MemoryLayout<UInt32>.size <= data.count else { throw CacheError.invalidData }
            let value = data.withUnsafeBytes { rawBuffer in
                rawBuffer.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
            }
            offset += MemoryLayout<UInt32>.size
            return UInt32(littleEndian: value)
        }

        mutating func readInt32() throws -> Int32 {
            guard offset + MemoryLayout<Int32>.size <= data.count else { throw CacheError.invalidData }
            let value = data.withUnsafeBytes { rawBuffer in
                rawBuffer.loadUnaligned(fromByteOffset: offset, as: Int32.self)
            }
            offset += MemoryLayout<Int32>.size
            return Int32(littleEndian: value)
        }

        mutating func readDouble() throws -> Double {
            guard offset + MemoryLayout<Double>.size <= data.count else { throw CacheError.invalidData }
            let value = data.withUnsafeBytes { rawBuffer in
                rawBuffer.loadUnaligned(fromByteOffset: offset, as: Double.self)
            }
            offset += MemoryLayout<Double>.size
            return value
        }

        mutating func readString() throws -> String {
            let length = Int(try readUInt32())
            guard offset + length <= data.count else { throw CacheError.invalidData }
            let bytes = data[offset..<(offset + length)]
            offset += length
            guard let value = String(data: bytes, encoding: .utf8) else {
                throw CacheError.invalidData
            }

            return value
        }

        mutating func readOptionalString() throws -> String? {
            try readBool() ? readString() : nil
        }

        mutating func readStrings() throws -> [String] {
            let count = Int(try readUInt32())
            var values: [String] = []
            values.reserveCapacity(count)
            for _ in 0..<count {
                values.append(try readString())
            }

            return values
        }

        mutating func readData() throws -> Data {
            let length = Int(try readUInt32())
            guard offset + length <= data.count else { throw CacheError.invalidData }
            let value = data[offset..<(offset + length)]
            offset += length
            return Data(value)
        }

        mutating func readSearchBuckets(entryCount: Int) throws -> [[Int]] {
            let bucketCount = Int(try readUInt32())
            guard bucketCount == 128 else { throw CacheError.invalidData }

            var buckets = Array(repeating: [Int](), count: bucketCount)
            for bucketIndex in 0..<bucketCount {
                let entryIndexCount = Int(try readUInt32())
                buckets[bucketIndex].reserveCapacity(entryIndexCount)
                for _ in 0..<entryIndexCount {
                    let entryIndex = Int(try readUInt32())
                    guard entryIndex >= 0, entryIndex < entryCount else {
                        throw CacheError.invalidData
                    }

                    buckets[bucketIndex].append(entryIndex)
                }
            }

            return buckets
        }

        mutating func readRow() throws -> SidebarSearchResultRow {
            switch try readUInt8() {
            case 0:
                return .homepage(id: try readString(), title: try readString())
            case 1:
                let id = try readString()
                let title = try readString()
                let path = try readString()
                let type = try readString()
                let symbolKind = SidebarSearchSymbolKind(rawValue: try readString()) ?? .unknown
                let customIconIdentifier = try readOptionalString()
                let site = try readDocCSource()
                return .reference(SidebarSearchReferenceResult(
                    id: id,
                    title: title,
                    path: path,
                    type: type,
                    symbolKind: symbolKind,
                    customIconIdentifier: customIconIdentifier,
                    site: site
                ))
            case 2:
                let id = try readString()
                let title = try readString()
                return .technology(SidebarSearchTechnologyResult(
                    id: id,
                    title: title,
                    framework: try readFramework(),
                    badgeReference: nil
                ))
            default:
                throw CacheError.invalidData
            }
        }

        mutating func readDocCSource() throws -> DocCSource? {
            guard try readBool() else { return nil }
            guard let id = UUID(uuidString: try readString()) else { throw CacheError.invalidData }
            let timestamp = Date(timeIntervalSinceReferenceDate: try readDouble())
            guard let url = URL(string: try readString()) else { throw CacheError.invalidData }
            let overrideName = try readOptionalString()
            guard let indexID = UUID(uuidString: try readString()) else { throw CacheError.invalidData }
            let includedArchiveIdentifiers = try readBool() ? try readStrings() : nil

            return DocCSource(
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

        mutating func readFramework() throws -> AppleTechnologies.FrameworkSection {
            let languages = try readStrings()
            let title = try readString()
            let tags = try readStrings()
            let destination = AppleTechnologies.FrameworkSection.Destination(
                type: try readString(),
                isActive: try readBool(),
                identifier: try readString()
            )

            return AppleTechnologies.FrameworkSection(
                languages: languages,
                title: title,
                tags: tags,
                destination: destination,
                legalNotices: nil,
                docCSite: nil
            )
        }
    }
}

/// Grouped sidebar search result set.
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
    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
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

    /// Stores a flattened search index for a source fingerprint.
    ///
    /// - Parameters:
    ///   - index: Flattened search index to cache.
    ///   - fingerprint: Source fingerprint associated with the cache entry.
    public func store(_ index: SidebarSearchIndex, for fingerprint: String) {
        guard !fingerprint.isEmpty else { return }

        do {
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            let payload = Payload(version: Self.cacheVersion, fingerprint: fingerprint, index: index)
            try payload.data().write(to: cacheURL(for: fingerprint), options: .atomic)
        } catch {
            print(error)
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

    /// User-facing title for the current index-build phase.
    public var indexBuildTitle: String {
        if isRebuildingIndex && indexBuildProgress == nil {
            return "Loading Index"
        }

        return indexBuildCount == 0 && index.entryCount == 0 ? "Indexing" : "Updating Index"
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

        indexBuildTask = Task(priority: .utility) {
            if let sourceFingerprint,
               let cachedIndex = await searchIndexCache.index(for: sourceFingerprint) {
                await MainActor.run {
                    guard self.indexBuildRequestID == requestID else { return }

                    self.installIndex(cachedIndex)
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
                self.installIndex(index)
            }
        }
    }

    /// Installs an already-built index.
    ///
    /// - Parameters:
    ///   - index: Search index snapshot to publish.
    ///   - searchDebounce: Delay before re-running the current query against the installed index.
    public func installIndex(_ index: SidebarSearchIndex, searchDebounce: Duration = .milliseconds(120)) {
        searchTask?.cancel()
        indexBuildTask?.cancel()
        searchRequestID = UUID()
        indexBuildRequestID = UUID()
        self.index = index
        isRebuildingIndex = false
        indexBuildProgress = nil
        indexBuildCount += 1
        updateSearchText(rawSearchText, debounce: searchDebounce)
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
    public func updateSearchText(_ searchText: String, debounce: Duration = .milliseconds(120)) {
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
        results = .empty

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
