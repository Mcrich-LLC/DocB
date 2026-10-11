// Shape tests for TopicImage: a page's author-provided icon or card image, keyed by a
// reference identifier and discriminated by its purpose.

import Testing
@testable import DocCSchema

@Suite struct TopicImageTests {
    @Test func decodesIconType() throws {
        let image = try decode(TopicImage.self, """
        {"type":"icon","identifier":"doc://com.example/documentation/examplekit/icon.png"}
        """)
        #expect(image.type == .icon)
        #expect(image.identifier.identifier == "doc://com.example/documentation/examplekit/icon.png")
    }

    @Test func decodesCardType() throws {
        let image = try decode(TopicImage.self, """
        {"type":"card","identifier":"doc://com.example/documentation/examplekit/card.png"}
        """)
        #expect(image.type == .card)
    }

    @Test func roundTrips() throws {
        try roundTrip(TopicImage.self, """
        {"type":"icon","identifier":"doc://com.example/documentation/examplekit/icon.png"}
        """)
    }

    @Test func missingTypeThrows() {
        #expect(throws: (any Error).self) {
            try decode(TopicImage.self, """
            {"identifier":"doc://com.example/documentation/examplekit/icon.png"}
            """)
        }
    }
}
