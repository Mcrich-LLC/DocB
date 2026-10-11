// Shape tests for `AnyCodable`, the type-erased wrapper that always decodes to an underlying
// `JSON` value. Covers object, array, scalar, and null payloads.

import Testing
@testable import DocCSchema

@Suite struct AnyCodableTests {
    @Test func decodesObject() throws {
        let value = try roundTrip(AnyCodable.self, """
        {"title": "Example title", "count": 3}
        """)
        let dict = try #require((value.value as? JSON)?.dictionary)
        #expect(dict["title"]?.string == "Example title")
        #expect(dict["count"]?.number == 3)
    }

    @Test func decodesArray() throws {
        let value = try roundTrip(AnyCodable.self, "[1, 2, 3]")
        let array = try #require((value.value as? JSON)?.array)
        #expect(array.map(\.number) == [1, 2, 3])
    }

    @Test func decodesScalarsAndNull() throws {
        // Bare top-level scalars aren't valid input to `JSONSerialization.jsonObject`, so the
        // shared `roundTrip` helper can't be used here; decode and re-encode by hand instead.
        let encoder = RenderJSONEncoder.makeEncoder()

        let string = try decode(AnyCodable.self, "\"hello\"")
        #expect((string.value as? JSON)?.string == "hello")
        #expect(String(data: try encoder.encode(string), encoding: .utf8) == "\"hello\"")

        let null = try decode(AnyCodable.self, "null")
        let nullJSON = try #require(null.value as? JSON)
        #expect(nullJSON.string == nil && nullJSON.number == nil && nullJSON.bool == nil && nullJSON.dictionary == nil && nullJSON.array == nil)
        #expect(String(data: try encoder.encode(null), encoding: .utf8) == "null")
    }
}
