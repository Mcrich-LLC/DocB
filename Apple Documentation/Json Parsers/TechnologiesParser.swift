//
//  TechnologiesParser.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/5/24.
//

import Foundation
import EnhancedCodable

enum TechnologyTypes: Identifiable {
    case apple(AppleTechnologies)
    case docC(DocCSite)
    
    var id: UUID {
        switch self {
        case .apple(let apple):
            return apple.id
        case .docC(let docC):
            return docC.id
        }
    }
}

struct AppleTechnologies: Decodable, AppleDocumentation, Identifiable {
    let id = UUID()
    
    let header: Header?
    let groups: [Technology]?
    let references: [String : Reference]
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
    
    struct CommonTechnologiesSection: Codable {
        let kind: String
        
        // Header
        let backgroundImage: String?
        let image: String?
        let title: String?
        
        // Technology
        let groups: [Technology]?
    }
    
    struct Header: Codable, Equatable, Hashable {
        let backgroundImage: String
        let image: String
        let title: String
        let kind: String
    }
    
    @CodableIgnoreInitializedProperties
    struct Technology: Codable, Identifiable, Hashable, Equatable {
        let id = UUID()
        
        let name: String
        let technologies: [FrameworkSection]
    }
    
    @CodableIgnoreInitializedProperties
    struct FrameworkSection: Codable, Identifiable, AppleDocumentation {
        let id = UUID()
        
        let languages: [String]
        let title: String
        let tags: [String]
        let destination: Destination
        let legalNotices: LegalNotices?
        let docCSite: DocCSite?
        
        func isEqual(to framework: FrameworkSection) -> Bool {
            guard let currentUrl = URL(string: destination.identifier),
                  let url = URL(string: framework.destination.identifier)
            else {
                return destination.identifier.lowercased() == framework.destination.identifier.lowercased()
            }
            
            return currentUrl.path().lowercased() == url.path().lowercased()
        }
        
        struct Destination: Codable, Hashable {
            let type: String
            let isActive: Bool
            let identifier: String
        }
        
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
