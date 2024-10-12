//
//  HomepageParser.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/11/24.
//

import Foundation
import SwiftUI

struct HomepageParser: Codable, Hashable {
    let metadata: Metadata
    let sections: [Section]
    let references: [String : Reference]
    
    struct Section: Codable, Identifiable, Hashable {
        let id = UUID()
        
        let kind: Kind
        let content: [ContentSection.Content]?
        let resources: [Resource]?
        let body: Body?
        let title: String?
        let video: String?
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            kind = try container.decode(Kind.self, forKey: .kind)
            content = try container.decodeIfPresent([ContentSection.Content].self, forKey: .content)
            resources = try container.decodeIfPresent([Resource].self, forKey: .resources)
            body = try container.decodeIfPresent(Body.self, forKey: .body)
            title = try container.decodeIfPresent(String.self, forKey: .title)
            video = try container.decodeIfPresent(String.self, forKey: .video)
        }
        
        enum Kind: String, Codable {
            case hero, section, homepageResources
        }
    }
    
    struct Metadata: Codable, Hashable {
        let title: String
        let role: Role
    }
    
    struct Resource: Codable, Hashable {
        let title: String
        let image: String?
        let destination: Reference
        let content: [ContentSection.Content]
    }
    
    struct Body: Codable, Hashable {
        let links: [LinkItem]?
        let cards: [Card]?
        let homepageLinks: [Reference]?
        let kind: Kind
        
        struct LinkItem: Codable, Hashable, Identifiable {
            let id = UUID()
            
            let items: [String]
            let style: ContentSection.Content.Style
            let type: Kind
            
            init(from decoder: any Decoder) throws {
                let container: KeyedDecodingContainer<HomepageParser.Body.LinkItem.CodingKeys> = try decoder.container(keyedBy: HomepageParser.Body.LinkItem.CodingKeys.self)
                self.items = try container.decode([String].self, forKey: HomepageParser.Body.LinkItem.CodingKeys.items)
                self.style = try container.decode(ContentSection.Content.Style.self, forKey: HomepageParser.Body.LinkItem.CodingKeys.style)
                self.type = try container.decode(Kind.self, forKey: HomepageParser.Body.LinkItem.CodingKeys.type)
            }
        }
        
        enum Kind: String, Codable {
            case links, homepageLinks, cards
        }
        
        struct Card: Codable, Hashable {
            let isFeatured: Bool
            let cards: [Content]

            struct CallToAction: Codable, Hashable {
                let ide: String?
                let web: String?
            }
            
            struct Content: Codable, Hashable {
                let content: [ContentSection.Content]
                let eyebrow: String?
                let destination: Reference
                let title: String
                let image: String?
                let callToAction: CallToAction?
            }
        }
    }
}
