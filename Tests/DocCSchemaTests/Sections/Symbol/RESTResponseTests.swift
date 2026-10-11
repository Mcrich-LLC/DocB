// Shape tests for RESTResponse: a single HTTP status/reason/mime-type/type-declaration
// entry, as listed inside a RESTResponseRenderSection.

import Testing
@testable import DocCSchema

@Suite struct RESTResponseTests {
    @Test func decodesMinimalPayload() throws {
        let json = """
        {
          "status": 200,
          "reason": null,
          "mimeType": null,
          "type": [{ "kind": "typeIdentifier", "text": "Artist" }]
        }
        """
        let response = try decode(RESTResponse.self, json)
        #expect(response.status == 200)
        #expect(response.reason == nil)
        #expect(response.mimeType == nil)
        #expect(response.type.count == 1)
        #expect(response.content == nil)
    }

    @Test func decodesFullPayload() throws {
        let json = """
        {
          "status": 404,
          "reason": "Not Found",
          "mimeType": "application/json",
          "type": [{ "kind": "typeIdentifier", "text": "Error" }],
          "content": [
            { "type": "paragraph", "inlineContent": [{ "type": "text", "text": "No such artist." }] }
          ]
        }
        """
        let response = try decode(RESTResponse.self, json)
        #expect(response.status == 404)
        #expect(response.reason == "Not Found")
        #expect(response.mimeType == "application/json")
        #expect(response.content?.count == 1)
    }

    @Test func roundTrips() throws {
        try roundTrip(RESTResponse.self, """
        {
          "status": 404,
          "reason": "Not Found",
          "mimeType": "application/json",
          "type": [{ "kind": "typeIdentifier", "text": "Error" }]
        }
        """)
    }

    @Test func missingRequiredKeyThrows() throws {
        #expect(throws: (any Error).self) {
            try decode(RESTResponse.self, "{ \"reason\": \"Not Found\" }")
        }
    }
}
