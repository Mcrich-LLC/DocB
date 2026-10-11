// Covers RenderNode.Variant and its nested Trait type: the `interfaceLanguage` trait shape
// and the fallback to `.unknown` when a trait object has none of the expected keys.

import Testing
@testable import DocCSchema

@Suite struct RenderNodeVariantTests {
    @Test func decodesMinimalVariant() throws {
        let variant = try decode(RenderNode.Variant.self, """
        {
            "traits": [{ "interfaceLanguage": "occ" }],
            "paths": ["/documentation/examplekit/thing-objc"]
        }
        """)
        #expect(variant.paths == ["/documentation/examplekit/thing-objc"])
        guard case .interfaceLanguage(let language) = variant.traits.first else {
            Issue.record("Expected an interfaceLanguage trait")
            return
        }
        #expect(language == "occ")
    }

    @Test func roundTrips() throws {
        try roundTrip(RenderNode.Variant.self, """
        {
            "traits": [{ "interfaceLanguage": "swift" }],
            "paths": ["/documentation/examplekit/thing"]
        }
        """)
    }

    @Test func traitMissingInterfaceLanguageIsPreserved() throws {
        let json = """
        {"bogus": "value"}
        """
        let value = try roundTrip(RenderNode.Variant.Trait.self, json)
        guard case .unknown(let payload) = value, case .dictionary(let object) = payload else {
            Issue.record("Expected .unknown")
            return
        }
        #expect(object["bogus"] == .string("value"))
    }
}
