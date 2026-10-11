// Covers RenderSectionKind's raw-value mapping, including the `plistDetails` case whose
// wire value ("details") differs from its case name.

import Testing
@testable import DocCSchema

@Suite struct RenderSectionKindTests {
    @Test func decodesStandardRawValues() throws {
        #expect(try decode(RenderSectionKind.self, "\"hero\"") == .hero)
        #expect(try decode(RenderSectionKind.self, "\"content\"") == .content)
        #expect(try decode(RenderSectionKind.self, "\"taskGroup\"") == .taskGroup)
        #expect(try decode(RenderSectionKind.self, "\"section\"") == .section)
    }

    @Test func decodesPlistDetailsCustomRawValue() throws {
        #expect(try decode(RenderSectionKind.self, "\"details\"") == .plistDetails)
    }

    @Test func roundTripsPlistDetails() throws {
        // Wrapped in an array: JSONSerialization (used by `roundTrip`'s subset check) rejects a
        // bare top-level string fragment.
        try roundTrip([RenderSectionKind].self, "[\"details\"]")
    }

    @Test func unknownRawValueIsPreserved() throws {
        let value = try decode(RenderSectionKind.self, "\"bogus\"")
        #expect(value == .unknown("bogus"))
        let encoded = try RenderJSONEncoder.makeEncoder().encode(value)
        #expect(try decode(RenderSectionKind.self, String(decoding: encoded, as: UTF8.self)) == value)
    }
}
