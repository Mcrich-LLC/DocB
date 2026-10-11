// Covers ContentAndMediaGroupSection: a section that groups several ContentAndMediaSection
// entries under one shared layout.

import Testing
@testable import DocCSchema

@Suite struct ContentAndMediaGroupSectionTests {
    @Test func decodesMinimal() throws {
        // Fully-synthesized Codable: "kind" is required despite having a default value, since a
        // missing key throws rather than falling back for non-Optional properties.
        let json = """
        {"kind": "contentAndMediaGroup", "sections": []}
        """
        let value = try decode(ContentAndMediaGroupSection.self, json)
        #expect(value.kind == .contentAndMediaGroup)
        #expect(value.sections.isEmpty)
        #expect(value.layout == nil)
    }

    @Test func decodesFullPayload() throws {
        let json = """
        {
            "kind": "contentAndMediaGroup",
            "layout": "vertical",
            "sections": [
                {"kind": "contentAndMedia", "title": "Example title", "mediaPosition": "leading"}
            ]
        }
        """
        let value = try decode(ContentAndMediaGroupSection.self, json)
        #expect(value.layout == .vertical)
        #expect(value.sections.count == 1)
    }

    @Test func roundTrips() throws {
        let json = """
        {
            "kind": "contentAndMediaGroup",
            "layout": "horizontal",
            "sections": [
                {"kind": "contentAndMedia", "title": "Example title", "mediaPosition": "leading"}
            ]
        }
        """
        try roundTrip(ContentAndMediaGroupSection.self, json)
    }

    @Test func decodesInsideRenderNode() throws {
        let sectionJSON = """
        {"kind": "contentAndMediaGroup", "sections": []}
        """
        let node = try decode(RenderNode.self, renderNodeJSON(kind: "overview", wrapping: sectionJSON))
        let section = try #require(node.sections.first as? ContentAndMediaGroupSection)
        #expect(section.sections.isEmpty)
    }

    @Test func missingSectionsThrows() {
        let json = """
        {"kind": "contentAndMediaGroup"}
        """
        #expect(throws: (any Error).self) {
            try decode(ContentAndMediaGroupSection.self, json)
        }
    }
}
