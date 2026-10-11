// Shape tests for `ResolvedTopicReference`'s custom {url, interfaceLanguage} coding, where
// `interfaceLanguage` round-trips through `SourceLanguage.id` rather than the full language object.

import Testing
@testable import DocCSchema

@Suite struct ResolvedTopicReferenceTests {
    @Test func decodesKnownLanguage() throws {
        let value = try roundTrip(ResolvedTopicReference.self, """
        {"url": "doc://com.example/documentation/examplekit/thing", "interfaceLanguage": "swift"}
        """)
        #expect(value.absoluteString == "doc://com.example/documentation/examplekit/thing")
        #expect(value.path == "/documentation/examplekit/thing")
        #expect(value.sourceLanguage == .swift)
    }

    @Test func decodesCustomLanguageID() throws {
        let value = try roundTrip(ResolvedTopicReference.self, """
        {"url": "doc://com.example/documentation/examplekit/thing", "interfaceLanguage": "customlang"}
        """)
        #expect(value.sourceLanguage.id == "customlang")
        #expect(value.sourceLanguage.name == "customlang")
    }

    @Test func missingRequiredKeyThrows() {
        #expect(throws: (any Error).self) {
            try decode(ResolvedTopicReference.self, """
            {"url": "doc://com.example/documentation/examplekit/thing"}
            """)
        }
    }
}
