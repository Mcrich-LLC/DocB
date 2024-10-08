//
//  CommonTypes.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/6/24.
//

import Foundation

struct ImageStruct: Decodable {
    let identifier: String
    let type: String
}

struct ContentStruct: Decodable, Hashable, Identifiable {
    let id = UUID()
    
    let text: String?
    let code: String?
    let identifier: String?
    let type: ContentType
}

struct Fragment: Decodable, Hashable {
    let text: String
    let kind: String
}

struct ContentSection: Decodable, Identifiable {
    let id = UUID()
    
    let kind: Kind
    let content: [Content]?
    let declarations: [Declaration]?
    
    enum Kind: String, Decodable {
        case content
        case declarations
    }
    
    struct Declaration: Decodable, Identifiable {
        let id = UUID()
        let tokens: [Token]
        let languages: [String]
        let platforms: [PlatformName]
        
        struct Token: Decodable {
            let text: String
            let kind: Kind
            
            enum Kind: String, Decodable {
                case text
                case keyword
                case attribute
                case identifier
                case typeIdentifier
                case externalParam
            }
        }
    }
    
    struct Content: Decodable, Identifiable {
        let id = UUID()
        let type: ContentType?
        
        // Media
        let identifier: String?
        
        // Heading
        let anchor: String?
        let text: String?
        let level: Int?
        
        // Inline Content
        let inlineContent: [ContentStruct]?
        
        // List
        let termListItems: [TermListItem]?
        let unorderedListItems: [UnorderedListItem]?
        
        // Tab
        let tabs: [Tab]?
        
        // Row
        let numberOfColumns: Int?
        let columns: [Column]?
        
        enum CodingKeys: CodingKey {
            case type
            case identifier
            case anchor
            case text
            case level
            case inlineContent
            case termListItems
            case unorderedListItems
            case tabs
            case numberOfColumns
            case columns
        }
        
        init(from decoder: any Decoder) throws {
            let container: KeyedDecodingContainer<ContentSection.Content.CodingKeys> = try decoder.container(keyedBy: ContentSection.Content.CodingKeys.self)
            self.type = try container.decodeIfPresent(ContentType.self, forKey: ContentSection.Content.CodingKeys.type)
            self.identifier = try container.decodeIfPresent(String.self, forKey: ContentSection.Content.CodingKeys.identifier)
            self.anchor = try container.decodeIfPresent(String.self, forKey: ContentSection.Content.CodingKeys.anchor)
            self.text = try container.decodeIfPresent(String.self, forKey: ContentSection.Content.CodingKeys.text)
            self.level = try container.decodeIfPresent(Int.self, forKey: ContentSection.Content.CodingKeys.level)
            self.inlineContent = try container.decodeIfPresent([ContentStruct].self, forKey: ContentSection.Content.CodingKeys.inlineContent)
            
            // Lists
            if type == .termList {
                self.termListItems = try container.decodeIfPresent([TermListItem].self, forKey: ContentSection.Content.CodingKeys.termListItems)
            } else {
                self.termListItems = nil
            }
            
            if type == .unorderedList {
                self.unorderedListItems = try container.decodeIfPresent([UnorderedListItem].self, forKey: ContentSection.Content.CodingKeys.unorderedListItems)
            } else {
                self.unorderedListItems = nil
            }
            
            // Tabs
            self.tabs = try container.decodeIfPresent([Tab].self, forKey: ContentSection.Content.CodingKeys.tabs)
            
            // Row
            self.numberOfColumns = try container.decodeIfPresent(Int.self, forKey: ContentSection.Content.CodingKeys.numberOfColumns)
            self.columns = try container.decodeIfPresent([Column].self, forKey: ContentSection.Content.CodingKeys.columns)
        }
        
        struct Column: Decodable {
            let size: Int
            let content: [Content]
        }
        
        struct Tab: Decodable {
            let content: [Content]
            let title: String
            
            struct Content: Decodable {
                let items: [Item]?
                let inlineContent: [ContentStruct]?
            }
            
            struct Item: Decodable {
                let content: [ContentSection.Content]
            }
        }
        
        struct TermListItem: Decodable {
            let term: Term
            let definition: Definition
            
            struct Definition: Decodable {
                let content: [ContentSection.Content]
            }
            
            struct Term: Decodable {
                let inlineContent: [ContentStruct]
            }
        }
        
        struct UnorderedListItem: Decodable {
            let content: [ContentSection.Content]?
        }
    }
}

struct Reference: Decodable, Hashable {
    let title: String?
    let abstract: [ContentStruct]?
    let identifier: String
    let kind: String?
    let type: String
    let url: String?
    let role: Role?
    let fragments: [Fragment]?
    let deprecated: Bool?
    let variants: [Variant]?
    
    struct Variant: Decodable, Hashable {
        let url: String
        let traits: [String]
    }
    
    enum Role: String, Decodable {
        case collectionGroup
        case collection
        case article
        case overview
        case sampleCode
        case symbol
    }
}

// MARK: Content Types

enum ContentType: String, Decodable {
    case heading
    case paragraph
    case text
    case image
    case video
    case termList
    case unorderedList
    case orderedList
    case tabNavigator
    case reference
    case table
    case emphasis
    case codeListing
    case row
    case aside
    case code
    case codeVoice
}

// MARK: Platforms
enum PlatformName: String, Decodable {
    case iOS
    case iPadOS
    case MacCatalyst = "Mac Catalyst"
    case macOS
    case tvOS
    case visionOS
    case watchOS
    case Xcode
}

struct Platform: Decodable, Identifiable {
    let id = UUID()
    
    let introducedAt: String
    let unavailable: Bool?
    let beta: Bool?
    let name: PlatformName
    let deprecated: Bool?
    let deprecatedAt: String?
}
