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
            let identifiers = try container.decode([String].self, forKey: Framework.TopicSection.CodingKeys.identifiers)
            
            // Filter to remove ids with #
            self.identifiers = identifiers.filter({ !$0.contains("#") })
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
        let platforms: [Platform]?
    }
    
    struct Reference: Decodable, Hashable {
        let title: String?
        let abstract: [ContentStruct]?
        let identifier: String
        let kind: String?
        let type: String
        let url: String?
        let role: Role?
        let symbolKind: String?
        let fragments: [Fragment]?
        
        enum Role: String, Decodable {
            case collectionGroup
            case collection
            case article
            case overview
            case sampleCode
            case symbol
            case link
            
            func symbol(symbolKind: String? = nil) -> String {
                switch self {
                case .collectionGroup:
                    "list.bullet"
                case .collection:
                    "list.bullet"
                case .sampleCode:
                    "curlybraces"
                case .symbol:
                    "curlybraces"
                default:
                    "text.document"
                }
            }
        }
    }
}
