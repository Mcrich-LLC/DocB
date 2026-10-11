// Shape tests for VariantCollection: decoding/encoding a value with variants through a small
// Codable struct built on decodeVariantCollectionIfPresent/encodeVariantCollection, and
// VariantCollection.Variant's mapValues transform.

import Foundation
import Testing
@testable import DocCSchema

/// A minimal Codable type exercising the `VariantCollection` keyed-container coding helpers,
/// the way `RenderNode`'s properties do.
private struct TitleContainer: Codable {
    var titleVariants: VariantCollection<String>

    private enum CodingKeys: String, CodingKey { case title }

    init(titleVariants: VariantCollection<String>) {
        self.titleVariants = titleVariants
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        titleVariants = try container.decodeVariantCollectionIfPresent(
            ofValueType: String.self,
            forKey: .title
        ) ?? VariantCollection(defaultValue: "")
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeVariantCollection(titleVariants, forKey: .title, encoder: encoder)
    }
}

@Suite struct VariantCollectionTests {
    @Test func decodesDefaultValueFromPlainJSON() throws {
        let value = try decode(TitleContainer.self, #"{"title":"Example title"}"#)
        #expect(value.titleVariants.defaultValue == "Example title")
        // Decoding a VariantCollection always yields an empty `variants` array: overrides for a
        // render node are decoded separately, from the top-level `variantOverrides` property.
        #expect(value.titleVariants.variants.isEmpty)
    }

    @Test func fallsBackToProvidedDefaultWhenKeyIsMissing() throws {
        let value = try decode(TitleContainer.self, "{}")
        #expect(value.titleVariants.defaultValue == "")
    }

    @Test func roundTripsDefaultValue() throws {
        try roundTrip(TitleContainer.self, #"{"title":"Example title"}"#)
    }

    @Test func encodingAccumulatesReplaceOverrideIntoVariantOverrides() throws {
        let container = TitleContainer(titleVariants: VariantCollection(
            defaultValue: "Example title",
            variants: [
                .init(traits: [.interfaceLanguage("occ")], patch: [.replace(value: "Alt title")])
            ]
        ))

        let encoder = RenderJSONEncoder.makeEncoder()
        let overrides = try #require(encoder.userInfoVariantOverrides)
        let data = try encoder.encode(container)

        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["title"] as? String == "Example title")

        #expect(overrides.values.count == 1)
        let variantOverride = try #require(overrides.values.first)
        #expect(variantOverride.traits == [.interfaceLanguage("occ")])
        #expect(variantOverride.patch.count == 1)
        #expect(variantOverride.patch[0].pointer.pathComponents == ["title"])
        #expect(variantOverride.patch[0].operation == .replace)
    }

    @Test func mapValuesTransformsDefaultAndVariantPatches() {
        let collection = VariantCollection(
            defaultValue: 1,
            variants: [.init(traits: [.interfaceLanguage("occ")], patch: [.replace(value: 2)])]
        )
        let mapped = collection.mapValues { String($0) }
        #expect(mapped.defaultValue == "1")
        #expect(mapped.variants.count == 1)
        guard case .replace(let value) = mapped.variants[0].patch[0] else {
            Issue.record("expected a replace patch operation")
            return
        }
        #expect(value == "2")
    }
}
