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
    
    /// A content struct representing a double line break.
    ///
    /// Used for separating paragraphs or sections.
    static fileprivate let doubleLineBreak = ContentStruct(text: "\n\n", code: nil, identifier: nil, metadata: nil, inlineContent: nil, font: nil, fontWeight: nil, type: .text, orderedListInt: nil)
    
    /// A content struct representing a 1.5 line break (custom marker).
    ///
    /// Used for spacing around lists or other block elements.
    static fileprivate let oneAndAHalfLineBreak = ContentStruct(text: "/%1.5_break_/%", code: nil, identifier: nil, metadata: nil, inlineContent: nil, font: nil, fontWeight: nil, type: .text, orderedListInt: nil)
    
    /// A content struct representing a single line break.
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
    
    /// Metadata associated with content, such as an abstract or summary.
    @CodableIgnoreInitializedProperties
    struct Metadata: Codable, Hashable, Equatable {
        /// A unique identifier for the metadata instance.
        let id: UUID = UUID()
        
        /// An abstract or summary description.
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
    /// The kind of fragment (e.g., "keyword", "identifier", "text").
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
    
    /// Declarations within this content section.
    var declarations: [Declaration]?
    /// A list of identifiers mentioned in this section.
    let mentions: [String]?
    /// Details associated with the content.
    let details: Details?
    
    // MARK: Web Endpoint Properties
    
    /// The REST responses associated with an endpoint.
    let items: [RestResponse]?
    /// The body content type for a REST endpoint.
    let bodyContentType: [RestResponse.RestResponseType]?
    /// The MIME type for a REST endpoint.
    let mimeType: String?
    /// The title of the section.
    let title: String?
    /// The tokens associated with the section.
    let tokens: [Token]?
    /// The attributes associated with the section.
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
    
    /// A structure representing an attribute of a REST endpoint.
    @CodableIgnoreInitializedProperties
    struct Attribute: Codable, Identifiable, Equatable, Hashable {
        /// A unique identifier for the attribute.
        let id = UUID()
        
        /// The name of the attribute.
        let name: String?
    }
    
    /// A structure representing a REST API response.
    @CodableIgnoreInitializedProperties
    struct RestResponse: Codable, Identifiable, Equatable, Hashable {
        /// A unique identifier for the response.
        let id = UUID()
        
        /// The types of data returned in the response.
        let type: [RestResponseType]
        /// The HTTP status code of the response.
        let status: Int?
        /// The MIME type of the response content.
        let mimeContent: String?
        /// The detailed content description of the response.
        let content: [ContentSection.Content]
        /// The reason phrase associated with the response status.
        let reason: String?
        /// The name of the response.
        let name: String?
        
        /// A structure representing the type definition within a REST response.
        @CodableIgnoreInitializedProperties
        struct RestResponseType: Codable, Identifiable, Equatable, Hashable {
            /// A unique identifier for the response type.
            let id = UUID()
            
            /// The text representation of the type.
            let text: String
            /// The kind of the type (e.g., type identifier).
            let kind: Kind
            /// The precise identifier for the type.
            let preciseIdentifier: String?
            /// The identifier for the type.
            let identifier: String?
        }
    }
    
    /// A structure containing details about a symbol or entity.
    @CodableIgnoreInitializedProperties
    struct Details: Codable, Identifiable, Equatable, Hashable {
        /// A unique identifier for the details.
        let id = UUID()
        
        /// The name of the detail.
        let name: String
        /// The values associated with the detail.
        let value: [Value]
        
        /// A structure representing a value within details.
        struct Value: Codable, Equatable, Hashable {
            /// The base type string of the value.
            let baseType: String
        }
    }
    
    /// A structure representing a declaration in code.
    @CodableIgnoreInitializedProperties
    struct Declaration: Codable, Identifiable, Equatable, Hashable {
        /// A unique identifier for the declaration.
        let id = UUID()
        /// The tokens that make up the declaration.
        let tokens: [Token]
        /// The languages in which this declaration is valid.
        let languages: [String]
        /// The platforms on which this declaration is available.
        let platforms: [String]?
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            tokens = try container.decode([Token].self, forKey: .tokens)
            languages = try container.decode([String].self, forKey: .languages)
            platforms = try container.decodeIfPresent([String].self, forKey: .languages)
        }
    }
    
    /// A lexical token representing a piece of code or text.
    struct Token: Codable, Equatable, Hashable {
        /// The text content of the token.
        let text: String?
        /// The kind of token (e.g., keyword, identifier).
        let kind: String
        /// The code snippet associated with the token.
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
        /// Code content if this fragment represents code, split by lines.
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
        /// Items for an unordered list (bullet points).
        let unorderedListItems: [UnorderedListItem]?
        /// Items for an ordered list (number points).
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
        
        // MARK: Layout
        
        /// The tabs within a tab navigator.
        let tabs: [Tab]?
        
        // MARK: Grid/Table
        
        /// The number of columns in a row.
        let numberOfColumns: Int?
        /// The columns in a row.
        let columns: [Column]?
        /// The rows in a table.
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
        
        /// A column within a row.
        struct Column: Codable, Equatable, Hashable {
            /// The relative size/weight of the column.
            let size: Int
            /// The content within the column.
            let content: [Content]
        }
        
        /// A tab within a tab navigator.
        @CodableIgnoreInitializedProperties
        struct Tab: Codable, Equatable, Identifiable, Hashable {
            /// A unique identifier for the tab.
            let id = UUID()
            
            /// The content within the tab.
            let content: [Content]
            
            /// A condensed version of the tab's content.
            var condensedContent: [Content] {
                getCondensedContent(content)
            }
            
            /// The title of the tab.
            let title: String
            
            /// An item within a tab.
            @CodableIgnoreInitializedProperties
            struct Item: Codable, Equatable, Identifiable, Hashable {
                /// A unique identifier for the item.
                let id = UUID()
                
                /// The content of the item.
                let content: [ContentSection.Content]
            }
        }
        
        /// An item in a term list (definition list).
        @CodableIgnoreInitializedProperties
        struct TermListItem: Codable, Identifiable, Equatable, Hashable {
            /// A unique identifier for the term list item.
            let id = UUID()
            /// The term being defined.
            let term: Term
            /// The definition of the term.
            let definition: Definition
            
            /// The definition content wrapper.
            struct Definition: Codable, Equatable, Hashable {
                /// The content of the definition.
                let content: [ContentSection.Content]
            }
            
            /// The term content wrapper.
            struct Term: Codable, Equatable, Hashable {
                /// The inline content representing the term.
                let inlineContent: [ContentStruct]
            }
        }
        
        /// A structure representing a list item in an unordered list.
        @CodableIgnoreInitializedProperties
        struct UnorderedListItem: Codable, Identifiable, Equatable, Hashable {
            /// A unique identifier for the list item.
            let id = UUID()
            
            /// The content of the list item.
            let content: [ContentSection.Content]?
        }
    }
}

/// A structure representing a variant of documentation (e.g., for a specific language).
struct Variant: Codable, Equatable, Hashable {
    /// The traits defining the variant.
    let traits: [Trait]
    /// The paths associated with this variant.
    let paths: [String]
    
    /// A trait defining a characteristic of a variant.
    struct Trait: Codable, Equatable, Hashable {
        /// The interface language for this trait.
        let interfaceLanguage: PreferedProgrammingLanguage
    }
}

/// A structure representing an override to apply to documentation variants.
struct VariantOverride: Codable, Equatable, Hashable {
    /// The traits that match the variants to override.
    let traits: [Variant.Trait]
    /// The patches to apply.
    let patch: [Patch]
    
    /// A structure representing a JSON patch operation.
    struct Patch: Codable, Equatable, Hashable {
        /// The operation type (e.g., "replace").
        let op: String
        /// The path to the value to modify.
        let path: String
        /// The new value wrapper, if applicable.
        let value: AltDeclarationsWrapper?
        
        /// A wrapper for alternative declarations in a patch.
        struct AltDeclarationsWrapper: Codable, Equatable, Hashable {
            /// The new declarations.
            let declarations: [ContentSection.Declaration]
            /// The kind of the wrapper.
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
