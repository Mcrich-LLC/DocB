// Shape tests for AvailabilityRenderItem: per-platform availability info, including its
// renamed wire keys (introducedAt/deprecatedAt/obsoletedAt/unavailable/beta).

import Testing
@testable import DocCSchema

@Suite struct AvailabilityRenderItemTests {
    @Test func decodesMinimalPayload() throws {
        let item = try decode(AvailabilityRenderItem.self, "{}")
        #expect(item.name == nil)
        #expect(item.introduced == nil)
        #expect(item.isBeta == nil)
    }

    @Test func decodesFullPayload() throws {
        let json = """
        {
          "name": "exampleOS",
          "introducedAt": "1.0",
          "deprecatedAt": "2.0",
          "obsoletedAt": "3.0",
          "message": "Use something else instead.",
          "renamed": "newThing()",
          "deprecated": true,
          "unavailable": false,
          "beta": true
        }
        """
        let item = try decode(AvailabilityRenderItem.self, json)
        #expect(item.name == "exampleOS")
        #expect(item.introduced == "1.0")
        #expect(item.deprecated == "2.0")
        #expect(item.obsoleted == "3.0")
        #expect(item.message == "Use something else instead.")
        #expect(item.renamed == "newThing()")
        #expect(item.unconditionallyDeprecated == true)
        #expect(item.unconditionallyUnavailable == false)
        #expect(item.isBeta == true)
    }

    @Test func roundTrips() throws {
        try roundTrip(AvailabilityRenderItem.self, """
        {
          "name": "exampleOS",
          "introducedAt": "1.0",
          "beta": false
        }
        """)
    }
}
