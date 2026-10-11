// Shape tests for RESTEndpointRenderSection and its nested Token: a tokenized REST
// endpoint (method/baseURL/path/parameter/text), including dispatch through
// RenderNode.primaryContentSections via its "restEndpoint" kind.

import Testing
@testable import DocCSchema

@Suite struct RESTEndpointRenderSectionTests {
    static let minimalJSON = """
    {
      "kind": "restEndpoint",
      "title": "HTTP Endpoint",
      "tokens": [
        { "kind": "method", "text": "GET" },
        { "kind": "baseURL", "text": "https://example.com" },
        { "kind": "path", "text": "/api/artists/" },
        { "kind": "parameter", "text": "{id}" },
        { "kind": "text", "text": "?flag=1" }
      ]
    }
    """

    @Test func decodesPayload() throws {
        let section = try decode(RESTEndpointRenderSection.self, Self.minimalJSON)
        #expect(section.kind == .restEndpoint)
        #expect(section.title == "HTTP Endpoint")
        #expect(section.tokens.map(\.kind) == [.method, .baseURL, .path, .parameter, .text])
        #expect(section.tokens[0].text == "GET")
    }

    @Test func roundTrips() throws {
        try roundTrip(RESTEndpointRenderSection.self, Self.minimalJSON)
    }

    @Test func dispatchesThroughRenderNodePrimaryContentSections() throws {
        let node = try decode(RenderNode.self, renderNodeJSON(primaryContentSection: Self.minimalJSON))
        let section = try #require(node.primaryContentSections.first as? RESTEndpointRenderSection)
        #expect(section.kind == .restEndpoint)
        #expect(section.tokens.count == 5)
    }

    @Test func missingRequiredKeyThrows() throws {
        #expect(throws: (any Error).self) {
            try decode(RESTEndpointRenderSection.self, "{ \"kind\": \"restEndpoint\", \"title\": \"HTTP Endpoint\" }")
        }
    }
}
