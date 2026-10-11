// Shape tests for `JSON`, the untyped JSON value used to carry arbitrary payloads (through
// `AnyCodable`). Covers each case (object, array, string, number, boolean, null) decoding to
// the right case and round-tripping.

import Testing
@testable import DocCSchema

@Suite struct JSONTests {
    @Test func decodesObjectWithNestedValues() throws {
        let value = try roundTrip(JSON.self, """
        {"title": "Example title", "count": 3, "enabled": true, "note": null, "tags": ["a", "b"]}
        """)
        let dict = try #require(value.dictionary)
        #expect(dict["title"]?.string == "Example title")
        #expect(dict["count"]?.number == 3)
        #expect(dict["enabled"]?.bool == true)
        #expect(dict["note"] != nil) // present, decodes to .null rather than being absent
        #expect(dict["note"]?.dictionary == nil && dict["note"]?.string == nil) // .null carries no payload
        #expect(dict["tags"]?.array?.map(\.string) == ["a", "b"])
    }

    @Test func decodesArrayOfMixedValues() throws {
        let value = try roundTrip(JSON.self, "[1, \"two\", false, null]")
        let array = try #require(value.array)
        #expect(array.map(\.number) == [1, nil, nil, nil])
        #expect(array.map(\.string) == [nil, "two", nil, nil])
        #expect(array.map(\.bool) == [nil, nil, false, nil])
    }

    @Test func decodesEachScalarCase() throws {
        // Bare top-level scalars aren't valid input to `JSONSerialization.jsonObject`, so the
        // shared `roundTrip` helper (which uses it to diff JSON) can't be used here; decode and
        // re-encode by hand instead.
        #expect(try decode(JSON.self, "42.5").number == 42.5)
        #expect(try decode(JSON.self, "\"hello\"").string == "hello")
        #expect(try decode(JSON.self, "true").bool == true)
        #expect(try decode(JSON.self, "null").dictionary == nil)

        let encoder = RenderJSONEncoder.makeEncoder()
        #expect(String(data: try encoder.encode(JSON.number(42.5)), encoding: .utf8) == "42.5")
        #expect(String(data: try encoder.encode(JSON.string("hello")), encoding: .utf8) == "\"hello\"")
        #expect(String(data: try encoder.encode(JSON.boolean(true)), encoding: .utf8) == "true")
        #expect(String(data: try encoder.encode(JSON.null), encoding: .utf8) == "null")
    }
}
