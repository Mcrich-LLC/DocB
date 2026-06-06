import Foundation
import DocCKit
import Synchronization

extension SidebarSearchIndex {
    static func deduplicatedEntries(_ entries: [Entry]) -> [Entry] {
        var seenKeys: Set<String> = []

        return entries.filter { entry in
            seenKeys.insert(entry.deduplicationKey).inserted
        }
    }

    /// Returns the smallest likely candidate slice for a normalized query.
    ///
    /// - Parameter normalizedQuery: Query already passed through `normalize(_:)`.
    /// - Returns: Entry indexes whose searchable text can contain the query.
    func candidateEntryIndexes(for normalizedQuery: String) -> AnySequence<Int> {
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
    static func makeSearchBuckets(
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
    static func appendDocCEntries(
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
    static func appendDocCEntries(
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
    static func estimatedEntryCount(
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
    static func estimatedEntryCount(in index: DocCIndex) -> Int {
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
    static func sortedLanguageKeys(_ keys: Dictionary<String, [DocCIndex.InterfaceLanguage]>.Keys) -> [String] {
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
    static func normalizedPath(_ path: String) -> String {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let pathWithLeadingSlash = trimmedPath.hasPrefix("/") ? trimmedPath : "/\(trimmedPath)"
        let pathWithoutBoundarySlashes = pathWithLeadingSlash.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return pathWithoutBoundarySlashes.isEmpty ? "/" : "/\(pathWithoutBoundarySlashes.lowercased())"
    }

    /// Returns a coarse ordering for result kinds where type definitions beat members mentioning the query.
    ///
    /// - Parameter symbolKind: Search symbol kind inferred from the DocC index.
    /// - Returns: Lower values rank earlier.
    static func kindRank(for symbolKind: SidebarSearchSymbolKind) -> Int {
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

    struct Entry: Sendable, Codable {
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
    struct Source: Sendable, Codable {
        /// Stable source identifier.
        let id: String
        /// Display title.
        let title: String
    }

    /// Apple DocC index searched without duplicating every symbol as a retained entry.
    final class StreamingAppleIndex: Sendable {
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

        func appendPreparedMatches(
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

        func appendStreamingMatches(
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

        struct PreparedIndex: Sendable {
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
    final class StreamingAppleQueryCache: Sendable {
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

        func key(for normalizedQuery: String, collectionLimit: Int) -> String {
            "\(collectionLimit)\u{0}\(normalizedQuery)"
        }

        struct State: Sendable {
            var values: [String: Value] = [:]
            var keys: [String] = []
        }
    }

    /// Collects unique searchable bytes for one entry.
    struct SearchKeyCollector {
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
    struct SearchScore: Sendable {
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

    enum CacheError: Error {
        case invalidHeader
        case invalidData
    }

    struct CacheWriter {
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

    struct CacheReader {
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
