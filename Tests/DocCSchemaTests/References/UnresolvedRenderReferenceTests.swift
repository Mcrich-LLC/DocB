// Shape tests for UnresolvedRenderReference: a reference to a page that could not be
// resolved, carrying only a title for display.

import Testing
@testable import DocCSchema

@Suite struct UnresolvedRenderReferenceTests {
    @Test func decodesPayload() throws {
        let reference = try decode(UnresolvedRenderReference.self, """
        {"type":"unresolvable","identifier":"doc://com.example/documentation/examplekit/missing","title":"Missing Thing"}
        """)
        #expect(reference.type == .unresolvable)
        #expect(reference.identifier.identifier == "doc://com.example/documentation/examplekit/missing")
        #expect(reference.title == "Missing Thing")
    }

    @Test func roundTrips() throws {
        try roundTrip(UnresolvedRenderReference.self, """
        {"type":"unresolvable","identifier":"doc://com.example/documentation/examplekit/missing","title":"Missing Thing"}
        """)
    }

    @Test func missingTitleThrows() {
        #expect(throws: (any Error).self) {
            try decode(UnresolvedRenderReference.self, """
            {"type":"unresolvable","identifier":"doc://com.example/documentation/examplekit/missing"}
            """)
        }
    }
}
