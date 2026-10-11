// Shape tests for RESTResponseRenderSection: a titled list of RESTResponse values, whose
// `responses` property is wire-encoded under the "items" key, including dispatch through
// RenderNode.primaryContentSections via its "restResponses" kind.

import Testing
@testable import DocCSchema

@Suite struct RESTResponseRenderSectionTests {
    static let minimalJSON = """
    {
      "kind": "restResponses",
      "title": "Response Codes",
      "items": [
        { "status": 200, "reason": "OK", "mimeType": "application/json", "type": [{ "kind": "typeIdentifier", "text": "Artist" }] }
      ]
    }
    """

    @Test func decodesPayload() throws {
        let section = try decode(RESTResponseRenderSection.self, Self.minimalJSON)
        #expect(section.kind == .restResponses)
        #expect(section.title == "Response Codes")
        #expect(section.responses.count == 1)
        #expect(section.responses[0].status == 200)
    }

    @Test func roundTrips() throws {
        try roundTrip(RESTResponseRenderSection.self, Self.minimalJSON)
    }

    @Test func dispatchesThroughRenderNodePrimaryContentSections() throws {
        let node = try decode(RenderNode.self, renderNodeJSON(primaryContentSection: Self.minimalJSON))
        let section = try #require(node.primaryContentSections.first as? RESTResponseRenderSection)
        #expect(section.kind == .restResponses)
        #expect(section.responses.count == 1)
    }

    @Test func missingRequiredKeyThrows() throws {
        #expect(throws: (any Error).self) {
            try decode(RESTResponseRenderSection.self, "{ \"kind\": \"restResponses\", \"title\": \"Response Codes\" }")
        }
    }
}
