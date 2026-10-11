// Shape tests for VariantOverride: traits + patch nesting and coding.

import Testing
@testable import DocCSchema

@Suite struct VariantOverrideTests {
    @Test func decodesTraitsAndPatch() throws {
        let json = """
        {
          "traits": [{ "interfaceLanguage": "occ" }],
          "patch": [{ "op": "replace", "path": "/metadata/title", "value": "Alt title" }]
        }
        """
        let override = try decode(VariantOverride.self, json)
        #expect(override.traits == [.interfaceLanguage("occ")])
        #expect(override.patch.count == 1)
        #expect(override.patch[0].pointer.pathComponents == ["metadata", "title"])
    }

    @Test func decodesMultipleTraitsAndPatchOperations() throws {
        let json = """
        {
          "traits": [{ "interfaceLanguage": "occ" }, { "interfaceLanguage": "swift" }],
          "patch": [
            { "op": "replace", "path": "/metadata/title", "value": "Alt title" },
            { "op": "remove", "path": "/metadata/subtitle" }
          ]
        }
        """
        let override = try decode(VariantOverride.self, json)
        #expect(override.traits.count == 2)
        #expect(override.patch.count == 2)
        #expect(override.patch[1].operation == .remove)
    }

    @Test func roundTrips() throws {
        let json = """
        {
          "traits": [{ "interfaceLanguage": "occ" }],
          "patch": [{ "op": "replace", "path": "/metadata/title", "value": "Alt title" }]
        }
        """
        try roundTrip(VariantOverride.self, json)
    }

    @Test func throwsWhenTraitsKeyIsMissing() {
        let json = """
        { "patch": [] }
        """
        #expect(throws: (any Error).self) {
            try decode(VariantOverride.self, json)
        }
    }
}
