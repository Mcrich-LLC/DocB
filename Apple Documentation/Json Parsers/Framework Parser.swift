//
//  Technology Parser.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/5/24.
//

import Foundation

struct Framework: Decodable {
    let topicSections: [TopicSection]
    let metadata: Metadata
    let references: [String : Reference]
    
    struct TopicSection: Decodable, Identifiable {
        let id = UUID()
        
        let title: String
        let anchor: String
        let identifiers: [String]
        
        enum CodingKeys: CodingKey {
            case id
            case title
            case anchor
            case identifiers
        }
        
        init(from decoder: any Decoder) throws {
            let container: KeyedDecodingContainer<Framework.TopicSection.CodingKeys> = try decoder.container(keyedBy: Framework.TopicSection.CodingKeys.self)
            self.title = try container.decode(String.self, forKey: Framework.TopicSection.CodingKeys.title)
            self.anchor = try container.decode(String.self, forKey: Framework.TopicSection.CodingKeys.anchor)
            self.identifiers = try container.decode([String].self, forKey: Framework.TopicSection.CodingKeys.identifiers)
        }
        
        init(title: String, anchor: String, identifiers: [String]) {
            self.title = title
            self.anchor = anchor
            self.identifiers = identifiers
        }
    }

    struct Metadata: Decodable {
        let title: String
        let role: String
        let images: [ImageStruct]?
        let platforms: [Platforms]?
        
        struct ImageStruct: Decodable {
            let identifier: String
            let type: String
        }
        
        struct Platforms: Decodable {
            let name: String
            let introducedAt: String
            let beta: Bool
        }
    }
    
    struct Reference: Decodable {
        let title: String?
        let abstract: [Abstract]?
        let identifier: String
        let kind: String?
        let type: String
        let url: String?
        let role: Role?
        
        enum CodingKeys: CodingKey {
            case title
            case abstract
            case identifier
            case kind
            case type
            case url
            case role
        }
        
        init(from decoder: any Decoder) throws {
            let container: KeyedDecodingContainer = try decoder.container(keyedBy: CodingKeys.self)
            self.title = try container.decodeIfPresent(String.self, forKey: .title)
            self.abstract = try container.decodeIfPresent([Framework.Reference.Abstract].self, forKey: .abstract)
            self.identifier = try container.decode(String.self, forKey: .identifier)
            self.kind = try container.decodeIfPresent(String.self, forKey: .kind)
            self.type = try container.decode(String.self, forKey: .type)
            self.url = try container.decodeIfPresent(String.self, forKey: .url)
            let roleString = try container.decodeIfPresent(String.self, forKey: .role)
            self.role = Role(rawValue: roleString ?? "")
        }
        
        init(title: String?, abstract: [Abstract]?, identifier: String, kind: String?, type: String, url: String?, role: Role?) {
            self.title = title
            self.abstract = abstract
            self.identifier = identifier
            self.kind = kind
            self.type = type
            self.url = url
            self.role = role
        }
        
        enum Role: String, Decodable {
            case collectionGroup
            case article
            case overview
        }
        
        struct Abstract: Decodable {
            let text: String
            let type: String
        }
    }
}
