// Covers RenderInlineContent: one case per inline kind (codeVoice, emphasis, strong, image,
// reference, text, newTerm, inlineHead, subscript, superscript, strikethrough), the reference
// case's overridingTitle variants, a missing-required-key failure, and an unknown discriminator
// (bare and nested inside a paragraph's inlineContent) preserved verbatim.

import Testing
@testable import DocCSchema

@Suite struct RenderInlineContentTests {
    @Test func decodesText() throws {
        let value = try roundTrip(RenderInlineContent.self, """
        { "type": "text", "text": "Example text." }
        """)
        #expect(value == .text("Example text."))
    }

    @Test func decodesCodeVoice() throws {
        let value = try roundTrip(RenderInlineContent.self, """
        { "type": "codeVoice", "code": "exampleSymbol()" }
        """)
        #expect(value == .codeVoice(code: "exampleSymbol()"))
    }

    // emphasis, strong, newTerm, inlineHead, subscript, superscript, and strikethrough all share
    // the same { type, inlineContent } shape and only differ by discriminator.
    @Test func decodesWrappedInlineContentKinds() throws {
        let kinds: [(String, ([RenderInlineContent]) -> RenderInlineContent)] = [
            ("emphasis", RenderInlineContent.emphasis),
            ("strong", RenderInlineContent.strong),
            ("newTerm", RenderInlineContent.newTerm),
            ("inlineHead", RenderInlineContent.inlineHead),
            ("subscript", RenderInlineContent.subscript),
            ("superscript", RenderInlineContent.superscript),
            ("strikethrough", RenderInlineContent.strikethrough),
        ]
        for (kind, make) in kinds {
            let json = """
            { "type": "\(kind)", "inlineContent": [ { "type": "text", "text": "Example text." } ] }
            """
            let value = try roundTrip(RenderInlineContent.self, json)
            #expect(value == make([.text("Example text.")]))
        }
    }

    @Test func decodesMinimalImage() throws {
        let value = try roundTrip(RenderInlineContent.self, """
        { "type": "image", "identifier": "example-image" }
        """)
        #expect(value == .image(identifier: RenderReferenceIdentifier("example-image"), metadata: nil))
    }

    @Test func decodesFullImage() throws {
        let json = """
        {
            "type": "image",
            "identifier": "example-image",
            "metadata": { "anchor": "example-anchor" }
        }
        """
        let value = try roundTrip(RenderInlineContent.self, json)
        guard case let .image(identifier, metadata) = value else {
            Issue.record("Expected .image, got \(value)")
            return
        }
        #expect(identifier == RenderReferenceIdentifier("example-image"))
        #expect(metadata?.anchor == "example-anchor")
    }

    @Test func decodesMinimalReference() throws {
        let value = try roundTrip(RenderInlineContent.self, """
        {
            "type": "reference",
            "identifier": "doc://com.example/documentation/examplekit/thing",
            "isActive": true
        }
        """)
        #expect(value == .reference(
            identifier: RenderReferenceIdentifier("doc://com.example/documentation/examplekit/thing"),
            isActive: true,
            overridingTitle: nil,
            overridingTitleInlineContent: nil
        ))
    }

    @Test func decodesReferenceWithPlainOverridingTitle() throws {
        let json = """
        {
            "type": "reference",
            "identifier": "doc://com.example/documentation/examplekit/thing",
            "isActive": false,
            "overridingTitle": "Custom Title"
        }
        """
        let value = try roundTrip(RenderInlineContent.self, json)
        guard case let .reference(_, isActive, overridingTitle, overridingTitleInlineContent) = value else {
            Issue.record("Expected .reference, got \(value)")
            return
        }
        #expect(isActive == false)
        #expect(overridingTitle == "Custom Title")
        // The plain-text initializer synthesizes matching formatted content.
        #expect(overridingTitleInlineContent == [.text("Custom Title")])
    }

    @Test func decodesReferenceWithFormattedOverridingTitle() throws {
        let json = """
        {
            "type": "reference",
            "identifier": "doc://com.example/documentation/examplekit/thing",
            "isActive": true,
            "overridingTitle": "Custom Title",
            "overridingTitleInlineContent": [ { "type": "text", "text": "Custom Title" } ]
        }
        """
        let value = try roundTrip(RenderInlineContent.self, json)
        guard case let .reference(_, _, overridingTitle, overridingTitleInlineContent) = value else {
            Issue.record("Expected .reference, got \(value)")
            return
        }
        #expect(overridingTitle == "Custom Title")
        #expect(overridingTitleInlineContent == [.text("Custom Title")])
    }

    @Test func missingRequiredKeyThrows() {
        // "text" case requires the "text" key.
        #expect(throws: (any Error).self) {
            try decode(RenderInlineContent.self, """
            { "type": "text" }
            """)
        }
    }

    @Test func unknownDiscriminatorIsPreserved() throws {
        let json = """
        { "type": "notARealKind", "text": "Example text." }
        """
        let value = try roundTrip(RenderInlineContent.self, json)
        guard case .unknown(let payload) = value, case .dictionary(let object) = payload else {
            Issue.record("Expected .unknown")
            return
        }
        #expect(object["text"] == .string("Example text."))
        #expect(value.plainText == "")
    }

    @Test func unknownInlineElementNestedInParagraphRoundTrips() throws {
        let json = """
        { "type": "paragraph", "inlineContent": [ { "type": "notARealKind", "extra": "value" } ] }
        """
        let value = try roundTrip(RenderBlockContent.self, json)
        guard case .paragraph(let paragraph) = value else {
            Issue.record("Expected .paragraph, got \(value)")
            return
        }
        #expect(paragraph.inlineContent.count == 1)
        let inline = paragraph.inlineContent[0]
        guard case .unknown(let payload) = inline, case .dictionary(let object) = payload else {
            Issue.record("Expected nested .unknown inline element")
            return
        }
        #expect(object["extra"] == .string("value"))
        #expect(inline.plainText == "")
    }
}
