// Shape tests for LinkReference: a URL paired with a plain-text title and its formatted
// (inline content) form, with fallbacks when either is missing from the JSON.

import Testing
@testable import DocCSchema

@Suite struct LinkReferenceTests {
    @Test func decodesWithPlainTextTitleOnly() throws {
        let reference = try decode(LinkReference.self, """
        {"type":"link","identifier":"doc://com.example/links/thing","title":"Example Title","url":"https://example.com/thing"}
        """)
        #expect(reference.title == "Example Title")
        #expect(reference.titleInlineContent == [.text("Example Title")])
    }

    @Test func decodesWithFormattedTitleInlineContent() throws {
        let reference = try decode(LinkReference.self, """
        {
          "type": "link",
          "identifier": "doc://com.example/links/thing",
          "titleInlineContent": [
            {"type": "text", "text": "Example "},
            {"type": "strong", "inlineContent": [{"type": "text", "text": "Title"}]}
          ],
          "url": "https://example.com/thing"
        }
        """)
        #expect(reference.title == "Example Title")
        #expect(reference.titleInlineContent.count == 2)
    }

    @Test func decodesWithNeitherTitleFallsBackToURL() throws {
        let reference = try decode(LinkReference.self, """
        {"type":"link","identifier":"doc://com.example/links/thing","url":"https://example.com/thing"}
        """)
        #expect(reference.title == "https://example.com/thing")
        #expect(reference.titleInlineContent == [.text("https://example.com/thing")])
    }

    @Test func roundTrips() throws {
        try roundTrip(LinkReference.self, """
        {"type":"link","identifier":"doc://com.example/links/thing","title":"Example Title","titleInlineContent":[{"type":"text","text":"Example Title"}],"url":"https://example.com/thing"}
        """)
    }

    @Test func missingURLThrows() {
        #expect(throws: (any Error).self) {
            try decode(LinkReference.self, """
            {"type":"link","identifier":"doc://com.example/links/thing","title":"Example Title"}
            """)
        }
    }
}
