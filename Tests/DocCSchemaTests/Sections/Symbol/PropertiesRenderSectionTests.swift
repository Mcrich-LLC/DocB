// Shape tests for PropertiesRenderSection: a titled list of RenderProperty values,
// including dispatch through RenderNode.primaryContentSections via its "properties" kind.

import Testing
@testable import DocCSchema

@Suite struct PropertiesRenderSectionTests {
    static let minimalJSON = """
    {
      "kind": "properties",
      "title": "Properties",
      "items": [
        { "name": "title", "type": [{ "kind": "typeIdentifier", "text": "String" }] }
      ]
    }
    """

    @Test func decodesMinimalPayload() throws {
        let section = try decode(PropertiesRenderSection.self, Self.minimalJSON)
        #expect(section.kind == .properties)
        #expect(section.title == "Properties")
        #expect(section.items.count == 1)
        #expect(section.items[0].name == "title")
    }

    @Test func roundTrips() throws {
        _ = try roundTrip(PropertiesRenderSection.self, Self.minimalJSON)
    }

    @Test func dispatchesThroughRenderNodePrimaryContentSections() throws {
        let node = try decode(RenderNode.self, renderNodeJSON(primaryContentSection: Self.minimalJSON))
        let properties = try #require(node.primaryContentSections.first as? PropertiesRenderSection)
        #expect(properties.kind == .properties)
        #expect(properties.items.count == 1)
    }

    @Test func missingItemsThrows() throws {
        #expect(throws: (any Error).self) {
            try decode(PropertiesRenderSection.self, "{ \"kind\": \"properties\", \"title\": \"Properties\" }")
        }
    }
}
