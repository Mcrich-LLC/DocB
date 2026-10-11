// Shape tests for TopicColor: an optional standard color identifier.

import Testing
@testable import DocCSchema

@Suite struct TopicColorTests {
    @Test func decodesWithStandardColorIdentifier() throws {
        let color = try decode(TopicColor.self, """
        {"standardColorIdentifier":"blue"}
        """)
        #expect(color.standardColorIdentifier == "blue")
    }

    @Test func decodesWithoutStandardColorIdentifier() throws {
        let color = try decode(TopicColor.self, "{}")
        #expect(color.standardColorIdentifier == nil)
    }

    @Test func roundTrips() throws {
        try roundTrip(TopicColor.self, """
        {"standardColorIdentifier":"purple"}
        """)
    }
}
