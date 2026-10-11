// Shape tests for MentionsRenderSection: a "mentions" section listing pages that mention
// a symbol, including dispatch through RenderNode.primaryContentSections.

import Testing
@testable import DocCSchema

@Suite struct MentionsRenderSectionTests {
    static let minimalJSON = """
    {
      "kind": "mentions",
      "mentions": ["https://example.com/documentation/examplekit/other"]
    }
    """

    @Test func decodesMinimalPayload() throws {
        let section = try decode(MentionsRenderSection.self, Self.minimalJSON)
        #expect(section.kind == .mentions)
        #expect(section.mentions.map(\.absoluteString) == ["https://example.com/documentation/examplekit/other"])
    }

    @Test func decodesMultipleMentions() throws {
        let json = """
        {
          "kind": "mentions",
          "mentions": [
            "https://example.com/documentation/examplekit/one",
            "https://example.com/documentation/examplekit/two"
          ]
        }
        """
        let section = try decode(MentionsRenderSection.self, json)
        #expect(section.mentions.count == 2)
    }

    @Test func roundTrips() throws {
        try roundTrip(MentionsRenderSection.self, Self.minimalJSON)
    }

    @Test func dispatchesThroughRenderNodePrimaryContentSections() throws {
        let node = try decode(RenderNode.self, renderNodeJSON(primaryContentSection: Self.minimalJSON))
        let mentions = try #require(node.primaryContentSections.first as? MentionsRenderSection)
        #expect(mentions.kind == .mentions)
        #expect(mentions.mentions.count == 1)
    }

    @Test func missingMentionsThrows() throws {
        #expect(throws: (any Error).self) {
            try decode(MentionsRenderSection.self, "{ \"kind\": \"mentions\" }")
        }
    }
}
