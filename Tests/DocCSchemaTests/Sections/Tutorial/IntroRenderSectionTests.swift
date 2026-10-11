// Covers IntroRenderSection: the tutorial page's hero section, plus its dispatch from
// CodableRenderSection under both the "hero" and legacy "intro" kind strings.

import Testing
@testable import DocCSchema

@Suite struct IntroRenderSectionTests {
    @Test func decodesMinimal() throws {
        let json = """
        {"kind": "hero", "title": "Example title"}
        """
        let value = try decode(IntroRenderSection.self, json)
        #expect(value.title == "Example title")
        #expect(value.kind == .hero)
        #expect(value.content.isEmpty)
        #expect(value.chapter == nil)
    }

    @Test func decodesFullPayload() throws {
        let json = """
        {
            "kind": "hero",
            "title": "Example title",
            "chapter": "Example chapter",
            "estimatedTimeInMinutes": 15,
            "xcodeRequirement": "doc://com.example/tutorials/requirement",
            "backgroundImage": "background.png",
            "action": {"type": "text", "text": "Get started"},
            "image": "image.png",
            "video": "video.mov",
            "projectFiles": "project.zip",
            "content": [
                {"type": "paragraph", "inlineContent": [{"type": "text", "text": "Example title"}]}
            ]
        }
        """
        let value = try decode(IntroRenderSection.self, json)
        #expect(value.chapter == "Example chapter")
        #expect(value.estimatedTimeInMinutes == 15)
        #expect(value.xcodeRequirement?.identifier == "doc://com.example/tutorials/requirement")
        #expect(value.backgroundImage?.identifier == "background.png")
        #expect(value.image?.identifier == "image.png")
        #expect(value.video?.identifier == "video.mov")
        #expect(value.projectFiles?.identifier == "project.zip")
        #expect(value.content.count == 1)
    }

    @Test func roundTrips() throws {
        let json = """
        {
            "kind": "hero",
            "title": "Example title",
            "chapter": "Example chapter",
            "content": []
        }
        """
        try roundTrip(IntroRenderSection.self, json)
    }

    @Test func legacyIntroKindNormalizesToHero() throws {
        // `kind` is a stored constant never read from the wire; any input decodes to `.hero`
        // regardless of the incoming discriminator, so "intro" input re-encodes as "hero".
        let json = """
        {"kind": "intro", "title": "Example title"}
        """
        let value = try decode(IntroRenderSection.self, json)
        #expect(value.kind == .hero)
    }

    @Test func decodesInsideRenderNode() throws {
        let sectionJSON = """
        {"kind": "hero", "title": "Example title"}
        """
        let node = try decode(RenderNode.self, renderNodeJSON(wrapping: sectionJSON))
        let section = try #require(node.sections.first as? IntroRenderSection)
        #expect(section.title == "Example title")
    }

    @Test func missingTitleThrows() {
        let json = """
        {"kind": "hero"}
        """
        #expect(throws: (any Error).self) {
            try decode(IntroRenderSection.self, json)
        }
    }
}
