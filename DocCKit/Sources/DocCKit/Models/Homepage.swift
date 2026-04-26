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
public struct HomepageParser: Codable, Hashable, AppleDocumentation {
    /// Homepage metadata including title and role.
    public let metadata: Metadata
    /// Ordered homepage sections.
    public let sections: [Section]
    /// Reference lookup table used by section destinations.
    public let references: [String : Reference]
    /// Optional legal notices shown in footer contexts.
    public let legalNotices: LegalNotices?
    
    /// A top-level homepage section such as hero, content section, or resources.
    @CodableIgnoreInitializedProperties
    public struct Section: Codable, Identifiable, Hashable, Sendable {
        public let id = UUID()
        
        public let kind: Kind
        public let content: [ContentSection.Content]?
        public let resources: [Resource]?
        public let body: Body?
        public let title: String?
        public let video: String?
        public let image: String?
        
        /// Supported homepage section kinds.
        public enum Kind: String, Codable, Sendable {
            case hero, section, homepageResources
        }
    }
    
    /// Metadata for homepage identity and role.
    public struct Metadata: Codable, Hashable, Sendable {
        public let title: String
        public let role: Role
    }
    
    /// Resource card model used by homepage resource sections.
    @CodableIgnoreInitializedProperties
    public struct Resource: Codable, Hashable, Identifiable, Sendable {
        public let id = UUID()
        
        public let title: String
        public let image: String?
        public let destination: Reference
        public let content: [ContentSection.Content]
    }
    
    /// Structured body payload used by complex homepage sections.
    public struct Body: Codable, Hashable, Sendable {
        public let links: [LinkItem]?
        public let cards: [Card]?
        public let highlightedLinks: [HighlightedLinks]?
        public let homepageLinks: [Reference]?
        public let kind: Kind
        public let image: String?
        
        /// Link list section payload.
        @CodableIgnoreInitializedProperties
        public struct LinkItem: Codable, Hashable, Identifiable, Sendable {
            public let id = UUID()
            
            public let items: [String]
            public let style: ContentSection.Content.Style
            public let type: Kind
        }
        
        /// Body subsection kinds available in homepage payloads.
        public enum Kind: String, Codable, Sendable {
            case links, homepageLinks, cards, highlightedLinks
        }
        
        /// Highlighted link card with optional call-to-action.
        @CodableIgnoreInitializedProperties
        public struct HighlightedLinks: Codable, Hashable, Identifiable, Sendable {
            public let id = UUID()
            
            public let content: [ContentSection.Content]
            public let title: String
            public let callToActionText: String?
            public let destination: URL?
        }
        
        /// Card group payload used for featured and standard homepage cards.
        @CodableIgnoreInitializedProperties
        public struct Card: Codable, Hashable, Identifiable, Sendable {
            public let id = UUID()
            
            public let isFeatured: Bool
            public let cards: [Content]

            /// IDE and web call-to-action URLs.
            public struct CallToAction: Codable, Hashable, Sendable {
                public let ide: String?
                public let web: String?
            }
            
            /// Individual card entry displayed within a homepage card group.
            @CodableIgnoreInitializedProperties
            public struct Content: Codable, Hashable, Identifiable, Sendable {
                public let id = UUID()
                
                public let content: [ContentSection.Content]
                public let eyebrow: String?
                public let destination: Reference
                public let title: String
                public let image: String?
                public let callToAction: CallToAction?
                public let callToActionText: CallToAction?
                
                /// Safe call-to-action accessor that handles schema variation.
                public var saferCallToAction: CallToAction? {
                    callToAction ?? callToActionText
                }
            }
        }
    }
}
