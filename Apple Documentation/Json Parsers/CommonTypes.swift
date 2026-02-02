//
//  CommonTypes.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/6/24.
//
// swiftlint:disable line_length file_length

import Foundation
import SwiftUI
import EnhancedCodable

/// Condenses content by merging adjacent text fragments and processing inline content.
///
/// This helper function iterates through the provided content, merging text nodes where appropriate
/// and handling lists and other inline elements to create a more compact representation.
///
/// - Parameter content: The array of `ContentSection.Content` to process.
/// - Returns: A condensed array of `ContentSection.Content`.
private func getCondensedContent(_ content: [ContentSection.Content]) -> [ContentSection.Content] {
    var newContent: [ContentSection.Content] = []
    
    for fragment in content {
        
        var newInlineContent = fragment.inlineContent ?? []
        
        if let text = fragment.text {
            let font: (CodableFont?, CodableFontWeight?) = switch fragment.level {
            case 3:
                (.title3, .bold)
            case 2:
                (.title2, .bold)
            case 1:
                (.title, .bold)
            default:
                (nil, nil)
            }
            
            let priorText: ContentStruct = .init(text: text, code: nil, identifier: nil, metadata: nil, inlineContent: nil, font: font.0, fontWeight: font.1, type: fragment.type ?? .text, orderedListInt: nil)
            newInlineContent.insert(priorText, at: 0)
        }
        
        newInlineContent.append(contentsOf: fragment.inlineContentFromOrderedListItems())
        newInlineContent.append(contentsOf: fragment.inlineContentFromUnorderedListItems())
        newInlineContent.append(contentsOf: fragment.inlineContentFromTermListItems())
        
        guard let inlineContent = newContent.last?.inlineContent,
                !newInlineContent.isEmpty,
                !(Array(Set(newInlineContent.map(\.type))).sorted(by: { $0.rawValue > $1.rawValue }) == [.image, .video] || Array(Set(newInlineContent.map(\.type))) == [.image] || Array(Set(newInlineContent.map(\.type))) == [.video]),
                !(Array(Set(inlineContent.map(\.type))).sorted(by: { $0.rawValue > $1.rawValue }) == [.image, .video] || Array(Set(inlineContent.map(\.type))) == [.image] || Array(Set(inlineContent.map(\.type))) == [.video])
        else {
            var fragment = fragment
            
            if !newInlineContent.isEmpty {
                fragment.inlineContent = newInlineContent
            }
            
            newContent.append(fragment)
            continue
        }
        
        guard fragment.type != .heading else {
            newContent[newContent.count - 1].inlineContent?.append(contentsOf: [ContentStruct.doubleLineBreak] + newInlineContent)
            continue
        }
        newContent[newContent.count - 1].inlineContent?.append(contentsOf: [ContentStruct.oneAndAHalfLineBreak] + newInlineContent)
    }
    
    return newContent
}

/// A structure representing an image resource.
///
/// `ImageStruct` holds the identifier and type of an image used within the documentation.
@CodableIgnoreInitializedProperties
struct ImageStruct: Codable, Identifiable, Equatable, Hashable {
    /// A unique identifier for the image struct instance.
    let id = UUID()
    
    /// The string identifier for the image resource.
    let identifier: String
    /// The type of the image, determining how it should be rendered or categorized.
    let type: ImageType
    
    /// Enum representing the possible types of images.
    enum ImageType: String, Codable, CaseIterable {
        /// An icon image.
        case icon
        /// A card image.
        case card
    }
}

/// A structure containing legal notice information.
struct LegalNotices: Codable, Equatable, Hashable {
    /// The copyright notice text.
    let copyright: String
    /// The terms of use text.
    let termsOfUse: String
    /// The privacy policy text.
    let privacyPolicy: String
}

/// Enum representing supported font styles that can be encoded/decoded.
///
/// Matches SwiftUI's `Font` styles.
enum CodableFont: String, CaseIterable, Codable {
    case body, callout, caption, caption2, footnote, headline, subheadline, largeTitle, title, title2, title3
    
    /// The corresponding SwiftUI `Font`.
    var font: Font {
        switch self {
        case .body:
                .body
        case .callout:
                .callout
        case .caption:
                .caption
        case .caption2:
                .caption2
        case .footnote:
                .footnote
        case .headline:
                .headline
        case .subheadline:
                .subheadline
        case .largeTitle:
                .largeTitle
        case .title:
                .title
        case .title2:
                .title2
        case .title3:
                .title3
        }
    }
}

/// Enum representing supported font weights that can be encoded/decoded.
///
/// Matches SwiftUI's `Font.Weight`.
enum CodableFontWeight: String, CaseIterable, Codable {
    case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black
    
    /// The corresponding SwiftUI `Font.Weight`.
    var fontWeight: Font.Weight {
        switch self {
        case .ultraLight:
                .ultraLight
        case .thin:
                .thin
        case .light:
                .light
        case .regular:
                .regular
        case .medium:
                .medium
        case .semibold:
                .semibold
        case .bold:
                .bold
        case .heavy:
                .heavy
        case .black:
                .black
        }
    }
}

/// A structure representing a piece of content.
///
/// `ContentStruct` matches the `Content` structure found in the JSON documentation,
/// but is flattened or adapted for easier consumption in the app.
@CodableIgnoreInitializedProperties
struct ContentStruct: Codable, Hashable, Identifiable, Equatable, Sendable {
    /// A unique identifier for the content struct instance.
    let id = UUID()
    
    /// The text content, if available.
    let text: String?
    /// The code content, if available.
    let code: String?
    /// The identifier for the content.
    let identifier: String?
    /// Metadata associated with the content.
    let metadata: Metadata?
    /// Nested inline content.
    var inlineContent: [ContentStruct]?
    /// The dictionary-encoded font style.
    fileprivate(set) var font: CodableFont?
    /// The dictionary-encoded font weight.
    fileprivate(set) var fontWeight: CodableFontWeight?
    /// The type of content.
    fileprivate(set) var type: ContentType
    /// The ordered list index, if this item is part of an ordered list.
    fileprivate(set) var orderedListInt: Int?
    
    // MARK: Static Helpers
    static fileprivate let doubleLineBreak = ContentStruct(text: "\n\n", code: nil, identifier: nil, metadata: nil, inlineContent: nil, font: nil, fontWeight: nil, type: .text, orderedListInt: nil)
    static fileprivate let oneAndAHalfLineBreak = ContentStruct(text: "/%1.5_break_/%", code: nil, identifier: nil, metadata: nil, inlineContent: nil, font: nil, fontWeight: nil, type: .text, orderedListInt: nil)
    static fileprivate let lineBreak = ContentStruct(text: "\n", code: nil, identifier: nil, metadata: nil, inlineContent: nil, font: nil, fontWeight: nil, type: .text, orderedListInt: nil)
    
    /// Converts the content struct into a flattened `AttributedString`.
    ///
    /// - Returns: An `AttributedString` representation of the content.
    func getFlattenedAttributedString() -> AttributedString {
        var attributedString = AttributedString(text ?? "")
        
        attributedString = applyAttributedStringFontAttributes(attributedString)
        
        for inline in (inlineContent ?? []) {
            let substring = applyAttributedStringFontAttributes(inline.getFlattenedAttributedString())
            attributedString += substring
        }
        
        return attributedString
    }
    
    private func applyAttributedStringFontAttributes(_ attributedString: AttributedString) -> AttributedString {
        var attributedString = attributedString
        
        if attributedString.font == nil {
            attributedString.font = font?.font ?? .body
        }
        
        switch type {
        case .emphasis:
            attributedString.font = attributedString.font?.italic()
        case .strong:
            attributedString.font = attributedString.font?.bold()
        default:
            break
        }
        
        return attributedString
    }
    
    @CodableIgnoreInitializedProperties
    struct Metadata: Codable, Hashable, Equatable {
        let id: UUID = UUID()
        
        let abstract: [ContentStruct]?
    }
}

extension [ContentStruct] {
    var isAllSomeFormOfText: Bool {
        let allowableTypes: [ContentType] = [.text, .emphasis, .strong]
        return !contains(where: { content in
            guard let innerContent = content.inlineContent else { return !allowableTypes.contains(content.type) }
            
            return innerContent.isAllSomeFormOfText && !allowableTypes.contains(content.type)
        })
    }
}

/// A text fragment with an associated kind.
struct Fragment: Codable, Hashable {
    /// The text content of the fragment.
    let text: String
    /// The kind of fragment (e.g., "keyword", "identifier").
    let kind: String
}

// swiftlint:disable:next type_body_length
/// A section of content within the documentation.
///
/// `ContentSection` represents various sections like declarations, details, and parameters.
@CodableIgnoreInitializedProperties struct ContentSection: Codable, Identifiable, Equatable, Hashable {
    /// A unique identifier for the content section.
    let id = UUID()
    
    /// The kind of section.
    let kind: Kind
    /// The array of content items within this section.
    let content: [Content]?
    var condensedContent: [Content] { getCondensedContent(content ?? []) }
    
    var declarations: [Declaration]?
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
    
    /// Enum representing the kind of content section.
    enum Kind: String, Codable, Equatable, Hashable {
        /// General content section.
        case content
        /// Declarations section.
        case declarations
        /// Mentions section.
        case mentions
        /// Details section.
        case details
        /// Kind section (deprecated or specific usage).
        case kind
        /// Parameters section.
        case parameters
        /// REST endpoint section.
        case restEndpoint
        /// REST body section.
        case restBody
        /// REST responses section.
        case restResponses
        /// Properties section.
        case properties
        /// Type identifier section.
        case typeIdentifier
        /// Text content.
        case text
        /// Attributes section.
        case attributes
        /// REST parameters section.
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
        let platforms: [String]?
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            tokens = try container.decode([Token].self, forKey: .tokens)
            languages = try container.decode([String].self, forKey: .languages)
            platforms = try container.decodeIfPresent([String].self, forKey: .languages)
        }
    }
    
    struct Token: Codable, Equatable, Hashable {
        let text: String?
        let kind: String
        let code: String?
    }
    
    struct Content: Codable, Identifiable, Equatable, Hashable, Sendable {
        let id = UUID()
        let type: ContentType?
        
        // MARK: Media
        /// The identifier for the media resource.
        let identifier: String?
        
        // MARK: Heading
        /// The anchor for the heading, used for linking.
        let anchor: String?
        /// The level of the heading (e.g., 1 for main title, 2 for section).
        let level: Int?
        
        // MARK: Text
        /// Code content if this fragment represents code.
        let code: [String]?
        /// Text content.
        let text: String?
        
        // MARK: Links
        /// The style of the link or content.
        let style: Style?
        /// Items used in links.
        let linkItems: [String]?
        
        // MARK: Inline Content
        /// Nested inline content elements.
        var inlineContent: [ContentStruct]?
        
        // MARK: Subcontent
        /// Nested content array.
        let content: [Content]?
        
        // MARK: List
        /// Items for a term list.
        let termListItems: [TermListItem]?
        /// Items for an unordered list.
        let unorderedListItems: [UnorderedListItem]?
        /// Items for an ordered list.
        let orderedListItems: [UnorderedListItem]?
        
        func inlineContentFromTermListItems() -> [ContentStruct] {
            (termListItems ?? []).enumerated().flatMap({ n, item in
                let termContent = item.term.inlineContent.map { content in
                    var content = content
                    content.fontWeight = .semibold
                    return content
                }
                let definitionContent = getCondensedContent(item.definition.content).flatMap { $0.inlineContent ?? [] }
                
                let content = termContent + [ContentStruct.lineBreak] + definitionContent
                return (n > 0 ? [ContentStruct.oneAndAHalfLineBreak] : []) + content
            })
        }
        
        func inlineContentFromUnorderedListItems() -> [ContentStruct] {
            (unorderedListItems ?? []).flatMap({ item in
                (item.content ?? []).flatMap { c in
                    let inlineContent: [ContentStruct] = (c.inlineContent ?? []).flatMap { content in
                        let inline = (content.inlineContent ?? []).map { i in
                            var i = i
                            if i.type == .text {
                                i.type = content.type
                            }
                            
                            return i
                        }
                        
                        var content = content
                        content.inlineContent = []
                        
                        return [content] + inline
                    }
                    
                    guard var inlineContentFirstItem = inlineContent.first else { return c.inlineContentFromUnorderedListItems() }
                    inlineContentFirstItem.type = .unorderedList
                    
                    return [inlineContentFirstItem] + inlineContent.dropFirst() + c.inlineContentFromUnorderedListItems()
                }
            }).enumerated().flatMap { n, content in
                return (n > 0 && content.type == .unorderedList) ? [ContentStruct.oneAndAHalfLineBreak, content] : [content]
            }
        }
        
        func inlineContentFromOrderedListItems() -> [ContentStruct] {
            let flattenedItems: [ContentStruct] = (orderedListItems ?? []).flatMap({ item in
                (item.content ?? []).flatMap { c in
                    let inlineContent: [ContentStruct] = (c.inlineContent ?? []).flatMap { content in
                        let inline = (content.inlineContent ?? []).map { i in
                            var i = i
                            if i.type == .text {
                                i.type = content.type
                            }
                            
                            return i
                        }
                        
                        var content = content
                        content.inlineContent = []
                        
                        return [content] + inline
                    }
                    guard var inlineContentFirstItem = inlineContent.first else { return c.inlineContentFromOrderedListItems() }
                    inlineContentFirstItem.type = .orderedList
                    
                    return [inlineContentFirstItem] + inlineContent.dropFirst() + c.inlineContentFromOrderedListItems()
                }
            })
            var orderedListInt = 0
            var items: [ContentStruct] = []
            
            for item in flattenedItems {
                guard item.type == .orderedList else {
                    items.append(item)
                    continue
                }
                var item = item
                item.orderedListInt = orderedListInt+1
                orderedListInt += 1
                
                if !items.isEmpty {
                    items.append(.oneAndAHalfLineBreak)
                }
                items.append(item)
            }
            
            return items
        }
        
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
            case hidden
            
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
            var condensedContent: [Content] {
                getCondensedContent(content)
            }
            
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

struct VariantOverride: Codable, Equatable, Hashable {
    let traits: [Variant.Trait]
    let patch: [Patch]
    
    struct Patch: Codable, Equatable, Hashable {
        let op: String
        let path: String
        let value: AltDeclarationsWrapper?
        
        struct AltDeclarationsWrapper: Codable, Equatable, Hashable {
            let declarations: [ContentSection.Declaration]
            let kind: String
        }
        
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            op = try container.decode(String.self, forKey: .op)
            path = try container.decode(String.self, forKey: .path)
            value = try? container.decodeIfPresent(AltDeclarationsWrapper.self, forKey: .value)
        }
    }
}

/// A reference to another documentation topic or external resource.
struct Reference: Codable, Hashable, Identifiable, Sendable {
    /// A unique identifier for the reference instance.
    let id = UUID()
    
    /// The title of the reference.
    let title: String?
    /// An abstract or summary of the referenced content.
    let abstract: [ContentStruct]?
    /// The unique identifier string for the reference.
    let identifier: String
    /// The kind of reference (e.g., "symbol").
    let kind: String?
    /// The type of reference (e.g., "topic").
    let type: String
    /// The URL associated with the reference.
    let url: String?
    /// The role of the reference.
    let role: Role?
    /// Fragments associated with the reference.
    let fragments: [Fragment]?
    /// Indicates if the reference is deprecated.
    let deprecated: Bool?
    /// Indicates if the reference is beta.
    let beta: Bool?
    /// Variants of the reference (e.g., for different languages).
    let variants: [Variant]?
    /// Images associated with the reference.
    let images: [ImageStruct]?
    /// The DocC site information if available.
    var docCSite: DocCSiteDTO?
    
    /// Determines if the reference points to an external site.
    var isExternalReference: Bool {
        url?.lowercased().contains("/documentation") == false
    }
    
    var externalURL: URL? {
        guard let urlString = url else {
            return nil
        }
        
        guard let docCSite = docCSite else {
            return URL(string: "https://developer.apple.com\(urlString)")
        }
        
        return docCSite.url.appending(path: urlString)
    }
    
    func isEqual(to reference: Self) -> Bool {
        guard let currentUrl = URL(string: identifier),
              let url = URL(string: reference.identifier)
        else {
            return identifier.lowercased() == reference.identifier.lowercased()
        }
        
        return currentUrl.path().lowercased() == url.path().lowercased()
    }
    
    init(title: String?, abstract: [ContentStruct]?, identifier: String, kind: String?, type: String, url: String?, role: Role?, fragments: [Fragment]?, deprecated: Bool?, beta: Bool?, variants: [Variant]?, images: [ImageStruct]?, docCSite: DocCSiteDTO?) {
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
/// Enum representing the role of a documentation item.
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
        case .overview:
                .pointBottomleftFilledForwardToPointToprightScurvepath
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
    case thematicBreak
}

// MARK: Platforms
@CodableIgnoreInitializedProperties
struct Platform: Codable, Identifiable, Equatable, Hashable {
    let id = UUID()
    
    let introducedAt: String?
    let unavailable: Bool?
    let beta: Bool?
    let name: String
    let deprecated: Bool?
    let deprecatedAt: String?
}

// swiftlint:enable line_length file_length
