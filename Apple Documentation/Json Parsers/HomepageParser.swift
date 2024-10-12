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
    }
    
    enum Kind: String, Codable {
        case hero, links, homepageLinks, section, cards, homepageResources
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
        
        struct LinkItem: Codable, Hashable {
            let items: [String]
            let style: ContentSection.Content.Style
            let type: Kind
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
