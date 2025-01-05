//
//  CommonTypes.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/6/24.
//
// swiftlint:disable line_length file_length type_body_length

import Foundation
import SwiftUI
import EnhancedCodable

@CodableIgnoreInitializedProperties
struct ImageStruct: Codable, Identifiable, Equatable, Hashable {
    let id = UUID()
    
    let identifier: String
    let type: ImageType
    
    enum ImageType: String, Codable, CaseIterable {
        case icon
        case card
    }
}

struct LegalNotices: Codable, Equatable, Hashable {
    let copyright: String
    let termsOfUse: String
    let privacyPolicy: String
}

@CodableIgnoreInitializedProperties
struct ContentStruct: Codable, Hashable, Identifiable, Equatable {
    let id = UUID()
    
    let text: String?
    let code: String?
    let identifier: String?
    let inlineContent: [ContentStruct]?
    let type: ContentType
}

struct Fragment: Codable, Hashable {
    let text: String
    let kind: String
}

@CodableIgnoreInitializedProperties
struct ContentSection: Codable, Identifiable, Equatable, Hashable {
    let id = UUID()
    
    let kind: Kind
    let content: [Content]?
    let declarations: [Declaration]?
    let mentions: [String]?
    let details: Details?
    
    // Web Endpoint
    let items: [RestResponse]?
    let bodyContentType: [RestResponse.RestResponseType]?
    let mimeType: String?
    let title: String?
    let tokens: [Token]?
    let attributes: [Attribute]?
    
    enum CodingKeys: CodingKey {
        case id
        case kind
        case content
        case declarations
        case mentions
        case details
        
        // Web Endpoint
        case items
        case bodyContentType
        case mimeType
        case title
        case tokens
        case attributes
    }
    
    enum Kind: String, Codable, Equatable, Hashable {
        case content
        case declarations
        case mentions
        case details
        case kind
        case parameters
        case restEndpoint
        case restBody
        case restResponses
        case properties
        case typeIdentifier
        case text
        case attributes
        case restParameters
    }
    
    @CodableIgnoreInitializedProperties
    struct Attribute: Codable, Identifiable, Equatable, Hashable {
        let id = UUID()
        
        let name: String?
    }
    
    @CodableIgnoreInitializedProperties
    struct RestResponse: Codable, Identifiable, Equatable, Hashable {
        let id = UUID()
        
        let type: [RestResponseType]
        let status: Int?
        let mimeContent: String?
        let content: [ContentSection.Content]
        let reason: String?
        let name: String?
        
        @CodableIgnoreInitializedProperties
        struct RestResponseType: Codable, Identifiable, Equatable, Hashable {
            let id = UUID()
            
            let text: String
            let kind: Kind
            let preciseIdentifier: String?
            let identifier: String?
        }
    }
    
    @CodableIgnoreInitializedProperties
    struct Details: Codable, Identifiable, Equatable, Hashable {
        let id = UUID()
        
        let name: String
        let value: [Value]
        
        struct Value: Codable, Equatable, Hashable {
            let baseType: String
        }
    }
    
    @CodableIgnoreInitializedProperties
    struct Declaration: Codable, Identifiable, Equatable, Hashable {
        let id = UUID()
        let tokens: [Token]
        let languages: [String]
        let platforms: [String]
    }
    
    struct Token: Codable, Equatable, Hashable {
        let text: String?
        let kind: String
        let code: String?
    }
    
    struct Content: Codable, Identifiable, Equatable, Hashable {
        let id = UUID()
        let type: ContentType?
        
        // Media
        let identifier: String?
        
        // Heading
        let anchor: String?
        let level: Int?
        
        // Text
        let code: [String]?
        let text: String?
        
        // Links
        let style: Style?
        let linkItems: [String]?
        
        // Inline Content
        let inlineContent: [ContentStruct]?
        
        // Subcontent
        let content: [Content]?
        
        // List
        let termListItems: [TermListItem]?
        let unorderedListItems: [UnorderedListItem]?
        let orderedListItems: [UnorderedListItem]?
        
        // Tab
        let tabs: [Tab]?
        
        // Row
        let numberOfColumns: Int?
        let columns: [Column]?
        let rows: [[[Content]]]?
        
        enum CodingKeys: CodingKey {
            case type
            case identifier
            case anchor
            case text
            case level
            case inlineContent
            case items
            case tabs
            case numberOfColumns
            case columns
            case code
            case style
            case content
            case rows
        }
        
        init(from decoder: any Decoder) throws {
            let container: KeyedDecodingContainer<ContentSection.Content.CodingKeys> = try decoder.container(keyedBy: ContentSection.Content.CodingKeys.self)
            self.type = try container.decodeIfPresent(ContentType.self, forKey: ContentSection.Content.CodingKeys.type)
            self.identifier = try container.decodeIfPresent(String.self, forKey: ContentSection.Content.CodingKeys.identifier)
            self.anchor = try container.decodeIfPresent(String.self, forKey: ContentSection.Content.CodingKeys.anchor)
            self.level = try container.decodeIfPresent(Int.self, forKey: ContentSection.Content.CodingKeys.level)
            self.inlineContent = try container.decodeIfPresent([ContentStruct].self, forKey: ContentSection.Content.CodingKeys.inlineContent)
            self.content = try container.decodeIfPresent([Content].self, forKey: ContentSection.Content.CodingKeys.content)
            self.style = try container.decodeIfPresent(Style.self, forKey: ContentSection.Content.CodingKeys.style)
            
            // Text
            self.text = try container.decodeIfPresent(String.self, forKey: ContentSection.Content.CodingKeys.text)
            self.code = try container.decodeIfPresent([String].self, forKey: ContentSection.Content.CodingKeys.code)
            
            // Lists
            if type == .termList {
                self.termListItems = try container.decodeIfPresent([TermListItem].self, forKey: .items)
            } else {
                self.termListItems = nil
            }
            
            if type == .unorderedList {
                self.unorderedListItems = try container.decodeIfPresent([UnorderedListItem].self, forKey: .items)
            } else {
                self.unorderedListItems = nil
            }
            
            if type == .orderedList {
                self.orderedListItems = try container.decodeIfPresent([UnorderedListItem].self, forKey: .items)
            } else {
                self.orderedListItems = nil
            }
            
            if type == .links {
                self.linkItems = try container.decodeIfPresent([String].self, forKey: .items)
            } else {
                self.linkItems = nil
            }
            
            // Tabs
            self.tabs = try container.decodeIfPresent([Tab].self, forKey: ContentSection.Content.CodingKeys.tabs)
            
            // Row
            self.numberOfColumns = try container.decodeIfPresent(Int.self, forKey: ContentSection.Content.CodingKeys.numberOfColumns)
            self.columns = try container.decodeIfPresent([Column].self, forKey: ContentSection.Content.CodingKeys.columns)
            self.rows = try container.decodeIfPresent([[[Content]]].self, forKey: ContentSection.Content.CodingKeys.rows)
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(type, forKey: .type)
            try container.encode(identifier, forKey: .identifier)
            try container.encode(anchor, forKey: .anchor)
            try container.encode(level, forKey: .level)
            try container.encode(inlineContent, forKey: .inlineContent)
            try container.encode(content, forKey: .content)
            try container.encode(style, forKey: .style)
            
            // Text
            try container.encode(text, forKey: .text)
            try container.encode(code, forKey: .code)
            
            // Lists
            if type == .termList {
                try container.encode(termListItems, forKey: .items)
            }
            
            if type == .unorderedList {
                try container.encode(unorderedListItems, forKey: .items)
            }
            
            if type == .orderedList {
                try container.encode(orderedListItems, forKey: .items)
            }
            
            if type == .links {
                try container.encode(linkItems, forKey: .items)
            }
            
            // Tabs
            try container.encode(tabs, forKey: .tabs)
            
            // Row
            try container.encode(numberOfColumns, forKey: .numberOfColumns)
            try container.encode(columns, forKey: .columns)
            try container.encode(rows, forKey: .rows)
        }
        
        enum Style: String, Codable, CaseIterable, Equatable {
            case compactGrid
            case detailedGrid
            case value
            
            // Asides
            case list
            case tip
            case experiment
            case warning
            case important
            case note
            case deprecated
        }
        
        struct Column: Codable, Equatable, Hashable {
            let size: Int
            let content: [Content]
        }
        
        @CodableIgnoreInitializedProperties
        struct Tab: Codable, Equatable, Identifiable, Hashable {
            let id = UUID()
            
            let content: [Content]
            let title: String
            
            @CodableIgnoreInitializedProperties
            struct Item: Codable, Equatable, Identifiable, Hashable {
                let id = UUID()
                
                let content: [ContentSection.Content]
            }
        }
        
        @CodableIgnoreInitializedProperties
        struct TermListItem: Codable, Identifiable, Equatable, Hashable {
            let id = UUID()
            let term: Term
            let definition: Definition
            
            struct Definition: Codable, Equatable, Hashable {
                let content: [ContentSection.Content]
            }
            
            struct Term: Codable, Equatable, Hashable {
                let inlineContent: [ContentStruct]
            }
        }
        
        @CodableIgnoreInitializedProperties
        struct UnorderedListItem: Codable, Identifiable, Equatable, Hashable {
            let id = UUID()
            
            let content: [ContentSection.Content]?
        }
    }
}

struct Variant: Codable, Equatable, Hashable {
    let traits: [Trait]
    let paths: [String]
    
    struct Trait: Codable, Equatable, Hashable {
        let interfaceLanguage: PreferedProgrammingLanguage
    }
}

struct Reference: Codable, Hashable, Identifiable {
    let id = UUID()
    
    let title: String?
    let abstract: [ContentStruct]?
    let identifier: String
    let kind: String?
    let type: String
    let url: String?
    let role: Role?
    let fragments: [Fragment]?
    let deprecated: Bool?
    let beta: Bool?
    let variants: [Variant]?
    let images: [ImageStruct]?
    var docCSite: DocCSite?
    
    func isEqual(to reference: Self) -> Bool {
        guard let currentUrl = URL(string: identifier),
              let url = URL(string: reference.identifier)
        else {
            return identifier.lowercased() == reference.identifier.lowercased()
        }
        
        return currentUrl.path().lowercased() == url.path().lowercased()
    }
    
    var shareUrl: URL? {
        guard let identifierUrl = URL(string: identifier) else { return nil }
        
        let shareUrlString = "https://developer.apple.com\(identifierUrl.path())"
        
        return URL(string: shareUrlString)
    }
    
    init(title: String?, abstract: [ContentStruct]?, identifier: String, kind: String?, type: String, url: String?, role: Role?, fragments: [Fragment]?, deprecated: Bool?, beta: Bool?, variants: [Variant]?, images: [ImageStruct]?, docCSite: DocCSite?) {
        self.title = title
        self.abstract = abstract
        self.identifier = identifier
        self.kind = kind
        self.type = type
        self.url = url
        self.role = role
        self.fragments = fragments
        self.deprecated = deprecated
        self.beta = beta
        self.variants = variants
        self.images = images
        self.docCSite = docCSite
    }
    
    enum CodingKeys: CodingKey {
        case title
        case abstract
        case identifier
        case kind
        case type
        case url
        case role
        case fragments
        case deprecated
        case beta
        case variants
        case images
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.abstract = try container.decodeIfPresent([ContentStruct].self, forKey: .abstract)
        self.identifier = try container.decode(String.self, forKey: .identifier)
        self.kind = try container.decodeIfPresent(String.self, forKey: .kind)
        self.type = try container.decode(String.self, forKey: .type)
        self.url = try container.decodeIfPresent(String.self, forKey: .url)
        
        if let role = try container.decodeIfPresent(String.self, forKey: .role) {
            self.role = .init(rawValue: role) ?? .unknown
        } else {
            self.role = nil
        }
        
        self.fragments = try container.decodeIfPresent([Fragment].self, forKey: .fragments)
        self.deprecated = try container.decodeIfPresent(Bool.self, forKey: .deprecated)
        self.beta = try container.decodeIfPresent(Bool.self, forKey: .beta)
        self.variants = try container.decodeIfPresent([Reference.Variant].self, forKey: .variants)
        self.images = try container.decodeIfPresent([ImageStruct].self, forKey: .images)
        self.docCSite = nil
    }
    
    struct Variant: Codable, Hashable {
        let url: String
        let traits: [String]
    }
}

// MARK: Role
enum Role: String, Codable, Equatable, Hashable {
    case collectionGroup
    case collection
    case article
    case overview
    case sampleCode
    case symbol
    case framework
    case codeListing
    case link
    case dictionarySymbol
    case pseudoSymbol
    case task
    case subsection
    case restRequestSymbol
    case unknown
    
    var color: Color? {
        switch self {
        case .sampleCode:
            .sampleCode
        case .collectionGroup:
            .collectionGroup.opacity(2)
        case .collection:
                .collection.opacity(2)
        case .symbol:
                .clear
        case .article:
                .article
        default:
            nil
        }
    }
    
    var accentColor: Color {
        switch self {
        case .collection, .symbol:
                .blue
        case .collectionGroup:
                .pink
        default:
            color ?? .accentColor
        }
    }
    
    var gradientColors: [Color] {
        let color = color ?? .article
        
        return [color.opacity(0.4), color.opacity(0.0)]
    }
            
    var labelIcon: SFSymbol {
        switch self {
        case .collectionGroup, .collection:
                .listBullet
        case .sampleCode, .symbol:
                .curlybraces
        default:
                .docText
        }
    }
}

// MARK: Content Types

enum ContentType: String, Codable, Equatable, Hashable {
    case heading
    case paragraph
    case text
    case links
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
    case strong
}

// MARK: Platforms
@CodableIgnoreInitializedProperties
struct Platform: Codable, Identifiable, Equatable, Hashable {
    let id = UUID()
    
    let introducedAt: String
    let unavailable: Bool?
    let beta: Bool?
    let name: String
    let deprecated: Bool?
    let deprecatedAt: String?
}

// swiftlint:enable line_length file_length type_body_length
