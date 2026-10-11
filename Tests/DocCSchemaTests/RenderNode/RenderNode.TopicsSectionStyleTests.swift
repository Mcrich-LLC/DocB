// Covers RenderNode.TopicsSectionStyle's raw-value mapping.

import Testing
@testable import DocCSchema

@Suite struct RenderNodeTopicsSectionStyleTests {
    @Test func decodesEachRawValue() throws {
        #expect(try decode(RenderNode.TopicsSectionStyle.self, "\"list\"") == .list)
        #expect(try decode(RenderNode.TopicsSectionStyle.self, "\"compactGrid\"") == .compactGrid)
        #expect(try decode(RenderNode.TopicsSectionStyle.self, "\"detailedGrid\"") == .detailedGrid)
        #expect(try decode(RenderNode.TopicsSectionStyle.self, "\"hidden\"") == .hidden)
    }

    @Test func roundTripsCompactGrid() throws {
        // Wrapped in an array: JSONSerialization (used by `roundTrip`'s subset check) rejects a
        // bare top-level string fragment.
        try roundTrip([RenderNode.TopicsSectionStyle].self, "[\"compactGrid\"]")
    }

    @Test func unknownRawValueIsPreserved() throws {
        let value = try decode(RenderNode.TopicsSectionStyle.self, "\"bogus\"")
        #expect(value == .unknown("bogus"))
        let encoded = try RenderJSONEncoder.makeEncoder().encode(value)
        #expect(try decode(RenderNode.TopicsSectionStyle.self, String(decoding: encoded, as: UTF8.self)) == value)
    }
}
