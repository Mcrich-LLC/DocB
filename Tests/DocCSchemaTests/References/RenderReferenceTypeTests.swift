// Shape tests for RenderReferenceType: the discriminator string for every kind of reference
// a render node can hold.

import Testing
@testable import DocCSchema

@Suite struct RenderReferenceTypeTests {
    @Test func decodesEveryDocumentedRawValue() throws {
        let cases: [(String, RenderReferenceType)] = [
            ("image", .image),
            ("video", .video),
            ("file", .file),
            ("fileType", .fileType),
            ("xcodeRequirement", .xcodeRequirement),
            ("topic", .topic),
            ("section", .section),
            ("download", .download),
            ("link", .link),
            ("externalLocation", .externalLocation),
            ("unresolvable", .unresolvable),
        ]
        for (raw, expected) in cases {
            let decoded = try decode(RenderReferenceType.self, "\"\(raw)\"")
            #expect(decoded == expected)
        }
    }

    @Test func roundTripsRawValue() throws {
        // `roundTrip` from JSONAssertions.swift shells out to `JSONSerialization`, which
        // rejects a bare JSON string (no enclosing array/object); check the round trip
        // directly instead, since this type always encodes as a single scalar value.
        let value = try decode(RenderReferenceType.self, "\"topic\"")
        let encoded = try RenderJSONEncoder.makeEncoder().encode(value)
        #expect(String(decoding: encoded, as: UTF8.self) == "\"topic\"")
    }

    @Test func unknownValueIsPreserved() throws {
        let value = try decode(RenderReferenceType.self, "\"bogus\"")
        #expect(value == .unknown("bogus"))
        let encoded = try RenderJSONEncoder.makeEncoder().encode(value)
        #expect(try decode(RenderReferenceType.self, String(decoding: encoded, as: UTF8.self)) == value)
    }
}
