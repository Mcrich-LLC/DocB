//
//  CommonTypes.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/6/24.
//
// swiftlint:disable line_length

import Foundation

struct ImageStruct: Decodable, Identifiable, Equatable, Hashable {
    let id = UUID()
    
    let identifier: String
    let type: String
    
    enum CodingKeys: CodingKey {
        case id
        case identifier
        case type
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.identifier = try container.decode(String.self, forKey: .identifier)
        self.type = try container.decode(String.self, forKey: .type)
    }
}

struct LegalNotices: Decodable {
    let copyright: String
    let termsOfUse: String
    let privacyPolicy: String
}

struct ContentStruct: Decodable, Hashable, Identifiable, Equatable {
    let id = UUID()
    
    let text: String?
    let code: String?
    let identifier: String?
    let inlineContent: [ContentStruct]?
    let type: ContentType
    
    enum CodingKeys: CodingKey {
        case id
        case text
        case code
        case identifier
        case inlineContent
        case type
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.text = try container.decodeIfPresent(String.self, forKey: .text)
        self.code = try container.decodeIfPresent(String.self, forKey: .code)
        self.identifier = try container.decodeIfPresent(String.self, forKey: .identifier)
        self.inlineContent = try container.decodeIfPresent([ContentStruct].self, forKey: .inlineContent)
        self.type = try container.decode(ContentType.self, forKey: .type)
    }
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
    let mentions: [String]?
    let details: Details?
    
    enum CodingKeys: CodingKey {
        case id
        case kind
        case content
        case declarations
        case mentions
        case details
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.kind = try container.decode(ContentSection.Kind.self, forKey: .kind)
        self.content = try container.decodeIfPresent([ContentSection.Content].self, forKey: .content)
        self.declarations = try container.decodeIfPresent([ContentSection.Declaration].self, forKey: .declarations)
        self.mentions = try container.decodeIfPresent([String].self, forKey: .mentions)
        self.details = try container.decodeIfPresent(Details.self, forKey: .details)
    }
    
    enum Kind: String, Decodable {
        case content
        case declarations
        case mentions
        case details
        case kind
        case parameters
    }
    
    struct Details: Decodable, Identifiable {
        let id = UUID()
        
        let name: String
        let value: [Value]
        
        enum CodingKeys: CodingKey {
            case id
            case name
            case value
        }
        
        init(from decoder: any Decoder) throws {
            let container: KeyedDecodingContainer<ContentSection.Details.CodingKeys> = try decoder.container(keyedBy: ContentSection.Details.CodingKeys.self)
            self.name = try container.decode(String.self, forKey: ContentSection.Details.CodingKeys.name)
            self.value = try container.decode([ContentSection.Details.Value].self, forKey: ContentSection.Details.CodingKeys.value)
        }
        
        struct Value: Decodable {
            let baseType: String
        }
    }
    
    struct Declaration: Decodable, Identifiable {
        let id = UUID()
        let tokens: [Token]
        let languages: [String]
        let platforms: [PlatformName]
        
        enum CodingKeys: CodingKey {
            case id
            case tokens
            case languages
            case platforms
        }
        
        init(from decoder: any Decoder) throws {
            let container: KeyedDecodingContainer<ContentSection.Declaration.CodingKeys> = try decoder.container(keyedBy: ContentSection.Declaration.CodingKeys.self)
            self.tokens = try container.decode([ContentSection.Declaration.Token].self, forKey: ContentSection.Declaration.CodingKeys.tokens)
            self.languages = try container.decode([String].self, forKey: ContentSection.Declaration.CodingKeys.languages)
            self.platforms = try container.decode([PlatformName].self, forKey: ContentSection.Declaration.CodingKeys.platforms)
        }
        
        struct Token: Decodable {
            let text: String
            let kind: String
        }
    }
    
    struct Content: Decodable, Identifiable, Equatable {
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
        
        // List
        let termListItems: [TermListItem]?
        let unorderedListItems: [UnorderedListItem]?
        let orderedListItems: [UnorderedListItem]?
        
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
            case items
            case tabs
            case numberOfColumns
            case columns
            case code
            case style
            
        }
        
        init(from decoder: any Decoder) throws {
            let container: KeyedDecodingContainer<ContentSection.Content.CodingKeys> = try decoder.container(keyedBy: ContentSection.Content.CodingKeys.self)
            self.type = try container.decodeIfPresent(ContentType.self, forKey: ContentSection.Content.CodingKeys.type)
            self.identifier = try container.decodeIfPresent(String.self, forKey: ContentSection.Content.CodingKeys.identifier)
            self.anchor = try container.decodeIfPresent(String.self, forKey: ContentSection.Content.CodingKeys.anchor)
            self.level = try container.decodeIfPresent(Int.self, forKey: ContentSection.Content.CodingKeys.level)
            self.inlineContent = try container.decodeIfPresent([ContentStruct].self, forKey: ContentSection.Content.CodingKeys.inlineContent)
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
        }
        
        enum Style: String, Decodable, CaseIterable {
            case compactGrid
            case note
            case detailedGrid
            case important
            case value
            case list
        }
        
        struct Column: Decodable, Equatable {
            let size: Int
            let content: [Content]
        }
        
        struct Tab: Decodable, Equatable, Identifiable {
            let id = UUID()
            
            let content: [Content]
            let title: String
            
            enum CodingKeys: CodingKey {
                case id
                case content
                case title
            }
            
            init(from decoder: any Decoder) throws {
                let container: KeyedDecodingContainer<ContentSection.Content.Tab.CodingKeys> = try decoder.container(keyedBy: ContentSection.Content.Tab.CodingKeys.self)
                self.content = try container.decode([ContentSection.Content.Tab.Content].self, forKey: ContentSection.Content.Tab.CodingKeys.content)
                self.title = try container.decode(String.self, forKey: ContentSection.Content.Tab.CodingKeys.title)
            }
            
            struct Content: Decodable, Equatable, Identifiable {
                let id = UUID()
                
                let items: [Item]?
                let inlineContent: [ContentStruct]?
                let type: ContentType?
                
                enum CodingKeys: CodingKey {
                    case id
                    case items
                    case inlineContent
                    case type
                }
                
                init(from decoder: any Decoder) throws {
                    let container: KeyedDecodingContainer<ContentSection.Content.Tab.Content.CodingKeys> = try decoder.container(keyedBy: ContentSection.Content.Tab.Content.CodingKeys.self)
                    self.items = try container.decodeIfPresent([ContentSection.Content.Tab.Item].self, forKey: ContentSection.Content.Tab.Content.CodingKeys.items)
                    self.inlineContent = try container.decodeIfPresent([ContentStruct].self, forKey: ContentSection.Content.Tab.Content.CodingKeys.inlineContent)
                    self.type = try container.decodeIfPresent(ContentType.self, forKey: ContentSection.Content.Tab.Content.CodingKeys.type)
                }
            }
            
            struct Item: Decodable, Equatable, Identifiable {
                let id = UUID()
                
                let content: [ContentSection.Content]
                
                enum CodingKeys: CodingKey {
                    case id
                    case content
                }
                
                init(from decoder: any Decoder) throws {
                    let container: KeyedDecodingContainer<ContentSection.Content.Tab.Item.CodingKeys> = try decoder.container(keyedBy: ContentSection.Content.Tab.Item.CodingKeys.self)
                    self.content = try container.decode([ContentSection.Content].self, forKey: ContentSection.Content.Tab.Item.CodingKeys.content)
                }
            }
        }
        
        struct TermListItem: Decodable, Identifiable, Equatable {
            let id = UUID()
            let term: Term
            let definition: Definition
            
            enum CodingKeys: CodingKey {
                case id
                case term
                case definition
            }
            
            init(from decoder: any Decoder) throws {
                let container: KeyedDecodingContainer<ContentSection.Content.TermListItem.CodingKeys> = try decoder.container(keyedBy: ContentSection.Content.TermListItem.CodingKeys.self)
                self.term = try container.decode(ContentSection.Content.TermListItem.Term.self, forKey: ContentSection.Content.TermListItem.CodingKeys.term)
                self.definition = try container.decode(ContentSection.Content.TermListItem.Definition.self, forKey: ContentSection.Content.TermListItem.CodingKeys.definition)
            }
            
            struct Definition: Decodable, Equatable {
                let content: [ContentSection.Content]
            }
            
            struct Term: Decodable, Equatable {
                let inlineContent: [ContentStruct]
            }
        }
        
        struct UnorderedListItem: Decodable, Identifiable, Equatable {
            let id = UUID()
            
            let content: [ContentSection.Content]?
            
            enum CodingKeys: CodingKey {
                case id
                case content
            }
            
            init(from decoder: any Decoder) throws {
                let container: KeyedDecodingContainer<ContentSection.Content.UnorderedListItem.CodingKeys> = try decoder.container(keyedBy: ContentSection.Content.UnorderedListItem.CodingKeys.self)
                self.content = try container.decodeIfPresent([ContentSection.Content].self, forKey: ContentSection.Content.UnorderedListItem.CodingKeys.content)
            }
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
    let images: [ImageStruct]?
    
    init(title: String?, abstract: [ContentStruct]?, identifier: String, kind: String?, type: String, url: String?, role: Role?, fragments: [Fragment]?, deprecated: Bool?, variants: [Variant]?, images: [ImageStruct]?) {
        self.title = title
        self.abstract = abstract
        self.identifier = identifier
        self.kind = kind
        self.type = type
        self.url = url
        self.role = role
        self.fragments = fragments
        self.deprecated = deprecated
        self.variants = variants
        self.images = images
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
        self.variants = try container.decodeIfPresent([Reference.Variant].self, forKey: .variants)
        self.images = try container.decodeIfPresent([ImageStruct].self, forKey: .images)
    }
    
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
        case codeListing
        case link
        case dictionarySymbol
        case pseudoSymbol
        case task
        case subsection
        case unknown
                
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
}

// MARK: Content Types

enum ContentType: String, Decodable, Equatable {
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
}

// MARK: Platforms
enum PlatformName: String, Decodable {
    case iOS
    case iPadOS
    case macCatalyst = "Mac Catalyst"
    case macOS
    case tvOS
    case visionOS
    case watchOS
    case xcode = "Xcode"
}

struct Platform: Decodable, Identifiable {
    let id = UUID()
    
    let introducedAt: String
    let unavailable: Bool?
    let beta: Bool?
    let name: PlatformName
    let deprecated: Bool?
    let deprecatedAt: String?
    
    enum CodingKeys: CodingKey {
        case id
        case introducedAt
        case unavailable
        case beta
        case name
        case deprecated
        case deprecatedAt
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.introducedAt = try container.decode(String.self, forKey: .introducedAt)
        self.unavailable = try container.decodeIfPresent(Bool.self, forKey: .unavailable)
        self.beta = try container.decodeIfPresent(Bool.self, forKey: .beta)
        self.name = try container.decode(PlatformName.self, forKey: .name)
        self.deprecated = try container.decodeIfPresent(Bool.self, forKey: .deprecated)
        self.deprecatedAt = try container.decodeIfPresent(String.self, forKey: .deprecatedAt)
    }
}

// swiftlint:enable line_length
