// Shape tests for RESTParametersRenderSection: a titled, sourced list of REST parameters,
// whose `parameters` property is wire-encoded under the "items" key, including dispatch
// through RenderNode.primaryContentSections via its "restParameters" kind.

import Testing
@testable import DocCSchema

@Suite struct RESTParametersRenderSectionTests {
    static let minimalJSON = """
    {
      "kind": "restParameters",
      "title": "Query Parameters",
      "source": "query",
      "items": [
        { "name": "category", "type": [{ "kind": "typeIdentifier", "text": "String" }] }
      ]
    }
    """

    @Test func decodesPayload() throws {
        let section = try decode(RESTParametersRenderSection.self, Self.minimalJSON)
        #expect(section.kind == .restParameters)
        #expect(section.title == "Query Parameters")
        #expect(section.source == .query)
        #expect(section.parameters.count == 1)
        #expect(section.parameters[0].name == "category")
    }

    @Test func roundTrips() throws {
        try roundTrip(RESTParametersRenderSection.self, Self.minimalJSON)
    }

    @Test func dispatchesThroughRenderNodePrimaryContentSections() throws {
        let node = try decode(RenderNode.self, renderNodeJSON(primaryContentSection: Self.minimalJSON))
        let section = try #require(node.primaryContentSections.first as? RESTParametersRenderSection)
        #expect(section.kind == .restParameters)
        #expect(section.source == .query)
    }

    @Test func missingRequiredKeyThrows() throws {
        #expect(throws: (any Error).self) {
            try decode(RESTParametersRenderSection.self, "{ \"kind\": \"restParameters\", \"title\": \"Query Parameters\" }")
        }
    }
}
