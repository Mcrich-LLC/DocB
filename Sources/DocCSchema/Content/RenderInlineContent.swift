// The inline content elements of a documentation page's rendered body text.
//
// Copied from swift-docc `Sources/SwiftDocC/Model/Rendering/Content/RenderInlineContent.swift`
// at commit 871966648f3790c4496ae302abd4181828f9527a.
// Tolerant: string enums keep unrecognised raw values in an `unknown` case instead of failing to decode.
// Trimmed: the `decoder.registerReferences` call in the `.reference` decode case (tracked
// unused-reference counting for `RenderNodeTransformer`, not part of this copy set) and the
// `RenderJSONDiffable` conformance extension at the bottom of the file.
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors
//
// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception

/// An inline content element.
///
/// Typically, a renderer will append inline elements to previous inline elements.
/// Apart from simple content like an image or a piece of plain text,
/// a renderer uses inline elements to style content.
///
/// These elements don't introduce a break in their container's layout flow
/// like ``RenderBlockContent`` elements do.
///
/// ```
/// [ Paragraph
///    [Text] [Strong [Text]] [Text] [Emphasize [Reference]] ...
/// ]
/// - - - - - - - -
/// [ Paragraph
///   ...
/// ]
/// ```
///
/// Inline elements can be nested, for example, an inline piece of text can be wrapped in an emphasis element.
/// Block elements cannot be nested in inline elements.
public enum RenderInlineContent: Equatable {
    /// A piece of code like a variable name or a single operator.
    case codeVoice(code: String)
    /// An emphasized piece of inline content.
    case emphasis(inlineContent: [RenderInlineContent])
    /// A strongly emphasized piece of inline content.
    case strong(inlineContent: [RenderInlineContent])
    /// An image element.
    case image(identifier: RenderReferenceIdentifier, metadata: RenderContentMetadata?)
    
    /// A reference to another resource.
    case reference(identifier: RenderReferenceIdentifier, isActive: Bool, overridingTitle: String?, overridingTitleInlineContent: [RenderInlineContent]?)
    /// A piece of plain text.
    case text(String)
    
    /// A piece of content that introduces a new term.
    case newTerm(inlineContent: [RenderInlineContent])
    /// An inline heading.
    case inlineHead(inlineContent: [RenderInlineContent])
    /// A subscript piece of content.
    case `subscript`(inlineContent: [RenderInlineContent])
    /// A superscript piece of content.
    case superscript(inlineContent: [RenderInlineContent])
    /// A strikethrough piece of content.
    case strikethrough(inlineContent: [RenderInlineContent])

    /// An inline element whose `type` this version of the schema does not know, preserved verbatim.
    case unknown(JSON)
}

// Codable conformance
extension RenderInlineContent: Codable {
    private enum InlineType: TolerantStringEnum {
        case codeVoice, emphasis, strong, image, reference, text, newTerm, inlineHead, `subscript`, superscript, strikethrough

        /// A value this version of the schema does not know. The raw string is preserved and re-encoded unchanged.
        case unknown(String)

        internal init(rawValue: String) {
            switch rawValue {
            case "codeVoice": self = .codeVoice
            case "emphasis": self = .emphasis
            case "strong": self = .strong
            case "image": self = .image
            case "reference": self = .reference
            case "text": self = .text
            case "newTerm": self = .newTerm
            case "inlineHead": self = .inlineHead
            case "subscript": self = .`subscript`
            case "superscript": self = .superscript
            case "strikethrough": self = .strikethrough
            default: self = .unknown(rawValue)
            }
        }

        internal var rawValue: String {
            switch self {
            case .codeVoice: "codeVoice"
            case .emphasis: "emphasis"
            case .strong: "strong"
            case .image: "image"
            case .reference: "reference"
            case .text: "text"
            case .newTerm: "newTerm"
            case .inlineHead: "inlineHead"
            case .`subscript`: "subscript"
            case .superscript: "superscript"
            case .strikethrough: "strikethrough"
            case .unknown(let rawValue): rawValue
            }
        }
    }
    
    private enum CodingKeys: CodingKey {
        case type, code, inlineContent, identifier, title, destination, text, isActive, overridingTitle, overridingTitleInlineContent, metadata
    }
    
    private var type: InlineType {
        switch self {
        case .codeVoice: return .codeVoice
        case .emphasis: return .emphasis
        case .strong: return .strong
        case .image: return .image
        case .reference: return .reference
        case .text: return .text
        case .subscript: return .subscript
        case .superscript: return .superscript
        case .newTerm: return .newTerm
        case .inlineHead: return .inlineHead
        case .strikethrough: return .strikethrough
        case .unknown(let json):
            if case .dictionary(let object) = json, case .string(let type)? = object["type"] {
                return .unknown(type)
            }
            return .unknown("")
        }
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(InlineType.self, forKey: .type)
        switch type {
        case .codeVoice:
            self = try .codeVoice(code: container.decode(String.self, forKey: .code))
        case .emphasis:
            self = try .emphasis(inlineContent: container.decode([RenderInlineContent].self, forKey: .inlineContent))
        case .strong:
            self = try .strong(inlineContent: container.decode([RenderInlineContent].self, forKey: .inlineContent))
        case .image:
            self = try .image(
                identifier: container.decode(RenderReferenceIdentifier.self, forKey: . identifier),
                metadata: container.decodeIfPresent(RenderContentMetadata.self, forKey: .metadata)
            )
        case .reference:
            let identifier = try container.decode(RenderReferenceIdentifier.self, forKey: .identifier)
            let overridingTitle: String?
            let overridingTitleInlineContent: [RenderInlineContent]?
            
            if let formattedOverridingTitle = try container.decodeIfPresent([RenderInlineContent].self, forKey: .overridingTitleInlineContent) {
                overridingTitleInlineContent = formattedOverridingTitle
                overridingTitle = try container.decodeIfPresent(String.self, forKey: .overridingTitle) ?? formattedOverridingTitle.plainText
            } else if let plainTextOverridingTitle = try container.decodeIfPresent(String.self, forKey: .overridingTitle) {
                overridingTitleInlineContent = [.text(plainTextOverridingTitle)]
                overridingTitle = plainTextOverridingTitle
            } else {
                overridingTitleInlineContent = nil
                overridingTitle = nil
            }

            self = try .reference(identifier: identifier,
                                  isActive: container.decode(Bool.self, forKey: .isActive),
                                  overridingTitle: overridingTitle,
                                  overridingTitleInlineContent: overridingTitleInlineContent)
            // Trimmed: decoder.registerReferences call removed (RenderNodeTransformer not in copy set).
        case .text:
            self = try .text(container.decode(String.self, forKey: .text))
        case .newTerm:
            self = try .newTerm(inlineContent: container.decode([RenderInlineContent].self, forKey: .inlineContent))
        case .inlineHead:
            self = try .inlineHead(inlineContent: container.decode([RenderInlineContent].self, forKey: .inlineContent))
        case .subscript:
            self = try .subscript(inlineContent: container.decode([RenderInlineContent].self, forKey: .inlineContent))
        case .superscript:
            self = try .superscript(inlineContent: container.decode([RenderInlineContent].self, forKey: .inlineContent))
        case .strikethrough:
            self = try .strikethrough(inlineContent: container.decode([RenderInlineContent].self, forKey: .inlineContent))
        case .unknown:
            self = .unknown(try JSON(from: decoder))
        }
    }
    
    public func encode(to encoder: any Encoder) throws {
        if case .unknown(let json) = self {
            try json.encode(to: encoder)
            return
        }

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        switch self {
        case .codeVoice(let code):
            try container.encode(code, forKey: .code)
        case .emphasis(let inlineContent):
            try container.encode(inlineContent, forKey: .inlineContent)
        case .strong(let inlineContent):
            try container.encode(inlineContent, forKey: .inlineContent)
        case .image(let identifier, let metadata):
            try container.encode(identifier, forKey: .identifier)
            try container.encodeIfPresent(metadata, forKey: .metadata)
        case .reference(let identifier, let isActive, let overridingTitle, let overridingTitleInlineContent):
            try container.encode(identifier, forKey: .identifier)
            try container.encode(isActive, forKey: .isActive)
            try container.encodeIfPresent(overridingTitle, forKey: .overridingTitle)
            try container.encodeIfPresent(overridingTitleInlineContent, forKey: .overridingTitleInlineContent)
        case .text(let text):
            try container.encode(text, forKey: .text)
        case .newTerm(inlineContent: let inlineContent):
            try container.encode(inlineContent, forKey: .inlineContent)
        case .inlineHead(inlineContent: let inlineContent):
            try container.encode(inlineContent, forKey: .inlineContent)
        case .subscript(inlineContent: let inlineContent):
            try container.encode(inlineContent, forKey: .inlineContent)
        case .superscript(inlineContent: let inlineContent):
            try container.encode(inlineContent, forKey: .inlineContent)
        case .strikethrough(inlineContent: let inlineContent):
            try container.encode(inlineContent, forKey: .inlineContent)
        case .unknown:
            break // Handled above.
        }
    }
}

// Plain text extraction
extension RenderInlineContent {
    /// Returns a lossy conversion of the formatted content to a plain-text string.
    ///
    /// This implementation is necessarily limited because it doesn't make
    /// use of any collected `RenderReference` items. In many cases, it may make
    /// more sense to use the `rawIndexableTextContent` function that does use `RenderReference`
    /// for a more accurate textual representation of `RenderInlineContent.image` and
    /// `RenderInlineContent.reference`.
    public var plainText: String {
        switch self {
        case let .codeVoice(code):
            return code
        case let .emphasis(inlineContent):
            return inlineContent.plainText
        case let .strong(inlineContent):
            return inlineContent.plainText
        case let .image(_, metadata):
            return (metadata?.abstract?.plainText) ?? ""
        case let .reference(_, _, overridingTitle, overridingTitleInlineContent):
            return overridingTitle ?? overridingTitleInlineContent?.plainText ?? ""
        case let .text(text):
            return text
        case let .newTerm(inlineContent):
            return inlineContent.plainText
        case let .inlineHead(inlineContent):
            return inlineContent.plainText
        case let .subscript(inlineContent):
            return inlineContent.plainText
        case let .superscript(inlineContent):
            return inlineContent.plainText
        case let .strikethrough(inlineContent):
            return inlineContent.plainText
        case .unknown:
            return ""
        }
    }
}

// Plain text extraction
extension Sequence<RenderInlineContent> {
    /// Returns a lossy conversion of the formatted content to a plain-text string.
    ///
    /// This implementation is necessarily limited because it doesn't make
    /// use of any collected `RenderReference` items. In many cases, it may make
    /// more sense to use the `rawIndexableTextContent` function that does use `RenderReference`
    /// for a more accurate textual representation of `RenderInlineContent.image` and
    /// `RenderInlineContent.reference`.
    public var plainText: String {
        return map { $0.plainText }.joined()
    }
}
