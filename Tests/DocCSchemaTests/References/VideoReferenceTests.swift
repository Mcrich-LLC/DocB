// Shape tests for VideoReference: alt text, variant proxies rebuilt into a DataAsset, and an
// optional poster image reference.

import Testing
@testable import DocCSchema

@Suite struct VideoReferenceTests {
    @Test func decodesMinimalPayload() throws {
        let reference = try decode(VideoReference.self, """
        {"type":"video","identifier":"doc://com.example/videos/thing.mp4","variants":[]}
        """)
        #expect(reference.type == .video)
        #expect(reference.altText == nil)
        #expect(reference.poster == nil)
        #expect(reference.asset.variants.isEmpty)
    }

    @Test func decodesWithPosterAndVariants() throws {
        let reference = try decode(VideoReference.self, """
        {
          "type": "video",
          "identifier": "doc://com.example/videos/thing.mp4",
          "alt": "An example video",
          "variants": [
            {"url": "https://example.com/thing-1x.mp4", "traits": ["1x"]},
            {"url": "https://example.com/thing-2x.mp4", "traits": ["2x", "dark"]}
          ],
          "poster": "doc://com.example/images/poster.png"
        }
        """)
        #expect(reference.altText == "An example video")
        #expect(reference.asset.variants.count == 2)
        #expect(reference.poster?.identifier == "doc://com.example/images/poster.png")
    }

    @Test func roundTrips() throws {
        try roundTrip(VideoReference.self, """
        {
          "type": "video",
          "identifier": "doc://com.example/videos/thing.mp4",
          "alt": "An example video",
          "variants": [
            {"url": "https://example.com/thing-1x.mp4", "traits": ["1x"]},
            {"url": "https://example.com/thing-2x.mp4", "traits": ["2x", "dark"]}
          ],
          "poster": "doc://com.example/images/poster.png"
        }
        """)
    }

    @Test func missingVariantsThrows() {
        #expect(throws: (any Error).self) {
            try decode(VideoReference.self, """
            {"type":"video","identifier":"doc://com.example/videos/thing.mp4"}
            """)
        }
    }
}
