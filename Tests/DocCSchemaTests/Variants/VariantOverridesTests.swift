// Shape tests for VariantOverrides: the top-level-array coding of its `values`, and its
// same-traits merging behavior.

import Testing
@testable import DocCSchema

@Suite struct VariantOverridesTests {
    @Test func decodesArrayOfOverrides() throws {
        let json = """
        [
          {
            "traits": [{ "interfaceLanguage": "occ" }],
            "patch": [{ "op": "replace", "path": "/metadata/title", "value": "Alt title" }]
          }
        ]
        """
        let overrides = try decode(VariantOverrides.self, json)
        #expect(overrides.isEmpty == false)
        #expect(overrides.values.count == 1)
    }

    @Test func decodesEmptyArrayAsEmpty() throws {
        let overrides = try decode(VariantOverrides.self, "[]")
        #expect(overrides.isEmpty)
    }

    @Test func roundTrips() throws {
        let json = """
        [
          {
            "traits": [{ "interfaceLanguage": "occ" }],
            "patch": [{ "op": "replace", "path": "/metadata/title", "value": "Alt title" }]
          }
        ]
        """
        try roundTrip(VariantOverrides.self, json)
    }

    @Test func addMergesPatchesForMatchingTraits() {
        let overrides = VariantOverrides(values: [
            VariantOverride(
                traits: [.interfaceLanguage("occ")],
                patch: [.replace(pointer: JSONPointer(pathComponents: ["title"]), encodableValue: "Alt title")]
            ),
            VariantOverride(
                traits: [.interfaceLanguage("occ")],
                patch: [.remove(pointer: JSONPointer(pathComponents: ["subtitle"]))]
            ),
        ])

        #expect(overrides.values.count == 1)
        #expect(overrides.values[0].patch.count == 2)
    }
}
