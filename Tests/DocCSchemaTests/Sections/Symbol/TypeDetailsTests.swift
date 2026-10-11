// Shape tests for TypeDetails: a base type name plus an optional array-mode flag.
//
// Note: arrayMode's `= false` is a Swift-construction default only; since the property is
// Optional, a missing key decodes to nil, not to the stated default.

import Testing
@testable import DocCSchema

@Suite struct TypeDetailsTests {
    @Test func decodesMinimalPayload() throws {
        let details = try decode(TypeDetails.self, "{}")
        #expect(details.baseType == nil)
        #expect(details.arrayMode == nil)
    }

    @Test func decodesFullPayload() throws {
        let json = """
        { "baseType": "String", "arrayMode": true }
        """
        let details = try decode(TypeDetails.self, json)
        #expect(details.baseType == "String")
        #expect(details.arrayMode == true)
    }

    @Test func roundTrips() throws {
        try roundTrip(TypeDetails.self, """
        { "baseType": "String", "arrayMode": true }
        """)
    }
}
