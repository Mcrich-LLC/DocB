// Shape tests for ImageReference: alt text plus a set of display/scale variant proxies,
// rebuilt into a DataAsset on decode.

import Testing
@testable import DocCSchema

@Suite struct ImageReferenceTests {
    @Test func decodesMinimalPayload() throws {
        let reference = try decode(ImageReference.self, """
        {"type":"image","identifier":"doc://com.example/images/thing.png","variants":[]}
        """)
        #expect(reference.type == .image)
        #expect(reference.altText == nil)
        #expect(reference.asset.variants.isEmpty)
    }

    @Test func decodesWithAltTextAndVariants() throws {
        let reference = try decode(ImageReference.self, """
        {
          "type": "image",
          "identifier": "doc://com.example/images/thing.png",
          "alt": "An example image",
          "variants": [
            {"url": "https://example.com/thing-1x.png", "traits": ["1x"]},
            {"url": "https://example.com/thing-2x.png", "traits": ["2x", "dark"], "svgID": "icon123"}
          ]
        }
        """)
        #expect(reference.altText == "An example image")
        #expect(reference.asset.variants.count == 2)

        let darkVariant = DataTraitCollection(userInterfaceStyle: .dark, displayScale: .double)
        #expect(reference.asset.variants[darkVariant]?.absoluteString == "https://example.com/thing-2x.png")
        #expect(reference.asset.metadata[reference.asset.variants[darkVariant]!]?.svgID == "icon123")
    }

    @Test func roundTrips() throws {
        try roundTrip(ImageReference.self, """
        {
          "type": "image",
          "identifier": "doc://com.example/images/thing.png",
          "alt": "An example image",
          "variants": [
            {"url": "https://example.com/thing-1x.png", "traits": ["1x"]},
            {"url": "https://example.com/thing-2x.png", "traits": ["2x", "dark"], "svgID": "icon123"}
          ]
        }
        """)
    }

    @Test func missingVariantsThrows() {
        #expect(throws: (any Error).self) {
            try decode(ImageReference.self, """
            {"type":"image","identifier":"doc://com.example/images/thing.png"}
            """)
        }
    }
}
