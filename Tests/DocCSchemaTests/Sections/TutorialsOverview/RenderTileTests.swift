// Covers RenderTile and its Identifier enum: a tile inside a Resources section that links to a
// specific kind of content (documentation, sample code, videos, etc).

import Testing
@testable import DocCSchema

@Suite struct RenderTileTests {
    @Test func decodesMinimal() throws {
        // Fully-synthesized Codable: "content" is required despite having a default value.
        let json = """
        {"identifier": "documentation", "title": "Example title", "content": []}
        """
        let value = try decode(RenderTile.self, json)
        #expect(value.identifier == .documentation)
        #expect(value.title == "Example title")
        #expect(value.content.isEmpty)
        #expect(value.action == nil)
        #expect(value.media == nil)
    }

    @Test func decodesFullPayload() throws {
        let json = """
        {
            "identifier": "sampleCode",
            "title": "Example title",
            "content": [
                {"type": "paragraph", "inlineContent": [{"type": "text", "text": "Example title"}]}
            ],
            "action": {"type": "text", "text": "See sample code"},
            "media": "tile.png"
        }
        """
        let value = try decode(RenderTile.self, json)
        #expect(value.identifier == .sampleCode)
        #expect(value.content.count == 1)
        #expect(value.media?.identifier == "tile.png")
    }

    @Test func identifierRawValuesMatchWireFormat() throws {
        #expect(RenderTile.Identifier.featured.rawValue == "featured")
        #expect(RenderTile.Identifier.documentation.rawValue == "documentation")
        #expect(RenderTile.Identifier.sampleCode.rawValue == "sampleCode")
        #expect(RenderTile.Identifier.downloads.rawValue == "downloads")
        #expect(RenderTile.Identifier.videos.rawValue == "videos")
        #expect(RenderTile.Identifier.forums.rawValue == "forums")
    }

    @Test func roundTrips() throws {
        let json = """
        {
            "identifier": "videos",
            "title": "Example title",
            "content": [],
            "media": "tile.png"
        }
        """
        try roundTrip(RenderTile.self, json)
    }

    @Test func unknownIdentifierIsPreserved() throws {
        let json = """
        {"identifier": "bogus", "title": "Example title", "content": []}
        """
        let value = try roundTrip(RenderTile.self, json)
        #expect(value.identifier == .unknown("bogus"))
    }

    @Test func missingTitleThrows() {
        let json = """
        {"identifier": "documentation", "content": []}
        """
        #expect(throws: (any Error).self) {
            try decode(RenderTile.self, json)
        }
    }
}
