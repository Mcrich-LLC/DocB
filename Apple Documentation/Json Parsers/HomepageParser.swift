//
//  HomepageParser.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/11/24.
//

import Foundation
import SwiftUI
import EnhancedCodable

struct HomepageParser: Codable, Hashable, AppleDocumentation {
    let metadata: Metadata
    let sections: [Section]
    let references: [String : Reference]
    let legalNotices: LegalNotices?
    
    @CodableIgnoreInitializedProperties
    struct Section: Codable, Identifiable, Hashable {
        let id = UUID()
        
        let kind: Kind
        let content: [ContentSection.Content]?
        let resources: [Resource]?
        let body: Body?
        let title: String?
        let video: String?
        
        enum Kind: String, Codable {
            case hero, section, homepageResources
        }
    }
    
    struct Metadata: Codable, Hashable {
        let title: String
        let role: Role
    }
    
    @CodableIgnoreInitializedProperties
    struct Resource: Codable, Hashable, Identifiable {
        let id = UUID()
        
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
        
        @CodableIgnoreInitializedProperties
        struct LinkItem: Codable, Hashable, Identifiable {
            let id = UUID()
            
            let items: [String]
            let style: ContentSection.Content.Style
            let type: Kind
        }
        
        enum Kind: String, Codable {
            case links, homepageLinks, cards
        }
        
        @CodableIgnoreInitializedProperties
        struct Card: Codable, Hashable, Identifiable {
            let id = UUID()
            
            let isFeatured: Bool
            let cards: [Content]

            struct CallToAction: Codable, Hashable {
                let ide: String?
                let web: String?
            }
            
            @CodableIgnoreInitializedProperties
            struct Content: Codable, Hashable, Identifiable {
                let id = UUID()
                
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
