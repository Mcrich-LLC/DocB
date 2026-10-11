// Shape tests for RenderReferenceIdentifier: a plain string wrapper, encoded/decoded as a
// bare JSON string rather than a keyed object.

import Testing
@testable import DocCSchema

@Suite struct RenderReferenceIdentifierTests {
    @Test func decodesBareString() throws {
        let identifier = try decode(RenderReferenceIdentifier.self, "\"doc://com.example/documentation/examplekit/thing\"")
        #expect(identifier.identifier == "doc://com.example/documentation/examplekit/thing")
    }

    @Test func roundTrips() throws {
        // `roundTrip` from JSONAssertions.swift shells out to `JSONSerialization`, which
        // rejects a bare JSON string (no enclosing array/object); check the round trip
        // directly instead, since this type always encodes as a single scalar value.
        let identifier = try decode(RenderReferenceIdentifier.self, "\"doc://com.example/documentation/examplekit/thing\"")
        let encoded = try RenderJSONEncoder.makeEncoder().encode(identifier)
        let decodedBack = try decode(RenderReferenceIdentifier.self, String(decoding: encoded, as: UTF8.self))
        #expect(decodedBack == identifier)
    }

    @Test func createsFromExternalLink() {
        let identifier = RenderReferenceIdentifier(forExternalLink: "https://example.com/page")
        #expect(identifier.identifier == "https://example.com/page")
    }
}
