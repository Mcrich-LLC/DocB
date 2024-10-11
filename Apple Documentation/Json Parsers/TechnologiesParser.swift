//
//  TechnologiesParser.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/5/24.
//

import Foundation

struct Technologies: Decodable {
    let header: Header?
    let groups: [Technology]?
    let legalNotices: LegalNotices
    
    enum CodingKeys: CodingKey {
        case sections, legalNotices
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.legalNotices = try container.decode(LegalNotices.self, forKey: .legalNotices)
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
    
    struct Header: Codable {
        let backgroundImage: String
        let image: String
        let title: String
        let kind: String
    }
    
    struct Technology: Codable, Identifiable {
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
    
    struct FrameworkSection: Codable, Identifiable, Hashable {
        let id = UUID()
        
        let languages: [String]
        let title: String
        let tags: [String]
        let destination: Destination
        
        enum CodingKeys: CodingKey {
            case id
            case languages
            case title
            case tags
            case destination
        }
        
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.languages = try container.decode([String].self, forKey: .languages)
            self.title = try container.decode(String.self, forKey: .title)
            self.tags = try container.decode([String].self, forKey: .tags)
            self.destination = try container.decode(Destination.self, forKey: .destination)
        }
        
        init(languages: [String], title: String, tags: [String], destination: Destination) {
            self.languages = languages
            self.title = title
            self.tags = tags
            self.destination = destination
        }
        
        struct Destination: Codable, Hashable {
            let type: String
            let isActive: Bool
            let identifier: String
        }
    }
}
