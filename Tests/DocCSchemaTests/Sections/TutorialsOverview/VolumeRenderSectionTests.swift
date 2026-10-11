// Covers VolumeRenderSection and its nested Chapter type: the section that groups a volume's
// tutorials into chapters.

import Testing
@testable import DocCSchema

@Suite struct VolumeRenderSectionTests {
    @Test func decodesMinimal() throws {
        // Fully-synthesized Codable via the manually-declared CodingKeys: "kind" and "chapters"
        // are required despite having default values, since a missing key throws rather than
        // falling back for non-Optional properties. "name" is genuinely optional (Optional type).
        let json = """
        {"kind": "volume", "chapters": []}
        """
        let value = try decode(VolumeRenderSection.self, json)
        #expect(value.kind == .volume)
        #expect(value.name == nil)
        #expect(value.image == nil)
        #expect(value.content == nil)
        #expect(value.chapters.isEmpty)
    }

    @Test func decodesFullPayload() throws {
        let json = """
        {
            "kind": "volume",
            "name": "Example volume",
            "image": "volume.png",
            "content": [
                {"type": "paragraph", "inlineContent": [{"type": "text", "text": "Example title"}]}
            ],
            "chapters": [
                {
                    "name": "Example chapter",
                    "content": [],
                    "tutorials": ["doc://com.example/tutorials/ExampleKit/Thing"],
                    "image": "chapter.png"
                }
            ]
        }
        """
        let value = try decode(VolumeRenderSection.self, json)
        #expect(value.name == "Example volume")
        #expect(value.chapters.count == 1)
        #expect(value.chapters[0].name == "Example chapter")
        #expect(value.chapters[0].tutorials.map(\.identifier) == ["doc://com.example/tutorials/ExampleKit/Thing"])
        #expect(value.chapters[0].image?.identifier == "chapter.png")
    }

    @Test func encodesNullNameForAnonymousVolume() throws {
        // The custom encode(to:) always writes "name", even null, for anonymous volumes.
        let json = """
        {"kind": "volume", "name": null, "chapters": []}
        """
        try roundTrip(VolumeRenderSection.self, json)
    }

    @Test func roundTrips() throws {
        let json = """
        {
            "kind": "volume",
            "name": "Example volume",
            "chapters": [
                {"name": "Example chapter", "content": [], "tutorials": []}
            ]
        }
        """
        try roundTrip(VolumeRenderSection.self, json)
    }

    @Test func decodesInsideRenderNode() throws {
        let sectionJSON = """
        {"kind": "volume", "chapters": []}
        """
        let node = try decode(RenderNode.self, renderNodeJSON(kind: "overview", wrapping: sectionJSON))
        let section = try #require(node.sections.first as? VolumeRenderSection)
        #expect(section.chapters.isEmpty)
    }

    @Test func missingChaptersThrows() {
        let json = """
        {"kind": "volume"}
        """
        #expect(throws: (any Error).self) {
            try decode(VolumeRenderSection.self, json)
        }
    }
}
