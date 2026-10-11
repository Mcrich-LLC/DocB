// Shape tests for PropertyListTitleStyle: how a property list key link should be titled
// (raw key vs. display name), including its non-obvious raw values ("symbol"/"title").

import Foundation
import Testing
@testable import DocCSchema

@Suite struct PropertyListTitleStyleTests {
    @Test func rawValues() {
        #expect(PropertyListTitleStyle.useRawKey.rawValue == "symbol")
        #expect(PropertyListTitleStyle.useDisplayName.rawValue == "title")
    }

    @Test func decodesRawValues() throws {
        #expect(try decode(PropertyListTitleStyle.self, "\"symbol\"") == .useRawKey)
        #expect(try decode(PropertyListTitleStyle.self, "\"title\"") == .useDisplayName)
    }

    // roundTrip's JSONSerialization-based subset check requires a top-level array/object, but
    // this type's wire form is a bare JSON string, so this checks the round trip directly.
    @Test func roundTrips() throws {
        let value = try decode(PropertyListTitleStyle.self, "\"title\"")
        let encoded = try RenderJSONEncoder.makeEncoder().encode(value)
        #expect(try decode(PropertyListTitleStyle.self, String(data: encoded, encoding: .utf8)!) == value)
    }

    @Test func unknownValueIsPreserved() throws {
        let value = try decode(PropertyListTitleStyle.self, "\"raw\"")
        #expect(value == .unknown("raw"))
        let encoded = try RenderJSONEncoder.makeEncoder().encode(value)
        #expect(try decode(PropertyListTitleStyle.self, String(data: encoded, encoding: .utf8)!) == value)
    }
}
