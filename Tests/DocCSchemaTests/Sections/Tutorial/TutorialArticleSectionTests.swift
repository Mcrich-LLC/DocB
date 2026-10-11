// Covers TutorialArticleSection: the body of a free-standing Tutorial Article page, made up of
// ContentLayout items.

import Testing
@testable import DocCSchema

@Suite struct TutorialArticleSectionTests {
    @Test func decodesMinimal() throws {
        // `content` has no required key: the custom init(from:) falls back to [] when absent.
        let json = """
        {"kind": "articleBody"}
        """
        let value = try decode(TutorialArticleSection.self, json)
        #expect(value.kind == .articleBody)
        #expect(value.content.isEmpty)
    }

    @Test func decodesFullPayload() throws {
        let json = """
        {
            "kind": "articleBody",
            "content": [
                {
                    "kind": "fullWidth",
                    "content": [
                        {"type": "paragraph", "inlineContent": [{"type": "text", "text": "Example title"}]}
                    ]
                }
            ]
        }
        """
        let value = try decode(TutorialArticleSection.self, json)
        #expect(value.content.count == 1)
    }

    @Test func roundTrips() throws {
        let json = """
        {
            "kind": "articleBody",
            "content": [
                {
                    "kind": "fullWidth",
                    "content": [
                        {"type": "paragraph", "inlineContent": [{"type": "text", "text": "Example title"}]}
                    ]
                }
            ]
        }
        """
        try roundTrip(TutorialArticleSection.self, json)
    }

    @Test func decodesInsideRenderNode() throws {
        let sectionJSON = """
        {"kind": "articleBody", "content": []}
        """
        let node = try decode(RenderNode.self, renderNodeJSON(kind: "article", wrapping: sectionJSON))
        let section = try #require(node.sections.first as? TutorialArticleSection)
        #expect(section.kind == .articleBody)
    }
}
