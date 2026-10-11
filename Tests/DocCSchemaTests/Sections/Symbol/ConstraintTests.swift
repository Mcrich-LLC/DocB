// Shape tests for Constraint: a single generic constraint (kind + left/right type names)
// used to build ConformanceSection sentences, including its four Kind raw values.

import Testing
@testable import DocCSchema

@Suite struct ConstraintTests {
    @Test func decodesPayload() throws {
        let json = """
        { "kind": "conformance", "leftTypeName": "Element", "rightTypeName": "Equatable" }
        """
        let constraint = try decode(Constraint.self, json)
        #expect(constraint.kind == .conformance)
        #expect(constraint.leftTypeName == "Element")
        #expect(constraint.rightTypeName == "Equatable")
    }

    @Test func kindRawValues() throws {
        #expect(Constraint.Kind.conformance.rawValue == "conformance")
        #expect(Constraint.Kind.sameType.rawValue == "sameType")
        #expect(Constraint.Kind.superclass.rawValue == "superclass")
        #expect(Constraint.Kind.sameShape.rawValue == "sameShape")
        #expect(try decode(Constraint.Kind.self, "\"conformance\"") == .conformance)
        #expect(try decode(Constraint.Kind.self, "\"sameShape\"") == .sameShape)
    }

    @Test func roundTrips() throws {
        try roundTrip(Constraint.self, """
        { "kind": "sameType", "leftTypeName": "Self.Element", "rightTypeName": "Int" }
        """)
    }

    @Test func missingRequiredKeyThrows() throws {
        #expect(throws: (any Error).self) {
            try decode(Constraint.self, "{ \"kind\": \"conformance\", \"leftTypeName\": \"Element\" }")
        }
    }
}
