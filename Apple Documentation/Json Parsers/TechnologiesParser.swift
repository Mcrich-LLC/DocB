//
//  TechnologiesParser.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/5/24.
//

import Foundation

enum TechnologyTypes {
    case apple(AppleTechnologies)
    case docC(DocCIndex)
}

struct AppleTechnologies: Decodable, AppleDocumentation {
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
    
    struct Technology: Codable, Identifiable, Hashable, Equatable {
        let id = UUID()
        
        let name: String
        let technologies: [FrameworkSection]
        
        enum CodingKeys: CodingKey {
            case id
            case name
            case technologies
        }
        
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try container.decode(String.self, forKey: .name)
            self.technologies = try container.decode([FrameworkSection].self, forKey: .technologies)
        }
        
        init(name: String, technologies: [FrameworkSection]) {
            self.name = name
            self.technologies = technologies
        }
    }
    
    struct FrameworkSection: Codable, Identifiable, AppleDocumentation {
        let id = UUID()
        
        let languages: [String]
        let title: String
        let tags: [String]
        let destination: Destination
        let legalNotices: LegalNotices?
        
        func isEqual(to framework: FrameworkSection) -> Bool {
            guard let currentUrl = URL(string: destination.identifier),
                  let url = URL(string: framework.destination.identifier)
            else {
                return destination.identifier.lowercased() == framework.destination.identifier.lowercased()
            }
            
            return currentUrl.path().lowercased() == url.path().lowercased()
        }
        
        enum CodingKeys: CodingKey {
            case id
            case languages
            case title
            case tags
            case destination
            case legalNotices
        }
        
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.languages = try container.decode([String].self, forKey: .languages)
            self.title = try container.decode(String.self, forKey: .title)
            self.legalNotices = try container.decodeIfPresent(LegalNotices.self, forKey: .legalNotices)
            self.tags = try container.decode([String].self, forKey: .tags)
            self.destination = try container.decode(Destination.self, forKey: .destination)
        }
        
        init(languages: [String], title: String, tags: [String], destination: Destination, legalNotices: LegalNotices) {
            self.languages = languages
            self.title = title
            self.tags = tags
            self.destination = destination
            self.legalNotices = legalNotices
        }
        
        struct Destination: Codable, Hashable {
            let type: String
            let isActive: Bool
            let identifier: String
        }
        
        var frameworkReference: Reference {
            Reference(title: title, abstract: nil, identifier: destination.identifier, kind: nil, type: "", url: nil, role: nil, fragments: nil, deprecated: nil, beta: nil, variants: nil, images: nil)
        }
    }
}
