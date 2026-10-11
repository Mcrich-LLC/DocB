// Shape tests for DiffAvailability and its nested Info: per-bucket (beta/minor/major/sdk)
// availability-change diffs.

import Testing
@testable import DocCSchema

@Suite struct DiffAvailabilityTests {
    @Test func decodesMinimalPayload() throws {
        let diff = try decode(DiffAvailability.self, "{}")
        #expect(diff.beta == nil)
        #expect(diff.minor == nil)
        #expect(diff.major == nil)
        #expect(diff.sdk == nil)
    }

    @Test func decodesFullPayload() throws {
        let json = """
        {
          "beta": { "change": "modified", "platform": "exampleOS", "versions": ["1.0", "1.1"] },
          "minor": { "change": "added", "platform": "exampleOS", "versions": ["1.1"] },
          "major": { "change": "added", "platform": "exampleOS", "versions": ["2.0"] },
          "sdk": { "change": "modified", "platform": "exampleOS", "versions": ["2.0", "2.1"] }
        }
        """
        let diff = try decode(DiffAvailability.self, json)
        #expect(diff.beta?.change == "modified")
        #expect(diff.beta?.platform == "exampleOS")
        #expect(diff.beta?.versions == ["1.0", "1.1"])
        #expect(diff.minor?.change == "added")
        #expect(diff.major?.versions == ["2.0"])
        #expect(diff.sdk?.change == "modified")
    }

    @Test func roundTrips() throws {
        try roundTrip(DiffAvailability.self, """
        {
          "beta": { "change": "modified", "platform": "exampleOS", "versions": ["1.0"] }
        }
        """)
    }

    @Test func infoMissingRequiredKeyThrows() throws {
        #expect(throws: (any Error).self) {
            try decode(DiffAvailability.self, """
            { "beta": { "change": "modified", "platform": "exampleOS" } }
            """)
        }
    }
}
