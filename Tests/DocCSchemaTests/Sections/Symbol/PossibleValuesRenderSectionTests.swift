// Shape tests for PossibleValuesRenderSection and its nested NamedValue: a pre-defined
// list of allowed values, including dispatch through RenderNode.primaryContentSections.

import Testing
@testable import DocCSchema

@Suite struct PossibleValuesRenderSectionTests {
    @Test func decodesMinimalPayload() throws {
        let json = """
        {
          "kind": "possibleValues",
          "values": [{ "name": "ppc", "content": null }]
        }
        """
        let section = try decode(PossibleValuesRenderSection.self, json)
        #expect(section.kind == .possibleValues)
        #expect(section.title == nil)
        #expect(section.values.count == 1)
        #expect(section.values[0].name == "ppc")
        #expect(section.values[0].content == nil)
    }

    @Test func decodesFullPayload() throws {
        let json = """
        {
          "kind": "possibleValues",
          "title": "Possible Values",
          "values": [
            {
              "name": "Default",
              "content": [
                { "type": "paragraph", "inlineContent": [{ "type": "text", "text": "Loads the first instance." }] }
              ]
            }
          ]
        }
        """
        let section = try decode(PossibleValuesRenderSection.self, json)
        #expect(section.title == "Possible Values")
        #expect(section.values[0].content?.count == 1)
    }

    // NamedValue's `content` is Optional and synthesized-Encodable, so encode omits the key
    // entirely when nil rather than writing `null`; an explicit `null` in the input would
    // therefore look "lost" to the subset check even though both mean "no content". Using an
    // omitted key here (rather than nil, covered by decodesMinimalPayload above) keeps this
    // round trip meaningful.
    @Test func roundTrips() throws {
        try roundTrip(PossibleValuesRenderSection.self, """
        {
          "kind": "possibleValues",
          "title": "Possible Values",
          "values": [{ "name": "ppc" }]
        }
        """)
    }

    @Test func dispatchesThroughRenderNodePrimaryContentSections() throws {
        let sectionJSON = """
        {
          "kind": "possibleValues",
          "title": "Possible Values",
          "values": [{ "name": "ppc", "content": null }]
        }
        """
        let node = try decode(RenderNode.self, renderNodeJSON(primaryContentSection: sectionJSON))
        let section = try #require(node.primaryContentSections.first as? PossibleValuesRenderSection)
        #expect(section.kind == .possibleValues)
        #expect(section.values.count == 1)
    }

    @Test func missingValuesThrows() throws {
        #expect(throws: (any Error).self) {
            try decode(PossibleValuesRenderSection.self, "{ \"kind\": \"possibleValues\" }")
        }
    }
}
