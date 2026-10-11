// Shape tests for RenderNodeVariantOverridesApplier: applying an interfaceLanguage-scoped
// override to a minimal render-node-shaped JSON document and checking the patched result.

import Foundation
import Testing
@testable import DocCSchema

@Suite struct RenderNodeVariantOverridesApplierTests {
    @Test func appliesMatchingOverrideAndRemovesVariantOverridesKey() throws {
        let original = Data("""
        {
          "metadata": { "title": "Example title" },
          "variantOverrides": [
            {
              "traits": [{ "interfaceLanguage": "occ" }],
              "patch": [{ "op": "replace", "path": "/metadata/title", "value": "Alt title" }]
            }
          ]
        }
        """.utf8)

        let patched = try RenderNodeVariantOverridesApplier().applyVariantOverrides(
            in: original,
            for: [.interfaceLanguage("occ")]
        )

        let object = try #require(JSONSerialization.jsonObject(with: patched) as? [String: Any])
        let metadata = try #require(object["metadata"] as? [String: Any])
        #expect(metadata["title"] as? String == "Alt title")
        #expect(object["variantOverrides"] == nil)
    }

    @Test func selectsTheOverrideMatchingTheRequestedTraitsAmongMultiple() throws {
        let original = Data("""
        {
          "metadata": { "title": "Example title" },
          "variantOverrides": [
            {
              "traits": [{ "interfaceLanguage": "swift" }],
              "patch": [{ "op": "replace", "path": "/metadata/title", "value": "Swift title" }]
            },
            {
              "traits": [{ "interfaceLanguage": "occ" }],
              "patch": [{ "op": "replace", "path": "/metadata/title", "value": "ObjC title" }]
            }
          ]
        }
        """.utf8)

        let patched = try RenderNodeVariantOverridesApplier().applyVariantOverrides(
            in: original,
            for: [.interfaceLanguage("occ")]
        )

        let object = try #require(JSONSerialization.jsonObject(with: patched) as? [String: Any])
        let metadata = try #require(object["metadata"] as? [String: Any])
        #expect(metadata["title"] as? String == "ObjC title")
    }

    @Test func returnsOriginalDataUnchangedWhenNoTraitsMatch() throws {
        let original = Data("""
        {
          "metadata": { "title": "Example title" },
          "variantOverrides": [
            {
              "traits": [{ "interfaceLanguage": "occ" }],
              "patch": [{ "op": "replace", "path": "/metadata/title", "value": "Alt title" }]
            }
          ]
        }
        """.utf8)

        let patched = try RenderNodeVariantOverridesApplier().applyVariantOverrides(
            in: original,
            for: [.interfaceLanguage("swift")]
        )

        #expect(patched == original)
    }

    @Test func returnsOriginalDataUnchangedWhenNoVariantOverridesPresent() throws {
        let original = Data("""
        { "metadata": { "title": "Example title" } }
        """.utf8)

        let patched = try RenderNodeVariantOverridesApplier().applyVariantOverrides(
            in: original,
            for: [.interfaceLanguage("occ")]
        )

        #expect(patched == original)
    }
}
