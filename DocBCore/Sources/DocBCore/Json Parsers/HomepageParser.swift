//
//  HomepageParser.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/11/24.
//

import Foundation
import SwiftUI
import EnhancedCodable

/// Decoded DocC homepage payload used to render the landing experience.
struct HomepageParser: Codable, Hashable, AppleDocumentation {
    /// Homepage metadata including title and role.
    let metadata: Metadata
    /// Ordered homepage sections.
    let sections: [Section]
    /// Reference lookup table used by section destinations.
    let references: [String : Reference]
    /// Optional legal notices shown in footer contexts.
    let legalNotices: LegalNotices?
    
    @CodableIgnoreInitializedProperties
    /// A top-level homepage section such as hero, content section, or resources.
    struct Section: Codable, Identifiable, Hashable, Sendable {
        let id = UUID()
        
        let kind: Kind
        let content: [ContentSection.Content]?
        let resources: [Resource]?
        let body: Body?
        let title: String?
        let video: String?
        let image: String?
        
        /// Supported homepage section kinds.
        enum Kind: String, Codable {
            case hero, section, homepageResources
        }
    }
    
    /// Metadata for homepage identity and role.
    struct Metadata: Codable, Hashable {
        let title: String
        let role: Role
    }
    
    @CodableIgnoreInitializedProperties
    /// Resource card model used by homepage resource sections.
    struct Resource: Codable, Hashable, Identifiable, Sendable {
        let id = UUID()
        
        let title: String
        let image: String?
        let destination: Reference
        let content: [ContentSection.Content]
    }
    
    /// Structured body payload used by complex homepage sections.
    struct Body: Codable, Hashable {
        let links: [LinkItem]?
        let cards: [Card]?
        let highlightedLinks: [HighlightedLinks]?
        let homepageLinks: [Reference]?
        let kind: Kind
        let image: String?
        
        @CodableIgnoreInitializedProperties
        /// Link list section payload.
        struct LinkItem: Codable, Hashable, Identifiable {
            let id = UUID()
            
            let items: [String]
            let style: ContentSection.Content.Style
            let type: Kind
        }
        
        /// Body subsection kinds available in homepage payloads.
        enum Kind: String, Codable {
            case links, homepageLinks, cards, highlightedLinks
        }
        
        @CodableIgnoreInitializedProperties
        /// Highlighted link card with optional call-to-action.
        struct HighlightedLinks: Codable, Hashable, Identifiable {
            let id = UUID()
            
            let content: [ContentSection.Content]
            let title: String
            let callToActionText: String?
            let destination: URL?
        }
        
        @CodableIgnoreInitializedProperties
        /// Card group payload used for featured and standard homepage cards.
        struct Card: Codable, Hashable, Identifiable {
            let id = UUID()
            
            let isFeatured: Bool
            let cards: [Content]

            /// IDE and web call-to-action URLs.
            struct CallToAction: Codable, Hashable {
                let ide: String?
                let web: String?
            }
            
            @CodableIgnoreInitializedProperties
            /// Individual card entry displayed within a homepage card group.
            struct Content: Codable, Hashable, Identifiable {
                let id = UUID()
                
                let content: [ContentSection.Content]
                let eyebrow: String?
                let destination: Reference
                let title: String
                let image: String?
                let callToAction: CallToAction?
                let callToActionText: CallToAction?
                
                /// Safe call-to-action accessor that handles schema variation.
                var saferCallToAction: CallToAction? {
                    callToAction ?? callToActionText
                }
            }
        }
    }
}
