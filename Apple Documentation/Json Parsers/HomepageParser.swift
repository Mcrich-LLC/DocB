//
//  HomepageParser.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/11/24.
//

import Foundation
import SwiftUI
import EnhancedCodable

/// A structure representing the parsed content of the documentation homepage.
struct HomepageParser: Codable, Hashable, AppleDocumentation {
    /// Metadata associated with the homepage.
    let metadata: Metadata
    /// The sections of content on the homepage.
    let sections: [Section]
    /// References to other documentation symbols.
    let references: [String : Reference]
    /// Legal notices associated with the homepage.
    let legalNotices: LegalNotices?
    
    @CodableIgnoreInitializedProperties
    struct Section: Codable, Identifiable, Hashable, Sendable {
        /// The unique identifier of the section.
        let id = UUID()
        
        /// The kind of section (e.g., hero, resources).
        let kind: Kind
        /// The content within the section.
        let content: [ContentSection.Content]?
        /// Resources available in this section.
        let resources: [Resource]?
        /// The body content of the section.
        let body: Body?
        /// The title of the section.
        let title: String?
        /// A URL or identifier for a video in the section.
        let video: String?
        /// A URL or identifier for an image in the section.
        let image: String?
        
        enum Kind: String, Codable {
            case hero, section, homepageResources
        }
    }
    
    /// Metadata providing details about the homepage.
    struct Metadata: Codable, Hashable {
        /// The title of the homepage.
        let title: String
        /// The role of the homepage document.
        let role: Role
    }
    
    /// A resource item appearing on the homepage.
    @CodableIgnoreInitializedProperties
    struct Resource: Codable, Hashable, Identifiable, Sendable {
        /// The unique identifier of the resource.
        let id = UUID()
        
        /// The title of the resource.
        let title: String
        /// An image associated with the resource.
        let image: String?
        /// The destination reference for the resource.
        let destination: Reference
        /// The content description of the resource.
        let content: [ContentSection.Content]
    }
    
    /// The body content of a homepage section.
    struct Body: Codable, Hashable {
        /// A list of links in the body.
        let links: [LinkItem]?
        /// A list of cards in the body.
        let cards: [Card]?
        /// A list of highlighted links.
        let highlightedLinks: [HighlightedLinks]?
        /// Links specific to the homepage structure.
        let homepageLinks: [Reference]?
        /// The kind of body content.
        let kind: Kind
        /// An image associated with the body.
        let image: String?
        
        /// An item serving as a link.
        @CodableIgnoreInitializedProperties
        struct LinkItem: Codable, Hashable, Identifiable {
            /// The unique identifier of the link item.
            let id = UUID()
            
            /// The text items in the link.
            let items: [String]
            /// The style of the link content.
            let style: ContentSection.Content.Style
            /// The type of the link item.
            let type: Kind
        }
        
        enum Kind: String, Codable {
            case links, homepageLinks, cards, highlightedLinks
        }
        
        /// A set of highlighted links.
        @CodableIgnoreInitializedProperties
        struct HighlightedLinks: Codable, Hashable, Identifiable {
            /// The unique identifier of the highlighted links.
            let id = UUID()
            
            /// The content description of the highlighted link.
            let content: [ContentSection.Content]
            /// The title of the highlighted link.
            let title: String
            /// The text for the call to action button.
            let callToActionText: String?
            /// The destination URL.
            let destination: URL?
        }
        
        /// A card element on the homepage.
        @CodableIgnoreInitializedProperties
        struct Card: Codable, Hashable, Identifiable {
            /// The unique identifier of the card.
            let id = UUID()
            
            /// Indicates if the card is featured.
            let isFeatured: Bool
            /// The content items within the card.
            let cards: [Content]

            struct CallToAction: Codable, Hashable {
                let ide: String?
                let web: String?
            }
            
            /// The content within a card.
            @CodableIgnoreInitializedProperties
            struct Content: Codable, Hashable, Identifiable {
                /// The unique identifier of the card content.
                let id = UUID()
                
                /// The content description.
                let content: [ContentSection.Content]
                /// A small heading text above the main title.
                let eyebrow: String?
                /// The destination reference.
                let destination: Reference
                /// The title of the card content.
                let title: String
                /// An image associated with the card.
                let image: String?
                /// The call to action details.
                let callToAction: CallToAction?
                /// Text-based call to action.
                let callToActionText: CallToAction?
                
                var saferCallToAction: CallToAction? {
                    callToAction ?? callToActionText
                }
            }
        }
    }
}
