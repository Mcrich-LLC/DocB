//
//  TechnologiesParser.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/5/24.
//

import Foundation
import EnhancedCodable

/// Unified technology source type representing Apple-hosted and custom DocC providers.
public enum TechnologyTypes: Identifiable, Equatable, Sendable {
    case apple(AppleTechnologies)
    case docC(DocCSiteDTO)
    
    /// Stable identifier for the underlying technology payload.
    public var id: UUID {
        switch self {
        case .apple(let apple):
            return apple.id
        case .docC(let docC):
            return docC.id
        }
    }
    
    /// Base URL for this technology source.
    public var url: URL {
        switch self {
        case .apple:
            return URL(string: Constants.aDeveloperURLBase)!
        case .docC(let docCSiteDTO):
            return docCSiteDTO.url
        }
    }
    
    /// Whether this value represents a custom DocC site.
    public var isDocC: Bool {
        switch self {
        case .apple:
            return false
        case .docC:
            return true
        }
    }
    
    /// Whether this value represents Apple Developer Documentation.
    public var isApple: Bool {
        switch self {
        case .apple:
            return true
        case .docC:
            return false
        }
    }
    
    /// Display names for technology grouping in the UI.
    @MainActor
    public var names: [String] {
        switch self {
        case .apple:
            return ["Apple Developer Documentation"]
        case .docC(let docC):
            return docC.groups.map(\.title)
        }
    }
    
    /// Preferred primary display name for this technology source.
    @MainActor
    public var primaryName: String {
        switch self {
        case .apple:
            return "Apple Developer Documentation"
        case .docC(let docC):
            return docC.overrideName ?? docC.groups.filter({ $0.type.lowercased() == "module" }).map(\.title).first ?? "Unknown"
        }
    }
}

extension [TechnologyTypes] {
    /// Custom DocC site values extracted from mixed technology arrays.
    public var docCSites: [DocCSiteDTO] {
        compactMap { tech in
            switch tech {
            case .apple: return nil
            case .docC(let docC): return docC
            }
        }
    }
    /// Apple technology values extracted from mixed technology arrays.
    public var appleTechnologies: [AppleTechnologies] {
        compactMap { tech in
            switch tech {
            case .apple(let apple): return apple
            case .docC: return nil
            }
        }
    }
}

/// Decoded Apple technologies payload used to build homepage and framework navigation.
public struct AppleTechnologies: Decodable, AppleDocumentation, Identifiable, Sendable {
    /// Stable identifier for diffable/UI usage.
    public let id = UUID()
    
    /// Optional hero/header section metadata.
    public let header: Header?
    /// Grouped technology sections.
    public let groups: [Technology]?
    /// Reference metadata keyed by identifier.
    public let references: [String : Reference]
    /// Optional legal notices payload.
    public let legalNotices: LegalNotices?
    
    /// Coding keys used for decoding shared section payloads.
    public enum CodingKeys: CodingKey {
        case sections, legalNotices, references
    }
    
    /// Decodes Apple technologies by extracting hero and technology sections from the shared sections array.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.legalNotices = try container.decodeIfPresent(LegalNotices.self, forKey: .legalNotices)
        self.references = try container.decode([String : Reference].self, forKey: .references)
        let sectionsArray = try container.decode([CommonTechnologiesSection].self, forKey: .sections)
        
        if let header = sectionsArray.first(where: { $0.kind == "hero" }), let backgroundImage = header.backgroundImage, let image = header.image, let title = header.title {
            self.header = .init(backgroundImage: backgroundImage, image: image, title: title, kind: header.kind)
        } else {
            self.header = nil
        }
        
        if let technologiesSection = sectionsArray.first(where: { $0.kind == "technologies" }) {
            self.groups = technologiesSection.groups
        } else {
            self.groups = nil
        }
    }
    
    /// Raw section model used to decode mixed section content before normalization.
    public struct CommonTechnologiesSection: Codable {
        public let kind: String
        
        // Header
        public let backgroundImage: String?
        public let image: String?
        public let title: String?
        
        // Technology
        public let groups: [Technology]?
    }
    
    /// Hero/header metadata shown at the top of the Apple technologies page.
    public struct Header: Codable, Equatable, Hashable, Sendable {
        public let backgroundImage: String
        public let image: String
        public let title: String
        public let kind: String
    }
    
    /// Group of related frameworks under a single technology name.
    @CodableIgnoreInitializedProperties
    public struct Technology: Codable, Identifiable, Hashable, Equatable, Sendable {
        /// Stable identifier for diffable/UI usage.
        public let id = UUID()
        
        /// Group display name.
        public let name: String
        /// Framework entries in this group.
        public let technologies: [FrameworkSection]
    }
    
    /// Framework entry used for navigation from technology lists.
    @CodableIgnoreInitializedProperties
    public struct FrameworkSection: Codable, Identifiable, AppleDocumentation, Sendable {
        /// Stable identifier for diffable/UI usage.
        public let id = UUID()
        
        /// Supported interface languages for this framework.
        public let languages: [String]
        /// Framework display title.
        public let title: String
        /// Tag metadata for filtering/grouping.
        public let tags: [String]
        /// Navigation destination metadata.
        public let destination: Destination
        /// Optional legal notices payload.
        public let legalNotices: LegalNotices?
        /// Optional custom DocC site context.
        public let docCSite: DocCSiteDTO?
        
        /// Path-based equality for framework sections to avoid identifier host differences.
        public func isEqual(to framework: FrameworkSection) -> Bool {
            guard let currentUrl = URL(string: destination.identifier),
                  let url = URL(string: framework.destination.identifier)
            else {
                return destination.identifier.lowercased() == framework.destination.identifier.lowercased()
            }
            
            return currentUrl.path().lowercased() == url.path().lowercased()
        }
        
        /// Destination metadata for a framework entry.
        public struct Destination: Codable, Hashable, Sendable {
            /// Destination type discriminator.
            public let type: String
            /// Whether destination is currently active.
            public let isActive: Bool
            /// Canonical destination identifier.
            public let identifier: String
        }
        
        /// Synthetic reference representing this framework section in list UIs.
        public var frameworkReference: Reference {
            Reference(
                title: title,
                abstract: nil,
                identifier: destination.identifier,
                kind: nil,
                type: "",
                url: nil,
                role: nil,
                fragments: nil,
                deprecated: nil,
                beta: nil,
                variants: nil,
                images: nil,
                docCSite: docCSite
            )
        }
    }
}
