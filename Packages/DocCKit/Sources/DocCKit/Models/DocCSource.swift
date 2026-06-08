import Foundation

/// A DocC documentation source that can resolve relative documentation assets and index entries.
public struct DocCSource: Identifiable, Codable, Equatable, Hashable, Sendable {
    /// Stable identifier used for equality and identity in collections.
    public let id: UUID
    /// Timestamp indicating when the source was added.
    public let timestamp: Date
    /// Optional override display name for the source.
    public let overrideName: String?
    /// Root URL for the DocC site.
    public let url: URL
    /// Parsed index describing available interface-language groups and entries.
    public private(set) var index: DocCIndex
    
    /// Creates an in-memory DocC source.
    ///
    /// - Parameters:
    ///   - id: Stable source identifier.
    ///   - timestamp: Date when this source was added or discovered.
    ///   - url: Root URL for the DocC site.
    ///   - overrideName: Optional display-name override.
    ///   - index: Parsed DocC index for the source.
    public init(id: UUID = UUID(), timestamp: Date = .init(), url: URL, overrideName: String? = nil, index: DocCIndex) {
        self.id = id
        self.timestamp = timestamp
        self.url = url
        self.overrideName = overrideName
        self.index = index
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.url = try container.decode(URL.self, forKey: .url)
        self.overrideName = try container.decodeIfPresent(String.self, forKey: .overrideName)
        self.index = try container.decode(DocCIndex.self, forKey: .index)
    }
    
    /// Updates the source index when a fresh remote index payload is loaded.
    ///
    /// - Parameter index: New index payload for the source.
    public mutating func setIndex(_ index: DocCIndex) {
        self.index = index
    }
    
    /// Coding keys for source serialization.
    public enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case url
        case overrideName
        case index
    }
    
    /// Top-level interface-language groups flattened from the source index.
    public var groups: [DocCIndex.InterfaceLanguage] {
        index.interfaceLanguages.flatMap { $0.value }
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
        
        let languages = index.interfaceLanguages.filter {
            $0.value.contains { $0.path == path } ||
            $0.value.flatMap { $0.children ?? [] }.contains { $0.path == interfaceLanguage.path ?? "" }
        }.map(\.key)
        
        return AppleTechnologies.FrameworkSection(
            languages: languages,
            title: interfaceLanguage.title,
            tags: [],
            destination: .init(type: "", isActive: true, identifier: path),
            legalNotices: nil,
            docCSite: self,
            index: nil
        )
    }
}
