// Shape tests for ConformanceSection: rendered "Available when..." / "Conforms when..."
// generic-constraint sentences.
//
// Note: availabilityPrefix/conformancePrefix carry Swift default values (used when a
// ConformanceSection is constructed in code), but synthesized Decodable only falls back to a
// stored property's default for missing *Optional*-typed keys; these two are non-Optional, so
// they're required keys on decode just like `constraints`. All three payloads below spell
// them out explicitly.

import Testing
@testable import DocCSchema

@Suite struct ConformanceSectionTests {
    @Test func decodesMinimalPayload() throws {
        let json = """
        {
          "availabilityPrefix": [{ "type": "text", "text": "Available when" }],
          "conformancePrefix": [{ "type": "text", "text": "Conforms when" }],
          "constraints": [{ "type": "text", "text": "Element conforms to Equatable" }]
        }
        """
        let section = try decode(ConformanceSection.self, json)
        #expect(section.constraints == [.text("Element conforms to Equatable")])
        #expect(section.availabilityPrefix == [.text("Available when")])
        #expect(section.conformancePrefix == [.text("Conforms when")])
    }

    @Test func decodesFullPayload() throws {
        let json = """
        {
          "availabilityPrefix": [{ "type": "text", "text": "Present when" }],
          "conformancePrefix": [{ "type": "text", "text": "Matches when" }],
          "constraints": [{ "type": "text", "text": "Self is Foo" }]
        }
        """
        let section = try decode(ConformanceSection.self, json)
        #expect(section.availabilityPrefix == [.text("Present when")])
        #expect(section.conformancePrefix == [.text("Matches when")])
        #expect(section.constraints == [.text("Self is Foo")])
    }

    @Test func roundTrips() throws {
        try roundTrip(ConformanceSection.self, """
        {
          "availabilityPrefix": [{ "type": "text", "text": "Present when" }],
          "conformancePrefix": [{ "type": "text", "text": "Matches when" }],
          "constraints": [{ "type": "text", "text": "Self is Foo" }]
        }
        """)
    }

    @Test func missingConstraintsThrows() throws {
        #expect(throws: (any Error).self) {
            try decode(ConformanceSection.self, "{}")
        }
    }
}
