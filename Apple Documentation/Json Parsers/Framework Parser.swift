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
        let images: [ImageStruct]
        let platforms: [Platforms]
        
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
        let role: String?
        
        struct Abstract: Decodable {
            let text: String
            let type: String
        }
    }
}
