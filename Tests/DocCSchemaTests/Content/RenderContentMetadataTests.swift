// Covers RenderContentMetadata: all-optional fields, minimal (empty object), and full payload
// with a nested inline-content abstract.

import Testing
@testable import DocCSchema

@Suite struct RenderContentMetadataTests {
    @Test func decodesMinimalEmptyPayload() throws {
        let metadata = try roundTrip(RenderContentMetadata.self, "{}")
        #expect(metadata.anchor == nil)
        #expect(metadata.title == nil)
        #expect(metadata.abstract == nil)
        #expect(metadata.deviceFrame == nil)
    }

    @Test func decodesFullPayload() throws {
        let json = """
        {
            "anchor": "example-anchor",
            "title": "Example Title",
            "abstract": [
                { "type": "text", "text": "An example abstract." }
            ],
            "deviceFrame": "phone"
        }
        """
        let metadata = try roundTrip(RenderContentMetadata.self, json)
        #expect(metadata.anchor == "example-anchor")
        #expect(metadata.title == "Example Title")
        #expect(metadata.abstract == [.text("An example abstract.")])
        #expect(metadata.deviceFrame == "phone")
    }
}
