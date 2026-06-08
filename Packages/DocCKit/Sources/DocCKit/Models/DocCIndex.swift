//
//  DocC Index Parser.swift
//  DocB
//
//  Created by Morris Richman on 1/3/25.
//

import Foundation
import EnhancedCodable

/// Top-level DocC index payload describing available interface-language trees.
public struct DocCIndex: Codable, Identifiable, Equatable, Hashable, Sendable {
    /// Stable identifier for diffable/UI usage.
    public let id: UUID
    
    /// Interface-language entries keyed by language token (for example, `swift`).
    public let interfaceLanguages: [String : [InterfaceLanguage]]
    /// Archive identifiers used to resolve custom image assets.
    public let includedArchiveIdentifiers: [String]?
    
    /// Creates a DocC index from grouped interface-language entries.
    ///
    /// - Parameters:
    ///   - id: Stable identifier for diffable/UI usage and cache identity.
    ///   - interfaceLanguages: Interface-language entries keyed by language token.
    ///   - includedArchiveIdentifiers: Archive identifiers used to resolve custom image assets.
    public init(
        id: UUID = UUID(),
        interfaceLanguages: [String : [InterfaceLanguage]],
        includedArchiveIdentifiers: [String]? = nil
    ) {
        self.id = id
        self.interfaceLanguages = interfaceLanguages
        self.includedArchiveIdentifiers = includedArchiveIdentifiers
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.interfaceLanguages = try container.decode([String : [InterfaceLanguage]].self, forKey: .interfaceLanguages)
        self.includedArchiveIdentifiers = try container.decodeIfPresent([String].self, forKey: .includedArchiveIdentifiers)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(interfaceLanguages, forKey: .interfaceLanguages)
        try container.encodeIfPresent(includedArchiveIdentifiers, forKey: .includedArchiveIdentifiers)
    }
    
    public static func == (lhs: DocCIndex, rhs: DocCIndex) -> Bool {
        lhs.interfaceLanguages == rhs.interfaceLanguages &&
        lhs.includedArchiveIdentifiers == rhs.includedArchiveIdentifiers
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(interfaceLanguages)
        hasher.combine(includedArchiveIdentifiers)
    }

    /// Coding keys for stable index serialization.
    public enum CodingKeys: String, CodingKey {
        case id
        case interfaceLanguages
        case includedArchiveIdentifiers
    }

    /// Indicates whether the index has any searchable interface-language entries.
    public var isSearchIndexEmpty: Bool {
        interfaceLanguages.values.allSatisfy(\.isEmpty)
    }
    
    /// A node in a DocC index tree representing modules, frameworks, and related groups.
    @CodableIgnoreInitializedProperties
    public struct InterfaceLanguage: Codable, Identifiable, Equatable, Hashable, Sendable {
        /// Stable identifier for diffable/UI usage.
        public let id = UUID()
        
        /// Display title for this index node.
        public let title: String
        /// Relative documentation path for this node.
        public let path: String?
        /// Node type discriminator (for example `module`, `framework`, `sampleCode`).
        public let type: String
        /// Optional custom icon identifier for this index node.
        public let icon: String?
        /// Optional boolean describing if the element is marked as beta
        public let beta: Bool?
        /// A boolean that describes if the element is marked as beta
        public var isBeta: Bool { beta ?? false }
        /// Optional boolean describing if an element is marked as deprecated
        public let deprecated: Bool?
        /// A boolean that describes if the element is marked as deprecated
        public var isDeprecated: Bool { deprecated ?? false }
        
        /// Child index nodes nested under this node.
        public fileprivate(set) var children: [InterfaceLanguage]?
        
        /// Creates an interface-language index node.
        ///
        /// - Parameters:
        ///   - title: Display title for this index node.
        ///   - path: Relative documentation path for this node.
        ///   - type: Node type discriminator.
        ///   - icon: Optional custom icon identifier for this index node.
        ///   - children: Child index nodes nested under this node.
        public init(title: String, path: String?, type: String, icon: String? = nil, beta: Bool? = nil, deprecated: Bool? = nil, children: [InterfaceLanguage]? = nil) {
            self.title = title
            self.path = path
            self.type = type
            self.icon = icon
            self.beta = beta
            self.deprecated = deprecated
            self.children = children
        }
        
        /// Recursively flattened descendant nodes.
        public var allChildren: [InterfaceLanguage] {
            (children ?? []) + (children?.flatMap(\.allChildren) ?? [])
        }
        
        public static func == (lhs: InterfaceLanguage, rhs: InterfaceLanguage) -> Bool {
            lhs.title == rhs.title &&
            lhs.path == rhs.path &&
            lhs.type == rhs.type &&
            lhs.icon == rhs.icon &&
            lhs.beta == rhs.beta &&
            lhs.deprecated == rhs.deprecated &&
            lhs.children == rhs.children
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(title)
            hasher.combine(path)
            hasher.combine(type)
            hasher.combine(icon)
            hasher.combine(beta)
            hasher.combine(deprecated)
            hasher.combine(children)
        }
        
        /// Converts immediate children into framework sections.
        ///
        /// - Parameter site: Site context used to associate generated sections.
        /// - Returns: Framework sections for child entries that contain valid paths.
        public func allFrameworkSections(for site: DocCSource) -> [AppleTechnologies.FrameworkSection] {
            children?.compactMap { frameworkSection(for: $0, site: site) } ?? []
        }
        
        /// Converts an index entry into a framework section for navigation.
        ///
        /// - Parameters:
        ///   - interfaceLanguage: Source index entry.
        ///   - site: Site context to attach to the section.
        /// - Returns: A framework section if the source has a path; otherwise `nil`.
        public func frameworkSection(for interfaceLanguage: DocCIndex.InterfaceLanguage, site: DocCSource) -> AppleTechnologies.FrameworkSection? {
//            let languages = self.index.interfaceLanguages.filter({
//                $0.value.contains(where: { $0.path == interfaceLanguage.path ?? "" }) || $0.value.flatMap { $0.children ?? [] }.contains(where: { $0.path == interfaceLanguage.path ?? "" })
//            }).map(\.key)
            
            guard let path = interfaceLanguage.path else { return nil }
            
            return AppleTechnologies.FrameworkSection(
                languages: [],
                title: interfaceLanguage.title,
                tags: [],
                destination: .init(type: "",
                isActive: true,
                identifier: path),
                legalNotices: nil,
                docCSite: site,
                index: nil
            )
        }
    }
}

extension DocCSource {
    /// Returns grouped entries excluding sample code containers and sample code children.
    public var nonSampleCodeGroups: [DocCIndex.InterfaceLanguage] {
        let groups = groups.filter({ $0.type != "sampleCode" }).map({ group in
            var group = group
            group.children = group.children?.filter({ $0.type != "sampleCode" })
            return group
        }).filter({ $0.children?.isEmpty == false })
        
        return groups
    }
}
