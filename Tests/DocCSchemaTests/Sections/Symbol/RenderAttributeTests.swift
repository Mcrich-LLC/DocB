// Shape tests for RenderAttribute: a discriminated enum of symbol attributes (default,
// bounds, lengths, and allowed values/types), keyed by its "kind" discriminator.

import Testing
@testable import DocCSchema

@Suite struct RenderAttributeTests {
    @Test func decodesSingleValueKinds() throws {
        #expect(try decode(RenderAttribute.self, "{ \"kind\": \"default\", \"value\": \"none\" }") == .default("none"))
        #expect(try decode(RenderAttribute.self, "{ \"kind\": \"minimum\", \"value\": \"1\" }") == .minimum("1"))
        #expect(try decode(RenderAttribute.self, "{ \"kind\": \"minimumExclusive\", \"value\": \"0\" }") == .minimumExclusive("0"))
        #expect(try decode(RenderAttribute.self, "{ \"kind\": \"maximum\", \"value\": \"10\" }") == .maximum("10"))
        #expect(try decode(RenderAttribute.self, "{ \"kind\": \"maximumExclusive\", \"value\": \"11\" }") == .maximumExclusive("11"))
        #expect(try decode(RenderAttribute.self, "{ \"kind\": \"minimumLength\", \"value\": \"1\" }") == .minimumLength("1"))
        #expect(try decode(RenderAttribute.self, "{ \"kind\": \"maximumLength\", \"value\": \"255\" }") == .maximumLength("255"))
    }

    @Test func decodesAllowedValues() throws {
        let json = """
        { "kind": "allowedValues", "values": ["none", "some", "all"] }
        """
        #expect(try decode(RenderAttribute.self, json) == .allowedValues(["none", "some", "all"]))
    }

    @Test func decodesAllowedTypes() throws {
        let json = """
        {
          "kind": "allowedTypes",
          "values": [
            [{ "kind": "typeIdentifier", "text": "String" }],
            [{ "kind": "typeIdentifier", "text": "Int" }]
          ]
        }
        """
        let attribute = try decode(RenderAttribute.self, json)
        guard case let .allowedTypes(types) = attribute else {
            Issue.record("Expected .allowedTypes")
            return
        }
        #expect(types.count == 2)
        #expect(types[0][0].text == "String")
    }

    @Test func roundTrips() throws {
        try roundTrip(RenderAttribute.self, "{ \"kind\": \"default\", \"value\": \"none\" }")
        try roundTrip(RenderAttribute.self, "{ \"kind\": \"allowedValues\", \"values\": [\"none\", \"all\"] }")
    }

    @Test func unknownKindIsPreserved() throws {
        let json = "{ \"kind\": \"unheardOf\", \"value\": \"x\" }"
        let value = try roundTrip(RenderAttribute.self, json)
        guard case .unknown(let payload) = value, case .dictionary(let object) = payload else {
            Issue.record("Expected .unknown")
            return
        }
        #expect(object["kind"] == .string("unheardOf"))
    }
}
