// Covers ContentAndMediaSection: a section of text laid out next to a piece of media, along with
// its Layout and MediaPosition enums.

import Testing
@testable import DocCSchema

@Suite struct ContentAndMediaSectionTests {
    @Test func decodesMinimal() throws {
        // No key is required: the custom init(from:) falls back to defaults throughout,
        // including "kind" (-> .contentAndMedia) and "mediaPosition" (-> .leading).
        let json = "{}"
        let value = try decode(ContentAndMediaSection.self, json)
        #expect(value.kind == .contentAndMedia)
        #expect(value.mediaPosition == .leading)
        #expect(value.layout == nil)
        #expect(value.title == nil)
        #expect(value.content.isEmpty)
    }

    @Test func decodesFullPayload() throws {
        let json = """
        {
            "kind": "contentAndMedia",
            "layout": "vertical",
            "title": "Example title",
            "eyebrow": "Example eyebrow",
            "content": [
                {"type": "paragraph", "inlineContent": [{"type": "text", "text": "Example title"}]}
            ],
            "media": "diagram.png",
            "mediaPosition": "trailing"
        }
        """
        let value = try decode(ContentAndMediaSection.self, json)
        #expect(value.layout == .vertical)
        #expect(value.title == "Example title")
        #expect(value.eyebrow == "Example eyebrow")
        #expect(value.content.count == 1)
        #expect(value.media?.identifier == "diagram.png")
        #expect(value.mediaPosition == .trailing)
    }

    @Test func roundTrips() throws {
        let json = """
        {
            "kind": "contentAndMedia",
            "layout": "horizontal",
            "title": "Example title",
            "media": "diagram.png",
            "mediaPosition": "leading"
        }
        """
        try roundTrip(ContentAndMediaSection.self, json)
    }

    @Test func mediaPositionMissingDefaultsToLeading() throws {
        // Backwards-compatibility path: older payloads omit "mediaPosition" entirely.
        let json = """
        {"kind": "contentAndMedia", "title": "Example title"}
        """
        let value = try decode(ContentAndMediaSection.self, json)
        #expect(value.mediaPosition == .leading)
    }

    @Test func decodesInsideRenderNode() throws {
        let sectionJSON = """
        {"kind": "contentAndMedia", "title": "Example title"}
        """
        let node = try decode(RenderNode.self, renderNodeJSON(kind: "overview", wrapping: sectionJSON))
        let section = try #require(node.sections.first as? ContentAndMediaSection)
        #expect(section.title == "Example title")
    }
}
