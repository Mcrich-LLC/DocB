// Shape tests for ContentRenderSection: arbitrary block content under a "content" or
// "discussion" kind, including dispatch through RenderNode.primaryContentSections.

import Testing
@testable import DocCSchema

@Suite struct ContentRenderSectionTests {
    static let discussionJSON = """
    {
      "kind": "discussion",
      "content": [
        { "type": "paragraph", "inlineContent": [{ "type": "text", "text": "Example discussion." }] }
      ]
    }
    """

    @Test func decodesDiscussionKind() throws {
        let section = try decode(ContentRenderSection.self, Self.discussionJSON)
        #expect(section.kind == .discussion)
        #expect(section.content.count == 1)
    }

    @Test func decodesContentKind() throws {
        let json = """
        {
          "kind": "content",
          "content": [
            { "type": "paragraph", "inlineContent": [{ "type": "text", "text": "Example content." }] }
          ]
        }
        """
        let section = try decode(ContentRenderSection.self, json)
        #expect(section.kind == .content)
    }

    @Test func roundTrips() throws {
        try roundTrip(ContentRenderSection.self, Self.discussionJSON)
    }

    @Test func dispatchesThroughRenderNodePrimaryContentSections() throws {
        let node = try decode(RenderNode.self, renderNodeJSON(primaryContentSection: Self.discussionJSON))
        let content = try #require(node.primaryContentSections.first as? ContentRenderSection)
        #expect(content.kind == .discussion)
        #expect(content.content.count == 1)
    }

    @Test func missingContentThrows() throws {
        #expect(throws: (any Error).self) {
            try decode(ContentRenderSection.self, "{ \"kind\": \"content\" }")
        }
    }
}
