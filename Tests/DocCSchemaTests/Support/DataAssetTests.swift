// Shape tests for `DataAsset` (and its nested `Context` enum and `Metadata` struct).
//
// `variants`/`metadata` are `[DataTraitCollection: URL]`/`[URL: Metadata]` dictionaries. Since
// neither key type is `String` or `Int`, Swift's synthesized `Codable` conformance encodes each
// as a flat JSON array of alternating key/value elements rather than a JSON object - confirmed
// by inspecting `RenderJSONEncoder`'s actual output. Tests use at most one entry per dictionary
// so that comparison doesn't depend on unspecified dictionary iteration order.

import Foundation
import Testing
@testable import DocCSchema

@Suite struct DataAssetTests {
    @Test func decodesMinimalPayload() throws {
        let value = try roundTrip(DataAsset.self, """
        {"variants": [], "metadata": [], "context": "display"}
        """)
        #expect(value.variants.isEmpty)
        #expect(value.metadata.isEmpty)
        #expect(value.context == .display)
    }

    @Test func decodesFullPayload() throws {
        let value = try roundTrip(DataAsset.self, """
        {
          "variants": [{"displayScale": "2x", "userInterfaceStyle": "light"}, "https://example.com/image.png"],
          "metadata": ["https://example.com/image.png", {"svgID": "icon-name"}],
          "context": "download"
        }
        """)
        #expect(value.context == .download)
        let trait = DataTraitCollection(userInterfaceStyle: .light, displayScale: .double)
        let url = try #require(URL(string: "https://example.com/image.png"))
        #expect(value.variants[trait] == url)
        #expect(value.metadata[url]?.svgID == "icon-name")
    }

    @Test func contextRawValues() throws {
        // Wrapped in an array so the shared `roundTrip` helper can be used on these bare-string cases.
        let values = try roundTrip([DataAsset.Context].self, "[\"display\", \"download\"]")
        #expect(values == [.display, .download])
    }

    @Test func metadataDefaultsSVGIDToNil() throws {
        let value = try roundTrip(DataAsset.Metadata.self, "{}")
        #expect(value.svgID == nil)
    }

    @Test func missingRequiredKeyThrows() {
        #expect(throws: (any Error).self) {
            try decode(DataAsset.self, """
            {"variants": [], "metadata": []}
            """)
        }
    }
}
