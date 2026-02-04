//
//  TechnologiesParser.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/5/24.
//

import Foundation
import EnhancedCodable

/// Enum representing different types of technology documentation sources.
enum TechnologyTypes: Identifiable, Equatable, Sendable {
    /// Documentation from Apple's official source.
    case apple(AppleTechnologies)
    /// Documentation from a hosted DocC site.
    case docC(DocCSiteDTO)
    
    /// The unique identifier for the technology source.
    var id: UUID {
        switch self {
        case .apple(let apple):
            return apple.id
        case .docC(let docC):
            return docC.id
        }
    }
    
    /// Indicates if the source is a DocC site.
    var isDocC: Bool {
        switch self {
        case .apple:
            return false
        case .docC:
            return true
        }
    }
}

/// A structure representing Apple's technology documentation index.
struct AppleTechnologies: Decodable, AppleDocumentation, Identifiable, Sendable {
    /// The unique identifier.
    let id = UUID()
    
    /// The header information for the technology page.
    let header: Header?
    /// The groups of technologies available.
    let groups: [Technology]?
    /// References to other symbols.
    let references: [String : Reference]
    /// Legal notices.
    let legalNotices: LegalNotices?
    
    enum CodingKeys: CodingKey {
        case sections, legalNotices, references
    }
    
    init(from decoder: any Decoder) throws {
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
    
    /// A common section structure used in the technologies JSON.
    struct CommonTechnologiesSection: Codable {
        /// The kind of section.
        let kind: String
        
        // MARK: Header
        /// The background image URL.
        let backgroundImage: String?
        /// The image URL.
        let image: String?
        /// The title of the section.
        let title: String?
        
        // MARK: Technology
        /// The groups of technologies in this section.
        let groups: [Technology]?
    }
    
    /// The header details for the technology page.
    struct Header: Codable, Equatable, Hashable {
        /// The background image.
        let backgroundImage: String
        /// The main image.
        let image: String
        /// The title.
        let title: String
        /// The kind of header.
        let kind: String
    }
    
    /// A specific technology group (e.g., "Platforms", "Tools").
    @CodableIgnoreInitializedProperties
    struct Technology: Codable, Identifiable, Hashable, Equatable, Sendable {
        /// The unique identifier for the technology group.
        let id = UUID()
        
        /// The name of the technology group.
        let name: String
        /// The list of specific technology frameworks in this group.
        let technologies: [FrameworkSection]
    }
    
    /// A section representing a specific framework or technology.
    @CodableIgnoreInitializedProperties
    struct FrameworkSection: Codable, Identifiable, AppleDocumentation {
        /// The unique identifier for the framework section.
        let id = UUID()
        
        /// The languages supported.
        let languages: [String]
        /// The title of the framework.
        let title: String
        /// Tags associated with the framework.
        let tags: [String]
        /// The navigation destination.
        let destination: Destination
        /// Legal notices.
        let legalNotices: LegalNotices?
        /// The associated DocC site, if applicable.
        let docCSite: DocCSiteDTO?
        
        /// Checks if this framework section is equal to another.
        func isEqual(to framework: FrameworkSection) -> Bool {
            guard let currentUrl = URL(string: destination.identifier),
                  let url = URL(string: framework.destination.identifier)
            else {
                return destination.identifier.lowercased() == framework.destination.identifier.lowercased()
            }
            
            return currentUrl.path().lowercased() == url.path().lowercased()
        }
        
        /// The destination details for navigation.
        struct Destination: Codable, Hashable {
            /// The type of destination.
            let type: String
            /// Indicates if the destination is active.
            let isActive: Bool
            /// The identifier path.
            let identifier: String
        }
        
        /// Converts this section into a `Reference` object.
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
