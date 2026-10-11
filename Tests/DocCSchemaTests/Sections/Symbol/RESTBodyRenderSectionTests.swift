// Shape tests for RESTBodyRenderSection: a REST request body's mime type, declared content
// type, and optional details/parameters, including dispatch through
// RenderNode.primaryContentSections via its "restBody" kind.

import Testing
@testable import DocCSchema

@Suite struct RESTBodyRenderSectionTests {
    static let minimalJSON = """
    {
      "kind": "restBody",
      "title": "HTTP Body",
      "mimeType": "application/json",
      "bodyContentType": [{ "kind": "typeIdentifier", "text": "Artist" }]
    }
    """

    @Test func decodesMinimalPayload() throws {
        let section = try decode(RESTBodyRenderSection.self, Self.minimalJSON)
        #expect(section.kind == .restBody)
        #expect(section.mimeType == "application/json")
        #expect(section.bodyContentType.count == 1)
        #expect(section.content == nil)
        #expect(section.parameters == nil)
    }

    @Test func decodesFullPayload() throws {
        let json = """
        {
          "kind": "restBody",
          "title": "HTTP Body",
          "mimeType": "multipart/form-data",
          "bodyContentType": [{ "kind": "typeIdentifier", "text": "Artist" }],
          "content": [
            { "type": "paragraph", "inlineContent": [{ "type": "text", "text": "The request body." }] }
          ],
          "parameters": [
            { "name": "title", "type": [{ "kind": "typeIdentifier", "text": "String" }] }
          ]
        }
        """
        let section = try decode(RESTBodyRenderSection.self, json)
        #expect(section.content?.count == 1)
        #expect(section.parameters?.count == 1)
    }

    @Test func roundTrips() throws {
        try roundTrip(RESTBodyRenderSection.self, Self.minimalJSON)
    }

    @Test func dispatchesThroughRenderNodePrimaryContentSections() throws {
        let node = try decode(RenderNode.self, renderNodeJSON(primaryContentSection: Self.minimalJSON))
        let section = try #require(node.primaryContentSections.first as? RESTBodyRenderSection)
        #expect(section.kind == .restBody)
        #expect(section.mimeType == "application/json")
    }

    @Test func missingRequiredKeyThrows() throws {
        #expect(throws: (any Error).self) {
            try decode(RESTBodyRenderSection.self, "{ \"kind\": \"restBody\", \"title\": \"HTTP Body\" }")
        }
    }
}
