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

struct ContentStruct: Decodable, Hashable {
    let text: String?
    let identifier: String?
    let type: String
}

struct ContentSection: Decodable {
    let kind: String
    let content: [Content]
    
    struct Content: Decodable {
        let type: ContentType?
        
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
        
        enum CodingKeys: CodingKey {
            case type
            case anchor
            case text
            case level
            case inlineContent
            case termListItems
            case unorderedListItems
            case tabs
        }
        
        init(from decoder: any Decoder) throws {
            let container: KeyedDecodingContainer<ContentSection.Content.CodingKeys> = try decoder.container(keyedBy: ContentSection.Content.CodingKeys.self)
            self.type = try container.decodeIfPresent(ContentType.self, forKey: ContentSection.Content.CodingKeys.type)
            self.anchor = try container.decodeIfPresent(String.self, forKey: ContentSection.Content.CodingKeys.anchor)
            self.text = try container.decodeIfPresent(String.self, forKey: ContentSection.Content.CodingKeys.text)
            self.level = try container.decodeIfPresent(Int.self, forKey: ContentSection.Content.CodingKeys.level)
            self.inlineContent = try container.decodeIfPresent([ContentStruct].self, forKey: ContentSection.Content.CodingKeys.inlineContent)
            
            // Lists
            if type == .termList {
                self.termListItems = try container.decodeIfPresent([ContentSection.TermListItem].self, forKey: ContentSection.Content.CodingKeys.termListItems)
            } else {
                self.termListItems = nil
            }
            
            if type == .unorderedList {
                self.unorderedListItems = try container.decodeIfPresent([ContentSection.UnorderedListItem].self, forKey: ContentSection.Content.CodingKeys.unorderedListItems)
            } else {
                self.unorderedListItems = nil
            }
            
            // Tabs
            self.tabs = try container.decodeIfPresent([ContentSection.Tab].self, forKey: ContentSection.Content.CodingKeys.tabs)
        }
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

enum ContentType: String, Decodable {
    case heading
    case paragraph
    case text
    case image
    case termList
    case unorderedList
    case tabNavigator
    case reference
    case table
    case emphasis
}
