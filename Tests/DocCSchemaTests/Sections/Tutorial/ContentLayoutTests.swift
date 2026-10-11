// Covers ContentLayout: the fullWidth/contentAndMedia/columns discriminated union used inside
// Tutorial Article and Tutorial section content.

import Testing
@testable import DocCSchema

@Suite struct ContentLayoutTests {
    @Test func decodesFullWidth() throws {
        let json = """
        {
            "kind": "fullWidth",
            "content": [
                {"type": "paragraph", "inlineContent": [{"type": "text", "text": "Example title"}]}
            ]
        }
        """
        let value = try decode(ContentLayout.self, json)
        guard case .fullWidth(let content) = value else {
            Issue.record("expected .fullWidth")
            return
        }
        #expect(content.count == 1)
    }

    @Test func decodesContentAndMedia() throws {
        // contentAndMedia flattens ContentAndMediaSection's own keys at the top level instead of
        // nesting them under "content".
        let json = """
        {
            "kind": "contentAndMedia",
            "title": "Example title",
            "mediaPosition": "leading"
        }
        """
        let value = try decode(ContentLayout.self, json)
        guard case .contentAndMedia(let section) = value else {
            Issue.record("expected .contentAndMedia")
            return
        }
        #expect(section.title == "Example title")
    }

    @Test func decodesColumns() throws {
        let json = """
        {
            "kind": "columns",
            "content": [
                {"kind": "contentAndMedia", "mediaPosition": "trailing"}
            ]
        }
        """
        let value = try decode(ContentLayout.self, json)
        guard case .columns(let sections) = value else {
            Issue.record("expected .columns")
            return
        }
        #expect(sections.count == 1)
        #expect(sections[0].mediaPosition == .trailing)
    }

    @Test func roundTripsFullWidth() throws {
        let json = """
        {
            "kind": "fullWidth",
            "content": [
                {"type": "paragraph", "inlineContent": [{"type": "text", "text": "Example title"}]}
            ]
        }
        """
        try roundTrip(ContentLayout.self, json)
    }

    @Test func roundTripsColumns() throws {
        let json = """
        {
            "kind": "columns",
            "content": [
                {"kind": "contentAndMedia", "mediaPosition": "leading"}
            ]
        }
        """
        try roundTrip(ContentLayout.self, json)
    }

    @Test func unknownKindIsPreserved() throws {
        let json = """
        {"kind": "bogus"}
        """
        let value = try roundTrip(ContentLayout.self, json)
        guard case .unknown(let payload) = value, case .dictionary(let object) = payload else {
            Issue.record("Expected .unknown")
            return
        }
        #expect(object["kind"] == .string("bogus"))
    }
}
