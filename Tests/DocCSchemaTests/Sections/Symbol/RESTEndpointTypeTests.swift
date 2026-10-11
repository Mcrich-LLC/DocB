// Shape tests for RESTEndpointType: a production/sandbox REST endpoint kind.

import Foundation
import Testing
@testable import DocCSchema

@Suite struct RESTEndpointTypeTests {
    @Test func decodesRawValues() throws {
        #expect(try decode(RESTEndpointType.self, "\"production\"") == .production)
        #expect(try decode(RESTEndpointType.self, "\"sandbox\"") == .sandbox)
    }

    // roundTrip's JSONSerialization-based subset check requires a top-level array/object, but
    // this type's wire form is a bare JSON string, so this checks the round trip directly.
    @Test func roundTrips() throws {
        let value = try decode(RESTEndpointType.self, "\"sandbox\"")
        let encoded = try RenderJSONEncoder.makeEncoder().encode(value)
        #expect(try decode(RESTEndpointType.self, String(data: encoded, encoding: .utf8)!) == value)
    }

    @Test func unknownValueIsPreserved() throws {
        let value = try decode(RESTEndpointType.self, "\"staging\"")
        #expect(value == .unknown("staging"))
        let encoded = try RenderJSONEncoder.makeEncoder().encode(value)
        #expect(try decode(RESTEndpointType.self, String(data: encoded, encoding: .utf8)!) == value)
    }
}
