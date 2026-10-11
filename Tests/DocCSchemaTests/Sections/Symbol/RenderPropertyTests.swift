// Shape tests for RenderProperty: a named property with a declaration-style type and
// optional required/deprecated/readOnly flags, as listed in a PropertiesRenderSection.
//
// Note: required/deprecated/readOnly each carry a `= false` Swift-construction default, but
// since they're Optional-typed, a missing key decodes to nil, not to that default.

import Testing
@testable import DocCSchema

@Suite struct RenderPropertyTests {
    @Test func decodesMinimalPayload() throws {
        let json = """
        {
          "name": "title",
          "type": [{ "kind": "typeIdentifier", "text": "String" }]
        }
        """
        let property = try decode(RenderProperty.self, json)
        #expect(property.name == "title")
        #expect(property.type.count == 1)
        #expect(property.typeDetails == nil)
        #expect(property.content == nil)
        #expect(property.attributes == nil)
        #expect(property.mimeType == nil)
        #expect(property.required == nil)
        #expect(property.deprecated == nil)
        #expect(property.readOnly == nil)
        #expect(property.introducedVersion == nil)
    }

    @Test func decodesFullPayload() throws {
        let json = """
        {
          "name": "title",
          "type": [{ "kind": "typeIdentifier", "text": "String" }],
          "typeDetails": [{ "baseType": "String", "arrayMode": false }],
          "content": [
            { "type": "paragraph", "inlineContent": [{ "type": "text", "text": "The title." }] }
          ],
          "attributes": [{ "kind": "default", "value": "none" }],
          "mimeType": "text/plain",
          "required": true,
          "deprecated": true,
          "readOnly": true,
          "introducedVersion": "1.0"
        }
        """
        let property = try decode(RenderProperty.self, json)
        #expect(property.typeDetails?.first?.baseType == "String")
        #expect(property.content?.count == 1)
        #expect(property.attributes?.count == 1)
        #expect(property.mimeType == "text/plain")
        #expect(property.required == true)
        #expect(property.deprecated == true)
        #expect(property.readOnly == true)
        #expect(property.introducedVersion == "1.0")
    }

    @Test func roundTrips() throws {
        try roundTrip(RenderProperty.self, """
        {
          "name": "title",
          "type": [{ "kind": "typeIdentifier", "text": "String" }],
          "mimeType": "text/plain",
          "required": true,
          "introducedVersion": "1.0"
        }
        """)
    }

    @Test func missingRequiredKeyThrows() throws {
        #expect(throws: (any Error).self) {
            try decode(RenderProperty.self, "{ \"name\": \"title\" }")
        }
    }
}
