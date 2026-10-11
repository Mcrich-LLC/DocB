// Shape tests for `UserInterfaceStyle`, the light/dark trait used by `DataTraitCollection`.

import Testing
@testable import DocCSchema

@Suite struct UserInterfaceStyleTests {
    @Test func decodesAllRawValues() throws {
        // Wrapped in an array so the shared `roundTrip` helper (which needs a top-level array
        // or object for its `JSONSerialization`-based diff) can be used on these bare-string cases.
        let values = try roundTrip([UserInterfaceStyle].self, "[\"light\", \"dark\"]")
        #expect(values == [.light, .dark])
    }

    @Test func allCasesMatchesRawValues() {
        #expect(UserInterfaceStyle.allCases.map(\.rawValue) == ["light", "dark"])
    }

    @Test func unknownRawValueThrows() {
        #expect(throws: (any Error).self) {
            try decode(UserInterfaceStyle.self, "\"sepia\"")
        }
    }
}
