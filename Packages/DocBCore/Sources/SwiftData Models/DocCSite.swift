//
//  DocCSite.swift
//  DocB
//
//  Created by Morris Richman on 3/19/26.
//

import Foundation
import SwiftUI
import SwiftData
import DocCKit
import MYCloudKit

/// Persisted DocC source snapshot that bridges SwiftData records and runtime-only DocCKit source state.
///
/// Snapshot identity and equality are based on `id`, while hashing also includes timestamp, URL, and index.
@MainActor
public final class PersistedDocCSource: Identifiable, @preconcurrency Codable, Equatable, @preconcurrency Hashable {
    public nonisolated static func == (lhs: PersistedDocCSource, rhs: PersistedDocCSource) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(timestamp)
        hasher.combine(url)
        hasher.combine(index)
    }
    
    /// Stable identifier used for equality and identity in collections.
    public let id: UUID
    /// Timestamp indicating when the site was added.
    public let timestamp: Date
    /// Optional override display name for the site.
    public let overrideName: String?
    /// Root URL for the DocC site.
    public let url: URL
    /// Used for restoring access to sandbox-scoped resources on the file system
    public let urlBookmark: Data?
    /// Parsed index describing available interface-language groups and entries.
    public private(set) var index: DocCIndex
    /// Persistent SwiftData identifier used for direct delete operations.
    public fileprivate(set) var persistentModelID: PersistentIdentifier?
    
    /// Creates an in-memory persisted DocC source snapshot.
    public init(id: UUID = UUID(), timestamp: Date = .init(), url: URL, urlBookmark: Data?, overrideName: String? = nil, index: DocCIndex, persistentModelID: PersistentIdentifier? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.url = url
        self.urlBookmark = urlBookmark
        self.overrideName = overrideName
        self.index = index
        self.persistentModelID = persistentModelID
    }
    
    /// Creates a persisted source snapshot from a `DocCSite` model.
    ///
    /// - Parameter model: A persisted SwiftData model.
    /// - Throws: `SwiftDataErrors.invalidShape` when required fields are missing.
    public init(_ model: DocCSite) throws {
        guard let timestamp = model.timestamp, let url = model.url, let index = model.decodedIndex else {
            throw SwiftDataErrors.invalidShape
        }
        
        self.id = model.id
        self.timestamp = timestamp
        self.url = url
        self.urlBookmark = model.urlBookmark
        self.overrideName = model.overrideName
        self.index = index
        self.persistentModelID = model.persistentModelID
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.url = try container.decode(URL.self, forKey: .url)
        self.urlBookmark = try container.decodeIfPresent(Data.self, forKey: .urlBookmark)
        self.overrideName = try container.decodeIfPresent(String.self, forKey: .overrideName)
        self.index = try container.decode(DocCIndex.self, forKey: .index)
    }
    
    /// Updates the source index when a fresh remote index payload is loaded.
    ///
    /// - Parameter index: New index payload for the site.
    public func setIndex(_ index: DocCIndex) {
        self.index = index
    }
    
    /// Coding keys for source serialization/deserialization.
    public enum CodingKeys: String, CodingKey {
        case timestamp
        case url
        case urlBookmark
        case overrideName
        case index
    }
    
    /// Top-level interface-language groups flattened from the site index.
    public var groups: [DocCIndex.InterfaceLanguage] {
        index.interfaceLanguages.flatMap({ $0.value })
    }
    
    /// Framework sections derived from all index groups.
    public var allFrameworkSections: [AppleTechnologies.FrameworkSection] {
        groups.compactMap(frameworkSection)
    }
    
    /// Converts an interface-language entry into a framework section model for UI navigation.
    ///
    /// - Parameter interfaceLanguage: Source index item.
    /// - Returns: A framework section when a valid path is present; otherwise `nil`.
    public func frameworkSection(for interfaceLanguage: DocCIndex.InterfaceLanguage) -> AppleTechnologies.FrameworkSection? {
        guard let path = interfaceLanguage.path else { return nil }
        
        let languages = self.index.interfaceLanguages.filter({
            $0.value.contains(where: { $0.path == path }) || $0.value.flatMap { $0.children ?? [] }.contains(where: { $0.path == interfaceLanguage.path ?? "" })
        }).map(\.key)
        
        return AppleTechnologies.FrameworkSection(
            languages: languages,
            title: interfaceLanguage.title,
            tags: [],
            destination: .init(type: "",
            isActive: true,
            identifier: path),
            legalNotices: nil,
            docCSite: docCSource
        )
    }
    
    /// Deletes the associated persisted site when this snapshot is backed by SwiftData.
    ///
    /// - Parameter modelContext: SwiftData context used to locate and remove the model.
    public func deleteSite(modelContext: ModelContext) throws {
        guard let persistentModelID else { return }
        let model = modelContext.model(for: persistentModelID)
        modelContext.delete(model)
        try modelContext.save()
    }
    
    /// Pure DocCKit source value for renderer/client APIs.
    public var docCSource: DocCSource {
        DocCSource(id: id, timestamp: timestamp, url: url, overrideName: overrideName, index: index)
    }
}

/// SwiftDataErrors defines a constrained set of related values.
public enum SwiftDataErrors: Error {
    /// Indicates persisted model data is missing required fields or has an unexpected shape.
    case invalidShape
}

/// Lightweight source snapshot for observing and syncing DocC site metadata without loading the local index tree.
public struct DocCSiteSnapshot: Identifiable, Equatable, MYRecordConvertible {
    /// Stable identifier for the persisted site model.
    public let id: UUID
    /// Creation timestamp for this saved site source.
    public let timestamp: Date?
    /// Base URL used to load DocC resources.
    public var url: URL?
    /// Used for restoring access to sandbox-scoped resources on the file system
    public let urlBookmark: Data?
    /// Optional user-facing override name for the source.
    public let overrideName: String?
    
    /// Creates a lightweight sync snapshot from a persisted DocC site model.
    ///
    /// - Parameter site: Persisted site model to observe.
    public init(site: DocCSite) {
        self.id = site.id
        self.timestamp = site.timestamp
        self.url = site.url
        self.urlBookmark = site.urlBookmark
        self.overrideName = site.overrideName
    }

    /// Creates a lightweight snapshot from an in-memory persisted source without copying its index.
    ///
    /// - Parameter source: Persisted source value to summarize.
    public init(source: PersistedDocCSource) {
        self.id = source.id
        self.timestamp = source.timestamp
        self.url = source.url
        self.urlBookmark = source.urlBookmark
        self.overrideName = source.overrideName
    }
    
    /// Converts this snapshot into the persisted-source value used to load remote DocC indexes.
    @MainActor
    public var persistedSource: PersistedDocCSource? {
        guard let timestamp, let url else { return nil }
        
        return PersistedDocCSource(
            id: id,
            timestamp: timestamp,
            url: url,
            urlBookmark: urlBookmark,
            overrideName: overrideName,
            index: DocCIndex(interfaceLanguages: [:])
        )
    }
    
    /// Whether this DocC site should be included in explicit CloudKit sync.
    public var participatesInCloudSync: Bool {
        guard let url else { return true }
        
        return !url.isFileURL
    }
    
    /// Unique CloudKit record identifier for this DocC site.
    public var myRecordID: String { id.uuidString }
    
    /// CloudKit record type used for persisted DocC sites.
    public var myRecordType: String { DocBCloudRecordTypes.docCSite }
    
    /// Root CloudKit group for this site.
    public var myRootGroupID: String? { nil }
    
    /// CloudKit-compatible properties for this persisted DocC site.
    public var myProperties: [String : MYRecordValue] {
        [
            "timestamp": .date(timestamp),
            "url": .string(url?.absoluteString),
            "overrideName": .string(overrideName)
        ]
    }
}

/// Persisted SwiftData model representing a DocC site source.
///
/// Persisted properties are optional to tolerate schema evolution, and `persistedSource` provides validated access for app-layer usage.
@Model
public final class DocCSite: Identifiable {
    /// Stable identifier for the persisted site model.
    public var id: UUID = UUID()
    /// Creation timestamp for this saved site source.
    public var timestamp: Date?
    /// Base URL used to load DocC resources.
    public var url: URL?
    /// Used for restoring access to sandbox-scoped resources on the file system
    public var urlBookmark: Data?
    /// Optional user-facing override name for the source.
    public var overrideName: String?
    /// Compact encoded DocC index used for offline restore without walking the SwiftData relationship tree.
    public var indexData: Data?
    /// Legacy relational index tree kept for existing schema compatibility.
    public var indexV2: DocCIndexModel?
    
    /// Creates a persisted site model from runtime DocC index content.
    public init(timestamp: Date = .init(), url: URL, urlBookmark: Data?, overrideName: String? = nil, index: DocCIndex) {
        self.timestamp = timestamp
        self.url = url
        self.urlBookmark = urlBookmark
        self.overrideName = overrideName
        self.indexData = Self.encodeIndex(index)
        self.indexV2 = nil
    }
    
    /// Internal initializer used when index content is already in model form.
    public init(timestamp: Date = .init(), url: URL, urlBookmark: Data?, overrideName: String? = nil, index: DocCIndexModel) {
        self.timestamp = timestamp
        self.url = url
        self.urlBookmark = urlBookmark
        self.overrideName = overrideName
        self.indexData = nil
        self.indexV2 = index
    }
    
    /// Creates a persisted model from a runtime source snapshot.
    @MainActor public init(_ source: PersistedDocCSource) {
        self.timestamp = source.timestamp
        self.url = source.url
        self.urlBookmark = source.urlBookmark
        self.overrideName = source.overrideName
        self.indexData = Self.encodeIndex(source.index)
        self.indexV2 = nil
    }
    
    /// Converts the persisted model into a source snapshot used by app logic and UI layers.
    ///
    /// This accessor throws when persisted data is malformed or required fields are missing.
    @MainActor public var persistedSource: PersistedDocCSource {
        get throws {
            guard let timestamp, let url, let index = decodedIndex else {
                throw SwiftDataErrors.invalidShape
            }

            return PersistedDocCSource(
                id: id,
                timestamp: timestamp,
                url: url,
                urlBookmark: urlBookmark,
                overrideName: overrideName,
                index: index,
                persistentModelID: persistentModelID
            )
        }
    }

    /// Decodes the compact offline index payload, falling back to the legacy relational index tree.
    public var decodedIndex: DocCIndex? {
        if let indexData,
           let index = try? JSONDecoder().decode(DocCIndex.self, from: indexData) {
            return index
        }

        return indexV2?.asIndex
    }

    /// Encodes an index for compact offline persistence.
    ///
    /// - Parameter index: Runtime index to encode.
    /// - Returns: Encoded index data, or `nil` when encoding fails.
    public static func encodeIndex(_ index: DocCIndex) -> Data? {
        try? JSONEncoder().encode(index)
    }
    
    /// Top-level grouped interface-language entries from the persisted index.
    public var groups: [InterfaceLanguageModel] {
        decodedIndex?.interfaceLanguages.values.flatMap { languages in
            languages.map(InterfaceLanguageModel.init)
        } ?? []
    }
    
    /// Performs a recursive title-based search across persisted interface-language entries.
    ///
    /// - Parameter query: Search text to match against entry titles.
    /// - Returns: `true` when any nested item matches.
    public func hasResultsForSearch(_ query: String) -> Bool {
        guard let decodedIndex else { return false }

        func containsMatch(_ language: DocCIndex.InterfaceLanguage) -> Bool {
            language.title.localizedCaseInsensitiveContains(query) || (language.children ?? []).contains(where: containsMatch)
        }

        for interfaceLanguage in decodedIndex.interfaceLanguages.values.flatMap({ $0 }) where containsMatch(interfaceLanguage) {
            return true
        }
        
        return false
    }
}

extension DocCSite: MYRecordConvertible {
    /// Unique CloudKit record identifier for this DocC site.
    public var myRecordID: String { id.uuidString }
    
    /// CloudKit record type used for persisted DocC sites.
    public var myRecordType: String { DocBCloudRecordTypes.docCSite }
    
    /// Root CloudKit group for this site.
    public var myRootGroupID: String? { nil }
    
    /// CloudKit-compatible properties for this persisted DocC site.
    public var myProperties: [String : MYRecordValue] {
        [
            "timestamp": .date(timestamp),
            "url": .string(url?.absoluteString),
            "overrideName": .string(overrideName)
        ]
    }
    
    /// Whether this DocC site should be included in explicit CloudKit sync.
    public var participatesInCloudSync: Bool {
        guard let url else { return true }
        
        return !url.isFileURL
    }
}

extension [DocCSite] {
    /// Converts persisted site models to lightweight snapshots without loading local DocC indexes.
    public var snapshots: [DocCSiteSnapshot] {
        map(DocCSiteSnapshot.init(site:))
    }
}

extension [DocCSiteSnapshot] {
    /// Converts lightweight site snapshots to persisted source values with empty local indexes.
    @MainActor public var asPersistedDocCSources: [PersistedDocCSource] {
        compactMap(\.persistedSource)
    }
}

extension [DocCSite] {
    /// Converts persisted site models to source snapshots, skipping malformed records.
    @MainActor public var asPersistedDocCSources: [PersistedDocCSource] {
        compactMap({ try? PersistedDocCSource($0) })
    }
    
    /// Converts persisted site models directly to DocCKit runtime sources.
    @MainActor public var asDocCSources: [DocCSource] {
        asPersistedDocCSources.map(\.docCSource)
    }
}

extension EnvironmentValues {
    /// Currently selected custom DocC site context for resolving relative references and assets.
    @Entry public var docCSite: DocCSource?
}

extension DocCSite {
    /// Persisted representation of a DocC index grouped by interface language.
    ///
    /// - Important: Child relationships use cascading deletes to keep nested index trees in sync with their parent index.
    @Model
    public final class DocCIndexModel: Identifiable {
        /// Stable identifier for this persisted index model.
        public var id: UUID = UUID()
        
        /// Parent site relationship that owns this index.
        @Relationship(deleteRule: .nullify, inverse: \DocCSite.indexV2)
        public var site: DocCSite?
        
        /// Grouped interface-language entries keyed by language name.
        public var interfaceLanguages: [InterfaceLanguageSetModel]?
        /// Archive identifiers used to resolve custom image assets.
        public var includedArchiveIdentifiers: [String]?
        
        /// Creates an index model from persisted language-set models.
        ///
        /// - Parameters:
        ///   - interfaceLanguages: Grouped interface-language entries keyed by language name.
        ///   - includedArchiveIdentifiers: Archive identifiers used to resolve custom image assets.
        public init(interfaceLanguages: [InterfaceLanguageSetModel], includedArchiveIdentifiers: [String]? = nil) {
            self.interfaceLanguages = interfaceLanguages
            self.includedArchiveIdentifiers = includedArchiveIdentifiers
        }
        
        /// Creates an index model from runtime DocC index payload.
        public init(_ index: DocCIndex) {
            self.interfaceLanguages = index.interfaceLanguages.map({ InterfaceLanguageSetModel(name: $0.key, languages: $0.value) })
            self.includedArchiveIdentifiers = index.includedArchiveIdentifiers
        }
        
        /// Reconstructs the runtime `DocCIndex` value from persisted model data.
        public var asIndex: DocCIndex {
            let interfaceLanguages = (interfaceLanguages ?? []).reduce(into: [String: [DocCIndex.InterfaceLanguage]]()) { acc, set in
                guard let name = set.name, let languages = set.languages else { return }
                acc[name] = languages.map({ $0.asInterfaceLanguage })
            }
            
            return DocCIndex(id: id, interfaceLanguages: interfaceLanguages, includedArchiveIdentifiers: includedArchiveIdentifiers)
        }
    }
    
    /// Named set of interface-language entries for a single language key (for example, Swift).
    @Model
    public final class InterfaceLanguageSetModel: Identifiable {
        /// Stable identifier for this language-set record.
        public var id = UUID()
        /// Language key (for example `swift`) associated with this set.
        public var name: String?
        /// Persisted entries for this language key.
        public var languages: [InterfaceLanguageModel]?
        
        /// Parent index relationship that owns this language set.
        @Relationship(deleteRule: .cascade, inverse: \DocCIndexModel.interfaceLanguages)
        public var index: DocCIndexModel?
        
        /// Creates a language-set model from explicit persisted fields.
        public init(name: String? = nil, languages: [InterfaceLanguageModel]? = nil) {
            self.name = name
            self.languages = languages
        }
        
        /// Creates a language-set model from runtime interface-language entries.
        public init(name: String, languages: [DocCIndex.InterfaceLanguage]) {
            self.name = name
            self.languages = languages.map({ InterfaceLanguageModel($0) })
        }
    }
    
    /// Persisted tree node for a DocC interface-language entry.
    @Model
    public final class InterfaceLanguageModel: Identifiable {
        /// Stable identifier for this interface-language node.
        public var id = UUID()
        
        /// Display title for the node.
        public var title: String?
        /// Optional documentation path used for navigation.
        public var path: String?
        /// Node type metadata (module, symbol, etc.).
        public var type: String?
        /// Optional custom icon identifier for this node.
        public var icon: String?
        
        /// Owning language-set relationship for root nodes.
        @Relationship(deleteRule: .cascade, inverse: \InterfaceLanguageSetModel.languages)
        private var set: InterfaceLanguageSetModel?
        
        // parent relationship
        /// Parent node relationship for nested interface-language entries.
        @Relationship(deleteRule: .cascade, inverse: \InterfaceLanguageModel.children)
        public var parent: InterfaceLanguageModel?
        
        /// Child nodes representing nested documentation hierarchy.
        public fileprivate(set) var children: [InterfaceLanguageModel]?
        
        /// Creates a persisted interface-language node from explicit fields.
        ///   - icon: Optional custom icon identifier for this node.
        public init(title: String?, path: String? = nil, type: String?, icon: String? = nil, children: [InterfaceLanguageModel]) {
            self.title = title
            self.path = path
            self.type = type
            self.icon = icon
            self.children = children
        }
        
        /// Creates a persisted interface-language node from runtime index payload.
        public init(_ language: DocCIndex.InterfaceLanguage) {
            self.title = language.title
            self.path = language.path
            self.type = language.type
            self.icon = language.icon
            
            if let children = language.children {
                let models = children.map { child in
                    let model = InterfaceLanguageModel(child)
                    model.parent = self
                    
                    return model
                }
                self.children = models
            }
        }
        
        /// Reconstructs the runtime interface-language value, including recursive children.
        public var asInterfaceLanguage: DocCIndex.InterfaceLanguage {
            let children: [DocCIndex.InterfaceLanguage]? = self.children?.map({ $0.asInterfaceLanguage })
            
            return DocCIndex.InterfaceLanguage(title: title ?? "Unknown", path: path, type: type ?? "Unknown", icon: icon, children: children)
        }
        
        /// Recursively checks whether this entry or descendants match the search query.
        ///
        /// - Parameter query: Search text to compare with entry titles.
        /// - Returns: `true` if this entry or any descendant matches.
        public func hasResultsForSearch(_ query: String) -> Bool {
            if title?.lowercased().contains(query.lowercased()) == true && type?.lowercased() != "module" {
                return true
            }
            
            guard let children else { return false }
            
            return children.first(where: { $0.hasResultsForSearch(query) }) != nil
        }
        
        /// Returns the owning language set by walking parent links when needed.
        ///
        /// - Returns: The nearest `InterfaceLanguageSetModel` in the ancestry chain.
        @MainActor
        public func getSet() throws -> InterfaceLanguageSetModel? {
            if let set {
                return set
            }
            
            return try self.parent?.getSet()
        }
    }
}
