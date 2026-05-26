import Foundation
import Observation
import DocCKit

/// Flattened sidebar search index used to keep keystroke matching off the main actor.
public struct SidebarSearchIndex: Sendable {
    /// Maximum number of rows published for a single sidebar query.
    public static let defaultResultLimit = 250
    
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
    
    /// Creates a sidebar search index from loaded technology snapshots.
    ///
    /// - Parameter technologies: Runtime technology sources from `DocumentationViewModel`.
    public init(technologies: [TechnologyTypes]) {
        let docCSites = technologies.docCSites.sorted { lhs, rhs in
            lhs.timestamp < rhs.timestamp
        }
        var entries: [Entry] = []
        
        for site in docCSites {
            let source = Source(
                id: "docc-\(site.id.uuidString)",
                title: site.overrideName ?? site.groups.first?.title ?? "Unknown"
            )
            Self.appendDocCEntries(from: site, source: source, to: &entries)
        }
        
        for appleTechnologies in technologies.appleTechnologies {
            let source = Source(id: "apple-\(appleTechnologies.id.uuidString)", title: "Apple Documentation")
            entries.append(.init(
                id: "\(source.id)-homepage",
                source: source,
                title: "Discover",
                normalizedTitle: Self.normalize("Discover"),
                normalizedTags: [],
                row: .homepage(id: "\(source.id)-homepage", title: "Discover")
            ))
            
            for group in appleTechnologies.groups ?? [] {
                for framework in group.technologies where framework.destination.isActive {
                    entries.append(.init(
                        id: "\(source.id)-\(framework.destination.identifier)",
                        source: source,
                        title: framework.title,
                        normalizedTitle: Self.normalize(framework.title),
                        normalizedTags: framework.tags.map(Self.normalize),
                        row: .technology(.init(
                            id: "\(source.id)-\(framework.destination.identifier)",
                            title: framework.title,
                            framework: framework,
                            badgeReference: appleTechnologies.references[framework.destination.identifier]
                        ))
                    ))
                }
            }
        }
        
        self.init(id: UUID(), entries: entries)
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
        
        var sections: [SidebarSearchResultSection] = []
        var sectionIndexesBySourceID: [String: Int] = [:]
        var totalMatches = 0
        let resultLimit = max(0, limit)
        
        for entry in entries where entry.matches(normalizedQuery) {
            totalMatches += 1
            guard totalMatches <= resultLimit else {
                continue
            }
            
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
            totalMatches: totalMatches,
            isTruncated: totalMatches > resultLimit
        )
    }
    
    /// Creates an index from a prebuilt entry array.
    ///
    /// - Parameters:
    ///   - id: Snapshot identity.
    ///   - entries: Flattened searchable entries.
    private init(id: UUID, entries: [Entry]) {
        self.id = id
        self.entries = entries
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
        to entries: inout [Entry]
    ) {
        func append(_ interfaceLanguage: DocCIndex.InterfaceLanguage, languageKey: String) {
            if interfaceLanguage.type.lowercased() != "module", let path = interfaceLanguage.path {
                let id = "\(source.id)-\(languageKey)-\(path)"
                let symbolKind = SidebarSearchSymbolKind(interfaceLanguage: interfaceLanguage)
                entries.append(.init(
                    id: id,
                    source: source,
                    title: interfaceLanguage.title,
                    normalizedTitle: normalize(interfaceLanguage.title),
                    normalizedTags: [],
                    row: .reference(.init(
                        id: id,
                        title: interfaceLanguage.title,
                        path: path,
                        type: interfaceLanguage.type,
                        symbolKind: symbolKind,
                        site: site
                    ))
                ))
            }
            
            for child in interfaceLanguage.children ?? [] {
                append(child, languageKey: languageKey)
            }
        }
        
        for languageKey in site.index.interfaceLanguages.keys.sorted() {
            for language in site.index.interfaceLanguages[languageKey] ?? [] {
                append(language, languageKey: languageKey)
            }
        }
    }
    
    /// Pre-normalized searchable row.
    private struct Entry: Sendable {
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
        /// UI row payload.
        let row: SidebarSearchResultRow
        
        /// Returns whether this entry matches a normalized query.
        ///
        /// - Parameter normalizedQuery: Query already passed through `normalize(_:)`.
        /// - Returns: `true` when the title or any tag contains the query.
        func matches(_ normalizedQuery: String) -> Bool {
            normalizedTitle.contains(normalizedQuery) || normalizedTags.contains { $0.contains(normalizedQuery) }
        }
    }
    
    /// Search result source grouping metadata.
    private struct Source: Sendable {
        /// Stable source identifier.
        let id: String
        /// Display title.
        let title: String
    }
}

/// Grouped sidebar search result set.
public struct SidebarSearchResults: Sendable {
    /// Empty result set.
    public static let empty = SidebarSearchResults(sections: [], totalMatches: 0, isTruncated: false)
    
    /// Grouped result sections.
    public var sections: [SidebarSearchResultSection]
    /// Total matches before row limiting.
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
    ///   - totalMatches: Total matches before row limiting.
    ///   - isTruncated: Whether rows were omitted because the result limit was reached.
    public init(sections: [SidebarSearchResultSection], totalMatches: Int, isTruncated: Bool) {
        self.sections = sections
        self.totalMatches = totalMatches
        self.isTruncated = isTruncated
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
public enum SidebarSearchResultRow: Identifiable, Sendable {
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
}

/// DocC reference result payload.
public struct SidebarSearchReferenceResult: Identifiable, Sendable {
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
    /// Owning custom DocC source.
    public let site: DocCSource
    
    /// Creates a DocC reference search result.
    ///
    /// - Parameters:
    ///   - id: Stable row identifier.
    ///   - title: Display title.
    ///   - path: Relative DocC path.
    ///   - type: Node type metadata.
    ///   - symbolKind: Best-effort Xcode documentation symbol badge kind.
    ///   - site: Owning custom DocC source.
    public init(
        id: String,
        title: String,
        path: String,
        type: String,
        symbolKind: SidebarSearchSymbolKind? = nil,
        site: DocCSource
    ) {
        self.id = id
        self.title = title
        self.path = path
        self.type = type
        self.symbolKind = symbolKind ?? SidebarSearchSymbolKind(title: title, path: path, type: type)
        self.site = site
    }
    
    /// Creates a navigation reference for the active deep-link scheme.
    ///
    /// - Parameter deepLinkScheme: Scheme used by the app for DocC navigation.
    /// - Returns: A reference suitable for `ReferenceNavigationLinkButton`.
    public func reference(deepLinkScheme: DocCDeepLinkScheme) -> Reference {
        Reference(
            title: title,
            identifier: "\(deepLinkScheme.urlPrefix)nav\(path)",
            type: type,
            docCSite: site
        )
    }
}

/// Xcode documentation-style symbol categories used by search result badges.
public enum SidebarSearchSymbolKind: String, Sendable {
    case article
    case classSymbol
    case collection
    case collectionGroup
    case enumeration
    case enumerationCase
    case framework
    case function
    case initializer
    case macro
    case method
    case property
    case protocolSymbol
    case structure
    case typeAlias
    case variable
    case unknown

    /// Creates a symbol kind from a DocC index node.
    ///
    /// - Parameter interfaceLanguage: DocC index node to classify.
    public init(interfaceLanguage: DocCIndex.InterfaceLanguage) {
        self.init(
            title: interfaceLanguage.title,
            path: interfaceLanguage.path,
            type: interfaceLanguage.type
        )
    }

    /// Creates a symbol kind from the metadata available in DocC indexes.
    ///
    /// - Parameters:
    ///   - title: Display title.
    ///   - path: Optional documentation path.
    ///   - type: DocC node type.
    public init(title: String, path: String?, type: String) {
        let role = Role(rawValue: type)

        switch role {
        case .collection:
            self = .collection
            return
        case .collectionGroup:
            self = .collectionGroup
            return
        case .framework:
            self = .framework
            return
        case .article, .overview, .sampleCode, .task, .subsection, .codeListing, .link:
            self = .article
            return
        case .dictionarySymbol:
            self = .typeAlias
            return
        default:
            break
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercasedTitle = trimmedTitle.lowercased()
        let pathComponents = path?.split(separator: "/").map(String.init) ?? []
        let lastPathComponent = pathComponents.last?.lowercased() ?? ""

        if lowercasedTitle.hasPrefix("init(") || lowercasedTitle == "init" {
            self = .initializer
        } else if trimmedTitle.contains("(") {
            self = pathComponents.count <= 3 ? .function : .method
        } else if lowercasedTitle.hasPrefix("case ") || lastPathComponent.hasPrefix("case-") {
            self = .enumerationCase
        } else if lowercasedTitle.hasSuffix("protocol") {
            self = .protocolSymbol
        } else if lowercasedTitle.hasSuffix("controller") || lowercasedTitle.hasSuffix("viewcontroller") {
            self = .classSymbol
        } else if lowercasedTitle.hasSuffix("phase") || lowercasedTitle.hasSuffix("style") || lowercasedTitle.hasSuffix("mode") {
            self = .enumeration
        } else if trimmedTitle.first?.isUppercase == true {
            self = .structure
        } else {
            self = .property
        }
    }

    /// Creates a symbol kind from article metadata when a full DocC page is available.
    ///
    /// - Parameter roleHeading: Human-readable DocC role heading, such as `Enumeration` or `Initializer`.
    public init?(roleHeading: String?) {
        guard let normalizedRoleHeading = roleHeading?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              !normalizedRoleHeading.isEmpty
        else {
            return nil
        }

        switch normalizedRoleHeading {
        case "article", "overview", "sample code":
            self = .article
        case "class":
            self = .classSymbol
        case "collection":
            self = .collection
        case "collection group":
            self = .collectionGroup
        case "enumeration", "enum":
            self = .enumeration
        case "case", "enumeration case":
            self = .enumerationCase
        case "framework":
            self = .framework
        case "function", "operator":
            self = .function
        case "initializer", "init":
            self = .initializer
        case "macro":
            self = .macro
        case "method", "instance method", "type method", "static method":
            self = .method
        case "property", "instance property", "type property", "static property":
            self = .property
        case "protocol":
            self = .protocolSymbol
        case "structure", "struct":
            self = .structure
        case "type alias", "typealias", "associated type":
            self = .typeAlias
        case "variable", "constant":
            self = .variable
        default:
            return nil
        }
    }
}

/// Apple framework result payload.
public struct SidebarSearchTechnologyResult: Identifiable, Sendable {
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
    /// Latest raw search text received from the sidebar field.
    public private(set) var rawSearchText = ""
    /// Current visible search results.
    public private(set) var results = SidebarSearchResults.empty
    /// Whether a query task is waiting or computing.
    public private(set) var isSearching = false
    /// Whether a fresh index snapshot is being built.
    public private(set) var isRebuildingIndex = false
    /// Number of installed index snapshots, used by tests to guard against query-time rebuilds.
    public private(set) var indexBuildCount = 0
    
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
    public func rebuildIndex(technologies: [TechnologyTypes], searchText: String) {
        rawSearchText = searchText
        indexBuildTask?.cancel()
        let requestID = UUID()
        indexBuildRequestID = requestID
        isRebuildingIndex = true
        
        indexBuildTask = Task(priority: .utility) {
            let index = await Task.detached(priority: .utility) {
                SidebarSearchIndex(technologies: technologies)
            }.value
            
            await MainActor.run {
                guard self.indexBuildRequestID == requestID else { return }
                
                self.installIndex(index)
            }
        }
    }
    
    /// Installs an already-built index.
    ///
    /// - Parameter index: Search index snapshot to publish.
    public func installIndex(_ index: SidebarSearchIndex) {
        searchTask?.cancel()
        indexBuildTask?.cancel()
        searchRequestID = UUID()
        indexBuildRequestID = UUID()
        self.index = index
        isRebuildingIndex = false
        indexBuildCount += 1
        updateSearchText(rawSearchText)
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
