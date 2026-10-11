// Shape tests for CodeExample: an optional type/syntax pair plus a required list of
// (collapsible, lines) code chunks.

import Testing
@testable import DocCSchema

@Suite struct CodeExampleTests {
    @Test func decodesMinimalPayload() throws {
        let json = """
        {
          "content": [
            { "collapsible": false, "code": ["let x = 1"] }
          ]
        }
        """
        let example = try decode(CodeExample.self, json)
        #expect(example.type == nil)
        #expect(example.syntax == nil)
        #expect(example.content.count == 1)
        #expect(example.content[0].collapsible == false)
        #expect(example.content[0].code == ["let x = 1"])
    }

    @Test func decodesFullPayload() throws {
        let json = """
        {
          "type": "request",
          "syntax": "json",
          "content": [
            { "collapsible": true, "code": ["{", "  \\"key\\": 1", "}"] }
          ]
        }
        """
        let example = try decode(CodeExample.self, json)
        #expect(example.type == "request")
        #expect(example.syntax == "json")
        #expect(example.content[0].collapsible == true)
        #expect(example.content[0].code.count == 3)
    }

    @Test func roundTrips() throws {
        try roundTrip(CodeExample.self, """
        {
          "type": "request",
          "syntax": "json",
          "content": [
            { "collapsible": false, "code": ["line one", "line two"] }
          ]
        }
        """)
    }

    @Test func missingContentThrows() throws {
        #expect(throws: (any Error).self) {
            try decode(CodeExample.self, "{ \"type\": \"request\" }")
        }
    }
}
