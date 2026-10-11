// Covers CallToActionSection: the tutorials-overview section that prompts the reader to start a
// tutorial.

import Testing
@testable import DocCSchema

@Suite struct CallToActionSectionTests {
    @Test func decodesMinimal() throws {
        let json = """
        {
            "kind": "callToAction",
            "title": "Example title",
            "action": {"type": "text", "text": "Start"}
        }
        """
        let value = try decode(CallToActionSection.self, json)
        #expect(value.kind == .callToAction)
        #expect(value.title == "Example title")
        #expect(value.abstract.isEmpty)
        #expect(value.media == nil)
        #expect(value.featuredEyebrow == nil)
    }

    @Test func decodesFullPayload() throws {
        let json = """
        {
            "kind": "callToAction",
            "title": "Example title",
            "abstract": [{"type": "text", "text": "Example abstract"}],
            "media": "hero.mp4",
            "action": {"type": "text", "text": "Start"},
            "featuredEyebrow": "Featured"
        }
        """
        let value = try decode(CallToActionSection.self, json)
        #expect(value.abstract.count == 1)
        #expect(value.media?.identifier == "hero.mp4")
        #expect(value.featuredEyebrow == "Featured")
    }

    @Test func roundTrips() throws {
        let json = """
        {
            "kind": "callToAction",
            "title": "Example title",
            "abstract": [{"type": "text", "text": "Example abstract"}],
            "media": "hero.mp4",
            "action": {"type": "text", "text": "Start"},
            "featuredEyebrow": "Featured"
        }
        """
        try roundTrip(CallToActionSection.self, json)
    }

    @Test func decodesInsideRenderNode() throws {
        let sectionJSON = """
        {
            "kind": "callToAction",
            "title": "Example title",
            "action": {"type": "text", "text": "Start"}
        }
        """
        let node = try decode(RenderNode.self, renderNodeJSON(kind: "overview", wrapping: sectionJSON))
        let section = try #require(node.sections.first as? CallToActionSection)
        #expect(section.title == "Example title")
    }

    @Test func missingActionThrows() {
        let json = """
        {"kind": "callToAction", "title": "Example title"}
        """
        #expect(throws: (any Error).self) {
            try decode(CallToActionSection.self, json)
        }
    }
}
