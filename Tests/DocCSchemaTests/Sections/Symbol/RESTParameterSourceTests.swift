// Shape tests for RESTParameterSource: where a REST parameter is carried (query, path,
// header, or cookie).

import Foundation
import Testing
@testable import DocCSchema

@Suite struct RESTParameterSourceTests {
    @Test func rawValues() throws {
        #expect(RESTParameterSource.query.rawValue == "query")
        #expect(RESTParameterSource.path.rawValue == "path")
        #expect(RESTParameterSource.header.rawValue == "header")
        #expect(RESTParameterSource.cookie.rawValue == "cookie")
        #expect(try decode(RESTParameterSource.self, "\"query\"") == .query)
        #expect(try decode(RESTParameterSource.self, "\"cookie\"") == .cookie)
    }

    // roundTrip's JSONSerialization-based subset check requires a top-level array/object, but
    // this type's wire form is a bare JSON string, so this checks the round trip directly.
    @Test func roundTrips() throws {
        let value = try decode(RESTParameterSource.self, "\"cookie\"")
        let encoded = try RenderJSONEncoder.makeEncoder().encode(value)
        #expect(try decode(RESTParameterSource.self, String(data: encoded, encoding: .utf8)!) == value)
    }

    @Test func unknownValueIsPreserved() throws {
        let value = try decode(RESTParameterSource.self, "\"body\"")
        #expect(value == .unknown("body"))
        let encoded = try RenderJSONEncoder.makeEncoder().encode(value)
        #expect(try decode(RESTParameterSource.self, String(data: encoded, encoding: .utf8)!) == value)
    }
}
