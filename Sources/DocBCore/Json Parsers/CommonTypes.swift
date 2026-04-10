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
import SFSafeSymbols

/// Condenses nested content blocks into render-friendly inline segments.
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

/// Image metadata for DocC references and content blocks.
@CodableIgnoreInitializedProperties
public struct ImageStruct: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id = UUID()
    
    /// Image resource identifier in the references map.
    public let identifier: String
    /// Categorized image usage type.
    public let type: ImageType
    
    /// Supported DocC image usage categories.
    public enum ImageType: String, Codable, CaseIterable, Sendable {
        case icon
        case card
    }
}

/// Legal notice metadata attached to documentation payloads.
public struct LegalNotices: Codable, Equatable, Hashable, Sendable {
    public let copyright: String
    public let termsOfUse: String
    public let privacyPolicy: String
}

/// Codable representation of SwiftUI font styles used in parsed content.
public enum CodableFont: String, CaseIterable, Codable, Sendable {
    case body, callout, caption, caption2, footnote, headline, subheadline, largeTitle, title, title2, title3
    
    /// Corresponding SwiftUI font.
    public var font: Font {
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

/// Codable representation of SwiftUI font weights used in parsed content.
public enum CodableFontWeight: String, CaseIterable, Codable, Sendable {
    case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black
    
    /// Corresponding SwiftUI font weight.
    public var fontWeight: Font.Weight {
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

/// Recursive inline content fragment used to render text, lists, emphasis, and metadata.
@CodableIgnoreInitializedProperties
public struct ContentStruct: Codable, Hashable, Identifiable, Equatable, Sendable {
    public let id = UUID()
    
    /// Plain text segment content.
    public let text: String?
    /// Code segment content.
    public let code: String?
    /// Optional reference identifier associated with this segment.
    public let identifier: String?
    /// Optional supplemental metadata.
    public let metadata: Metadata?
    /// Nested inline content segments.
    public var inlineContent: [ContentStruct]?
    /// Optional font style hint for rendering.
    public fileprivate(set) var font: CodableFont?
    /// Optional font weight hint for rendering.
    public fileprivate(set) var fontWeight: CodableFontWeight?
    /// Segment content type.
    public fileprivate(set) var type: ContentType
    /// Ordered-list number used when rendering ordered list content.
    public fileprivate(set) var orderedListInt: Int?
    
    static fileprivate let doubleLineBreak = ContentStruct(text: "\n\n", code: nil, identifier: nil, metadata: nil, inlineContent: nil, font: nil, fontWeight: nil, type: .text, orderedListInt: nil)
    static fileprivate let oneAndAHalfLineBreak = ContentStruct(text: "/%1.5_break_/%", code: nil, identifier: nil, metadata: nil, inlineContent: nil, font: nil, fontWeight: nil, type: .text, orderedListInt: nil)
    static fileprivate let lineBreak = ContentStruct(text: "\n", code: nil, identifier: nil, metadata: nil, inlineContent: nil, font: nil, fontWeight: nil, type: .text, orderedListInt: nil)
    
    /// Flattens nested inline content into a single attributed string.
    public func getFlattenedAttributedString() -> AttributedString {
        var attributedString = AttributedString(text ?? "")
        
        attributedString = applyAttributedStringFontAttributes(attributedString)
        
        for inline in (inlineContent ?? []) {
            let substring = applyAttributedStringFontAttributes(inline.getFlattenedAttributedString())
            attributedString += substring
        }
        
        return attributedString
    }
    
    /// Applies font and emphasis attributes to attributed text according to content metadata.
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
    
    /// Supplemental metadata attached to an inline content fragment.
    @CodableIgnoreInitializedProperties
    public struct Metadata: Codable, Hashable, Equatable, Sendable {
        /// Stable identifier for diffable/UI usage.
        public let id: UUID = UUID()
        
        /// Optional abstract content associated with this metadata entry.
        public let abstract: [ContentStruct]?
    }
}

extension [ContentStruct] {
    /// Whether all items (including nested inline content) are plain or emphasized text.
    public var isAllSomeFormOfText: Bool {
        let allowableTypes: [ContentType] = [.text, .emphasis, .strong]
        return !contains(where: { content in
            guard let innerContent = content.inlineContent else { return !allowableTypes.contains(content.type) }
            
            return innerContent.isAllSomeFormOfText && !allowableTypes.contains(content.type)
        })
    }
}

/// Raw token fragment used by declarations and reference metadata.
public struct Fragment: Codable, Hashable, Sendable {
    /// Fragment text content.
    public let text: String
    /// Fragment semantic kind (identifier, punctuation, etc.).
    public let kind: String
}

// swiftlint:disable:next type_body_length
/// Parsed DocC content section supporting narrative, declarations, REST docs, and structured blocks.
@CodableIgnoreInitializedProperties public struct ContentSection: Codable, Identifiable, Equatable, Hashable, Sendable {
    /// Stable identifier for diffable/UI usage.
    public let id = UUID()
    
    /// Section kind discriminator.
    public let kind: Kind
    /// Raw section content blocks.
    public let content: [Content]?
    /// Condensed content optimized for article rendering.
    public var condensedContent: [Content] { getCondensedContent(content ?? []) }
    
    /// Declarations payload for symbol sections.
    public var declarations: [Declaration]?
    /// Mentioned-reference identifiers for mentions sections.
    public let mentions: [String]?
    /// Details payload for details sections.
    public let details: Details?
    
    // Web Endpoint
    /// REST response/property items for endpoint sections.
    public let items: [RestResponse]?
    /// Declared body content types for REST body sections.
    public let bodyContentType: [RestResponse.RestResponseType]?
    /// MIME type string for REST body/response sections.
    public let mimeType: String?
    /// Section title.
    public let title: String?
    /// Token stream used for endpoint/declaration code reconstruction.
    public let tokens: [Token]?
    /// Attribute definitions for REST attributes sections.
    public let attributes: [Attribute]?
    
    /// Content-section discriminator used to drive rendering and decoding behavior.
    public enum Kind: String, Codable, Equatable, Hashable, Sendable {
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
    
    /// REST attribute model for endpoint documentation.
    @CodableIgnoreInitializedProperties
    public struct Attribute: Codable, Identifiable, Equatable, Hashable, Sendable {
        /// Stable identifier for diffable/UI usage.
        public let id = UUID()
        
        /// Attribute name presented in REST attribute sections.
        public let name: String?
    }
    
    /// REST response documentation block.
    @CodableIgnoreInitializedProperties
    public struct RestResponse: Codable, Identifiable, Equatable, Hashable, Sendable {
        /// Stable identifier for diffable/UI usage.
        public let id = UUID()
        
        /// Type/token descriptors associated with this response/body/property item.
        public let type: [RestResponseType]
        /// HTTP status code for response entries.
        public let status: Int?
        /// MIME content description for this response item.
        public let mimeContent: String?
        /// Narrative content describing this response item.
        public let content: [ContentSection.Content]
        /// Human-readable reason phrase or summary.
        public let reason: String?
        /// Optional item name (for properties/parameters).
        public let name: String?
        
        /// Token metadata describing HTTP types and related identifiers.
        @CodableIgnoreInitializedProperties
        public struct RestResponseType: Codable, Identifiable, Equatable, Hashable, Sendable {
            /// Stable identifier for diffable/UI usage.
            public let id = UUID()
            
            /// Display text for this response type token.
            public let text: String
            /// Token kind/classification.
            public let kind: Kind
            /// Optional precise identifier from DocC payloads.
            public let preciseIdentifier: String?
            /// Optional identifier used for linking this type.
            public let identifier: String?
        }
    }
    
    /// Key/value details section for symbol or endpoint metadata.
    @CodableIgnoreInitializedProperties
    public struct Details: Codable, Identifiable, Equatable, Hashable, Sendable {
        /// Stable identifier for diffable/UI usage.
        public let id = UUID()
        
        /// Details field name.
        public let name: String
        /// One or more detail values associated with `name`.
        public let value: [Value]
        
        /// Individual details value entry.
        public struct Value: Codable, Equatable, Hashable, Sendable {
            /// Normalized/base type name for the details value.
            public let baseType: String
        }
    }
    
    /// Language-specific declaration block for symbols.
    @CodableIgnoreInitializedProperties
    public struct Declaration: Codable, Identifiable, Equatable, Hashable, Sendable {
        /// Stable identifier for diffable/UI usage.
        public let id = UUID()
        /// Token stream that reconstructs declaration text.
        public let tokens: [Token]
        /// Interface languages this declaration applies to.
        public let languages: [String]
        /// Optional platform qualifiers for this declaration.
        public let platforms: [String]?
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            tokens = try container.decode([Token].self, forKey: .tokens)
            languages = try container.decode([String].self, forKey: .languages)
            platforms = try container.decodeIfPresent([String].self, forKey: .languages)
        }
    }
    
    /// Token element used inside declaration and endpoint sections.
    public struct Token: Codable, Equatable, Hashable, Sendable {
        /// Token display text.
        public let text: String?
        /// Token classification.
        public let kind: String
        /// Optional code payload for this token.
        public let code: String?
    }
    
    /// Generic DocC content node supporting nested blocks, tables, tabs, and list structures.
    public struct Content: Codable, Identifiable, Equatable, Hashable, Sendable {
        /// Stable identifier for diffable/UI usage.
        public let id = UUID()
        /// Content node type discriminator.
        public let type: ContentType?
        
        // Media
        /// Media/reference identifier.
        public let identifier: String?
        
        // Heading
        /// Anchor identifier for heading nodes.
        public let anchor: String?
        /// Heading depth level.
        public let level: Int?
        
        // Text
        /// Code lines for code/codeListing content.
        public let code: [String]?
        /// Plain text for paragraph/text/heading content.
        public let text: String?
        
        // Links
        /// Link rendering style hint.
        public let style: Style?
        /// Link target identifiers.
        public let linkItems: [String]?
        
        // Inline Content
        /// Nested inline content fragments.
        public var inlineContent: [ContentStruct]?
        
        // Subcontent
        /// Nested content blocks.
        public let content: [Content]?
        
        // List
        /// Term-list entries for `.termList` nodes.
        public let termListItems: [TermListItem]?
        /// Unordered-list entries for `.unorderedList` nodes.
        public let unorderedListItems: [UnorderedListItem]?
        /// Ordered-list entries for `.orderedList` nodes.
        public let orderedListItems: [UnorderedListItem]?
        
        /// Converts term list items into flattened inline content suitable for rendering.
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
        
        /// Converts unordered list items into flattened inline content suitable for rendering.
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
        
        /// Converts ordered list items into flattened inline content with index metadata.
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
        /// Tab entries for `.tabNavigator` nodes.
        public let tabs: [Tab]?
        
        // Row
        /// Explicit grid column count for row layout.
        public let numberOfColumns: Int?
        /// Row columns and their content.
        public let columns: [Column]?
        /// Table row/cell content payloads.
        public let rows: [[[Content]]]?
        
        /// Coding keys used to decode/encode polymorphic content nodes.
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
        
        public init(from decoder: any Decoder) throws {
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
        
        /// Manual encoder preserving list-item discriminators and optional fields.
        public func encode(to encoder: Encoder) throws {
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
        
        /// Content layout style hint from DocC payloads.
        public enum Style: String, Codable, CaseIterable, Equatable, Sendable {
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
        
        /// Table-like column descriptor used by row content types.
        public struct Column: Codable, Equatable, Hashable, Sendable {
            /// Relative column size in row layout units.
            public let size: Int
            /// Content blocks contained in this column.
            public let content: [Content]
        }
        
        /// Tab content wrapper for tabbed content sections.
        @CodableIgnoreInitializedProperties
        public struct Tab: Codable, Equatable, Identifiable, Hashable, Sendable {
            /// Stable identifier for diffable/UI usage.
            public let id = UUID()
            
            /// Raw tab content blocks.
            public let content: [Content]
            /// Condensed tab content optimized for rendering.
            public var condensedContent: [Content] {
                getCondensedContent(content)
            }
            
            /// Tab title shown in tab selectors.
            public let title: String
            
            /// Item wrapper used within tab payloads.
            @CodableIgnoreInitializedProperties
            public struct Item: Codable, Equatable, Identifiable, Hashable, Sendable {
                /// Stable identifier for diffable/UI usage.
                public let id = UUID()
                
                /// Content contained in this tab item.
                public let content: [ContentSection.Content]
            }
        }
        
        /// Term list entry with term and definition blocks.
        @CodableIgnoreInitializedProperties
        public struct TermListItem: Codable, Identifiable, Equatable, Hashable, Sendable {
            /// Stable identifier for diffable/UI usage.
            public let id = UUID()
            /// Term fragment shown as the entry label.
            public let term: Term
            /// Definition content associated with `term`.
            public let definition: Definition
            
            /// Definition payload for a term-list item.
            public struct Definition: Codable, Equatable, Hashable, Sendable {
                /// Definition content blocks.
                public let content: [ContentSection.Content]
            }
            
            /// Term payload for a term-list item.
            public struct Term: Codable, Equatable, Hashable, Sendable {
                /// Inline content segments representing the term.
                public let inlineContent: [ContentStruct]
            }
        }
        
        /// Unordered/ordered list entry content wrapper.
        @CodableIgnoreInitializedProperties
        public struct UnorderedListItem: Codable, Identifiable, Equatable, Hashable, Sendable {
            /// Stable identifier for diffable/UI usage.
            public let id = UUID()
            
            /// Content blocks for this list item.
            public let content: [ContentSection.Content]?
        }
    }
}

/// Variant descriptor used for language-specific and trait-based DocC content.
public struct Variant: Codable, Equatable, Hashable, Sendable {
    /// Trait constraints for this variant.
    public let traits: [Trait]
    /// JSON patch target paths associated with this variant.
    public let paths: [String]
    
    /// Language/interface trait descriptor for a variant.
    public struct Trait: Codable, Equatable, Hashable, Sendable {
        /// Interface language associated with this trait.
        public let interfaceLanguage: PreferedProgrammingLanguage
    }
}

/// Patch instructions used to override sections for specific variants.
public struct VariantOverride: Codable, Equatable, Hashable, Sendable {
    /// Trait constraints that activate this override.
    public let traits: [Variant.Trait]
    /// Patch operations to apply when traits match.
    public let patch: [Patch]
    
    /// Individual patch operation for applying variant overrides.
    public struct Patch: Codable, Equatable, Hashable, Sendable {
        /// Patch operation (`replace`, etc.).
        public let op: String
        /// JSON path targeted by this patch.
        public let path: String
        /// Optional replacement payload.
        public let value: AltDeclarationsWrapper?
        
        /// Variant override payload containing replacement declarations.
        public struct AltDeclarationsWrapper: Codable, Equatable, Hashable, Sendable {
            public let declarations: [ContentSection.Declaration]
            public let kind: String
        }
        
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            op = try container.decode(String.self, forKey: .op)
            path = try container.decode(String.self, forKey: .path)
            value = try? container.decodeIfPresent(AltDeclarationsWrapper.self, forKey: .value)
        }
    }
}

/// Reference metadata used for navigation, linking, and rendering across documentation payloads.
public struct Reference: Codable, Hashable, Identifiable, Sendable {
    public let id = UUID()
    
    /// Display title.
    public let title: String?
    /// Optional abstract content.
    public let abstract: [ContentStruct]?
    /// Canonical identifier (often `doc://...`).
    public let identifier: String
    /// Optional kind metadata.
    public let kind: String?
    /// Reference type metadata.
    public let type: String
    /// Optional URL string from payload.
    public let url: String?
    /// Optional semantic role.
    public let role: Role?
    /// Optional syntax fragments for symbol-like titles.
    public let fragments: [Fragment]?
    /// Optional deprecation flag.
    public let deprecated: Bool?
    /// Optional beta flag.
    public let beta: Bool?
    /// Optional display variants.
    public let variants: [Variant]?
    /// Optional associated image assets.
    public let images: [ImageStruct]?
    /// Resolved DocC site context for relative links/assets.
    public var docCSite: DocCSiteDTO?
    
    /// Whether this reference targets a non-DocC URL.
    public var isExternalReference: Bool {
        url?.lowercased().contains("/documentation") == false
    }
    
    /// Resolves the external URL for this reference using Apple or custom-site context.
    public var externalURL: URL? {
        var urlString: String? = url
        
        // Fallback to identifier
        if urlString == nil {
            urlString = URL(string: identifier)?.path()
        }
        
        guard let urlString else {
            return nil
        }
        
        guard let docCSite = docCSite else {
            guard urlString.contains(Constants.aDeveloperURLBase) else {
                return URL(string: "\(Constants.aDeveloperURLBase)\(urlString)")
            }
            return URL(string: urlString)
        }
        
        return docCSite.url.appending(path: urlString)
    }
    
    /// Path-based reference comparison that tolerates host differences.
    public func isEqual(to reference: Self) -> Bool {
        guard let currentUrl = URL(string: identifier),
              let url = URL(string: reference.identifier)
        else {
            return identifier.lowercased() == reference.identifier.lowercased()
        }
        
        return currentUrl.path().lowercased() == url.path().lowercased()
    }
    
    /// Creates a reference from explicit values.
    public init(title: String? = nil, abstract: [ContentStruct]? = nil, identifier: String, kind: String? = nil, type: String, url: String? = nil, role: Role? = nil, fragments: [Fragment]? = nil, deprecated: Bool? = nil, beta: Bool? = nil, variants: [Variant]? = nil, images: [ImageStruct]? = nil, docCSite: DocCSiteDTO? = nil) {
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
    
    /// Coding keys used for reference serialization.
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
    
    public init(from decoder: any Decoder) throws {
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
    
    /// Variant metadata scoped to a reference URL.
    public struct Variant: Codable, Hashable, Sendable {
        /// URL associated with this variant.
        public let url: String
        /// Trait strings associated with this variant.
        public let traits: [String]
    }
}

// MARK: Role
/// Semantic role for a DocC reference or content destination.
public enum Role: String, Codable, Equatable, Hashable, Sendable {
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
    
    /// Optional role-specific background color used in UI.
    public var color: Color? {
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
    
    /// Accent color used for role badges and iconography.
    public var accentColor: Color {
        switch self {
        case .collection, .symbol:
                .blue
        case .collectionGroup:
                .pink
        default:
            color ?? .accentColor
        }
    }
    
    /// Gradient colors used for role-themed backgrounds.
    public var gradientColors: [Color] {
        let color = color ?? .article
        
        return [color.opacity(0.4), color.opacity(0.0)]
    }
            
    /// Preferred SF Symbol used to represent this role in lists.
    public var labelIcon: SFSymbol {
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

/// Supported inline and block content types decoded from DocC JSON.
public enum ContentType: String, Codable, Equatable, Hashable, Sendable {
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
    case small
}

// MARK: Platforms
/// Platform availability metadata for symbols and articles.
@CodableIgnoreInitializedProperties
public struct Platform: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id = UUID()
    
    /// Version where availability begins.
    public let introducedAt: String?
    /// Whether this platform is unavailable for the symbol/content.
    public let unavailable: Bool?
    /// Whether this platform availability is beta.
    public let beta: Bool?
    /// Platform name.
    public let name: String
    /// Whether the platform availability is deprecated.
    public let deprecated: Bool?
    /// Version where deprecation begins.
    public let deprecatedAt: String?
}

// swiftlint:enable line_length file_length
