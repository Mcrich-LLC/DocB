// Shape tests for AttributesRenderSection: a titled list of RenderAttribute values,
// including dispatch through RenderNode.primaryContentSections via its "attributes" kind.

import Testing
@testable import DocCSchema

@Suite struct AttributesRenderSectionTests {
    @Test func decodesMinimalPayload() throws {
        let json = """
        { "kind": "attributes", "title": "Attributes" }
        """
        let section = try decode(AttributesRenderSection.self, json)
        #expect(section.kind == .attributes)
        #expect(section.title == "Attributes")
        #expect(section.attributes == nil)
    }

    @Test func decodesFullPayload() throws {
        let json = """
        {
          "kind": "attributes",
          "title": "Attributes",
          "attributes": [
            { "kind": "default", "value": "none" },
            { "kind": "allowedValues", "values": ["none", "all"] }
          ]
        }
        """
        let section = try decode(AttributesRenderSection.self, json)
        #expect(section.attributes?.count == 2)
        #expect(section.attributes?[0] == .default("none"))
    }

    @Test func roundTrips() throws {
        try roundTrip(AttributesRenderSection.self, """
        {
          "kind": "attributes",
          "title": "Attributes",
          "attributes": [{ "kind": "default", "value": "none" }]
        }
        """)
    }

    @Test func dispatchesThroughRenderNodePrimaryContentSections() throws {
        let sectionJSON = """
        { "kind": "attributes", "title": "Attributes" }
        """
        let node = try decode(RenderNode.self, renderNodeJSON(primaryContentSection: sectionJSON))
        let attributes = try #require(node.primaryContentSections.first as? AttributesRenderSection)
        #expect(attributes.kind == .attributes)
        #expect(attributes.title == "Attributes")
    }

    @Test func missingTitleThrows() throws {
        #expect(throws: (any Error).self) {
            try decode(AttributesRenderSection.self, "{ \"kind\": \"attributes\" }")
        }
    }
}
