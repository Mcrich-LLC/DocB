// Shape tests for TaskGroupRenderSection: a titled list of topic-graph identifiers with an
// optional nested discussion section, dispatched through CodableContentSection by its
// "taskGroup" kind.
//
// Note: unlike its sibling render sections, TaskGroupRenderSection's own CodingKeys and
// encode(to:) never include a "kind" key (see TaskGroupRenderSection.swift) — it's used
// directly as `[TaskGroupRenderSection]` in RenderNode's topicSections/seeAlsoSections/
// defaultImplementationsSections, which carry no per-element discriminator. So standalone
// payloads below omit "kind", and the RenderNode.primaryContentSections dispatch test
// below is decode-only (a full encode round trip of that wrapping RenderNode would drop the
// "kind" the CodableContentSection wrapper needed to route the decode, since
// TaskGroupRenderSection.encode(to:) never re-emits it).

import Testing
@testable import DocCSchema

@Suite struct TaskGroupRenderSectionTests {
    static let minimalJSON = """
    { "identifiers": ["doc://com.example/documentation/examplekit/one"] }
    """

    @Test func decodesMinimalPayload() throws {
        let section = try decode(TaskGroupRenderSection.self, Self.minimalJSON)
        #expect(section.kind == .taskGroup)
        #expect(section.title == nil)
        #expect(section.abstract == nil)
        #expect(section.discussion == nil)
        #expect(section.identifiers == ["doc://com.example/documentation/examplekit/one"])
        #expect(section.generated == false)
        #expect(section.anchor == nil)
    }

    @Test func decodesFullPayload() throws {
        let json = """
        {
          "title": "Example Group",
          "abstract": [{ "type": "text", "text": "A short summary." }],
          "discussion": {
            "kind": "content",
            "content": [
              { "type": "paragraph", "inlineContent": [{ "type": "text", "text": "More detail." }] }
            ]
          },
          "identifiers": ["doc://com.example/documentation/examplekit/one"],
          "generated": true,
          "anchor": "example-group"
        }
        """
        let section = try decode(TaskGroupRenderSection.self, json)
        #expect(section.title == "Example Group")
        #expect(section.abstract == [.text("A short summary.")])
        let discussion = try #require(section.discussion as? ContentRenderSection)
        #expect(discussion.kind == .content)
        #expect(discussion.content.count == 1)
        #expect(section.generated == true)
        #expect(section.anchor == "example-group")
    }

    @Test func roundTrips() throws {
        try roundTrip(TaskGroupRenderSection.self, """
        {
          "title": "Example Group",
          "identifiers": ["doc://com.example/documentation/examplekit/one"],
          "generated": true,
          "anchor": "example-group"
        }
        """)
    }

    @Test func dispatchesThroughRenderNodePrimaryContentSections() throws {
        let sectionJSON = """
        {
          "kind": "taskGroup",
          "title": "Example Group",
          "identifiers": ["doc://com.example/documentation/examplekit/one"]
        }
        """
        let node = try decode(RenderNode.self, renderNodeJSON(primaryContentSection: sectionJSON))
        let section = try #require(node.primaryContentSections.first as? TaskGroupRenderSection)
        #expect(section.kind == .taskGroup)
        #expect(section.title == "Example Group")
        #expect(section.identifiers == ["doc://com.example/documentation/examplekit/one"])
    }

    @Test func missingIdentifiersThrows() throws {
        #expect(throws: (any Error).self) {
            try decode(TaskGroupRenderSection.self, "{ \"title\": \"Example Group\" }")
        }
    }
}
