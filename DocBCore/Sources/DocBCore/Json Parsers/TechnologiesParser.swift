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
    var url: URL {
        switch self {
        case .apple(let appleTechnologies):
            return URL(string: Constants.aDeveloperURLBase)!
        case .docC(let docCSiteDTO):
            return docCSiteDTO.url
        }
    }
    
    /// Whether this value represents a custom DocC site.
    var isDocC: Bool {
        switch self {
        case .apple:
            return false
        case .docC:
            return true
        }
    }
    
    /// Whether this value represents Apple Developer Documentation.
    var isApple: Bool {
        switch self {
        case .apple:
            return true
        case .docC:
            return false
        }
    }
    
    /// Display names for technology grouping in the UI.
    @MainActor
    var names: [String] {
        switch self {
        case .apple:
            return ["Apple Developer Documentation"]
        case .docC(let docC):
            return docC.groups.map(\.title)
        }
    }
    
    /// Preferred primary display name for this technology source.
    @MainActor
    var primaryName: String {
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
    var docCSites: [DocCSiteDTO] {
        compactMap { tech in
            switch tech {
            case .apple: return nil
            case .docC(let docC): return docC
            }
        }
    }
    /// Apple technology values extracted from mixed technology arrays.
    var appleTechnologies: [AppleTechnologies] {
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
    let header: Header?
    /// Grouped technology sections.
    let groups: [Technology]?
    /// Reference metadata keyed by identifier.
    let references: [String : Reference]
    /// Optional legal notices payload.
    let legalNotices: LegalNotices?
    
    /// Coding keys used for decoding shared section payloads.
    enum CodingKeys: CodingKey {
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
    struct CommonTechnologiesSection: Codable {
        let kind: String
        
        // Header
        let backgroundImage: String?
        let image: String?
        let title: String?
        
        // Technology
        let groups: [Technology]?
    }
    
    /// Hero/header metadata shown at the top of the Apple technologies page.
    struct Header: Codable, Equatable, Hashable {
        let backgroundImage: String
        let image: String
        let title: String
        let kind: String
    }
    
    @CodableIgnoreInitializedProperties
    /// Group of related frameworks under a single technology name.
    struct Technology: Codable, Identifiable, Hashable, Equatable, Sendable {
        /// Stable identifier for diffable/UI usage.
        let id = UUID()
        
        /// Group display name.
        let name: String
        /// Framework entries in this group.
        let technologies: [FrameworkSection]
    }
    
    @CodableIgnoreInitializedProperties
    /// Framework entry used for navigation from technology lists.
    struct FrameworkSection: Codable, Identifiable, AppleDocumentation {
        /// Stable identifier for diffable/UI usage.
        let id = UUID()
        
        /// Supported interface languages for this framework.
        let languages: [String]
        /// Framework display title.
        let title: String
        /// Tag metadata for filtering/grouping.
        let tags: [String]
        /// Navigation destination metadata.
        let destination: Destination
        /// Optional legal notices payload.
        let legalNotices: LegalNotices?
        /// Optional custom DocC site context.
        let docCSite: DocCSiteDTO?
        
        /// Path-based equality for framework sections to avoid identifier host differences.
        func isEqual(to framework: FrameworkSection) -> Bool {
            guard let currentUrl = URL(string: destination.identifier),
                  let url = URL(string: framework.destination.identifier)
            else {
                return destination.identifier.lowercased() == framework.destination.identifier.lowercased()
            }
            
            return currentUrl.path().lowercased() == url.path().lowercased()
        }
        
        /// Destination metadata for a framework entry.
        struct Destination: Codable, Hashable {
            /// Destination type discriminator.
            let type: String
            /// Whether destination is currently active.
            let isActive: Bool
            /// Canonical destination identifier.
            let identifier: String
        }
        
        /// Synthetic reference representing this framework section in list UIs.
        var frameworkReference: Reference {
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
