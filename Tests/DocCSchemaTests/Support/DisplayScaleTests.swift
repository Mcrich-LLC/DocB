// Shape tests for `DisplayScale`, the 1x/2x/3x scale factor used by `DataTraitCollection`.

import Testing
@testable import DocCSchema

@Suite struct DisplayScaleTests {
    @Test func decodesAllRawValues() throws {
        // Wrapped in an array so the shared `roundTrip` helper (which needs a top-level array
        // or object for its `JSONSerialization`-based diff) can be used on these bare-string cases.
        let values = try roundTrip([DisplayScale].self, "[\"1x\", \"2x\", \"3x\"]")
        #expect(values == [.standard, .double, .triple])
    }

    @Test func allCasesMatchesRawValues() {
        #expect(DisplayScale.allCases.map(\.rawValue) == ["1x", "2x", "3x"])
    }

    @Test func unknownRawValueThrows() {
        #expect(throws: (any Error).self) {
            try decode(DisplayScale.self, "\"4x\"")
        }
    }
}
