// Covers ResourcesRenderSection: the tutorials-overview section listing additional resource
// tiles.

import Testing
@testable import DocCSchema

@Suite struct ResourcesRenderSectionTests {
    @Test func decodesMinimal() throws {
        // Fully-synthesized Codable: "kind" and "content" are required despite having default
        // values, since a missing key throws rather than falling back for non-Optional properties.
        let json = """
        {"kind": "resources", "tiles": [], "content": []}
        """
        let value = try decode(ResourcesRenderSection.self, json)
        #expect(value.kind == .resources)
        #expect(value.tiles.isEmpty)
        #expect(value.content.isEmpty)
    }

    @Test func decodesFullPayload() throws {
        let json = """
        {
            "kind": "resources",
            "tiles": [
                {"identifier": "documentation", "title": "Example title", "content": []}
            ],
            "content": [
                {"type": "paragraph", "inlineContent": [{"type": "text", "text": "Example title"}]}
            ]
        }
        """
        let value = try decode(ResourcesRenderSection.self, json)
        #expect(value.tiles.count == 1)
        #expect(value.content.count == 1)
    }

    @Test func roundTrips() throws {
        let json = """
        {
            "kind": "resources",
            "tiles": [
                {"identifier": "documentation", "title": "Example title", "content": []}
            ],
            "content": []
        }
        """
        try roundTrip(ResourcesRenderSection.self, json)
    }

    @Test func decodesInsideRenderNode() throws {
        let sectionJSON = """
        {"kind": "resources", "tiles": [], "content": []}
        """
        let node = try decode(RenderNode.self, renderNodeJSON(kind: "overview", wrapping: sectionJSON))
        let section = try #require(node.sections.first as? ResourcesRenderSection)
        #expect(section.tiles.isEmpty)
    }

    @Test func missingTilesThrows() {
        let json = """
        {"kind": "resources", "content": []}
        """
        #expect(throws: (any Error).self) {
            try decode(ResourcesRenderSection.self, json)
        }
    }
}
