// Shape tests for ParameterRenderSection: a single named parameter sub-section with
// free-form block content.

import Testing
@testable import DocCSchema

@Suite struct ParameterRenderSectionTests {
    @Test func decodesMinimalPayload() throws {
        let json = """
        { "name": "value", "content": [] }
        """
        let section = try decode(ParameterRenderSection.self, json)
        #expect(section.name == "value")
        #expect(section.content.isEmpty)
    }

    @Test func decodesFullPayload() throws {
        let json = """
        {
          "name": "value",
          "content": [
            { "type": "paragraph", "inlineContent": [{ "type": "text", "text": "The value to use." }] }
          ]
        }
        """
        let section = try decode(ParameterRenderSection.self, json)
        #expect(section.name == "value")
        #expect(section.content.count == 1)
    }

    @Test func roundTrips() throws {
        try roundTrip(ParameterRenderSection.self, """
        {
          "name": "value",
          "content": [
            { "type": "paragraph", "inlineContent": [{ "type": "text", "text": "The value to use." }] }
          ]
        }
        """)
    }

    @Test func missingNameThrows() throws {
        #expect(throws: (any Error).self) {
            try decode(ParameterRenderSection.self, "{ \"content\": [] }")
        }
    }
}
