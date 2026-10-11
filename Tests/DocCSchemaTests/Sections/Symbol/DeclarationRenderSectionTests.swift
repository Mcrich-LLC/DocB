// Shape tests for DeclarationRenderSection and its nested Token / OtherDeclarations /
// OtherDeclarations.Declaration types: a tokenized symbol declaration plus optional
// overload declarations.

import Testing
@testable import DocCSchema

@Suite struct DeclarationRenderSectionTests {
    @Test func decodesMinimalPayload() throws {
        let json = """
        {
          "platforms": ["exampleOS"],
          "tokens": [{ "kind": "keyword", "text": "func" }]
        }
        """
        let section = try decode(DeclarationRenderSection.self, json)
        #expect(section.platforms.count == 1)
        #expect(section.platforms[0]?.rawValue == "exampleOS")
        #expect(section.tokens == [.init(text: "func", kind: .keyword)])
        #expect(section.languages == nil)
        #expect(section.otherDeclarations == nil)
    }

    @Test func decodesFullPayload() throws {
        let json = """
        {
          "platforms": ["exampleOS", null],
          "languages": ["swift"],
          "tokens": [
            { "kind": "keyword", "text": "func" },
            { "kind": "identifier", "text": "example", "identifier": "doc://com.example/documentation/examplekit/thing", "preciseIdentifier": "s:1", "highlight": "changed" }
          ],
          "otherDeclarations": {
            "declarations": [
              {
                "tokens": [{ "kind": "identifier", "text": "exampleOverload" }],
                "identifier": "doc://com.example/documentation/examplekit/overload",
                "conformance": {
                  "availabilityPrefix": [{ "type": "text", "text": "Available when" }],
                  "conformancePrefix": [{ "type": "text", "text": "Conforms when" }],
                  "constraints": [{ "type": "text", "text": "Element conforms to Equatable" }]
                }
              }
            ],
            "displayIndex": 0
          }
        }
        """
        let section = try decode(DeclarationRenderSection.self, json)
        #expect(section.platforms == [PlatformName(rawValue: "exampleOS"), nil])
        #expect(section.languages == ["swift"])
        #expect(section.tokens.count == 2)
        #expect(section.tokens[1].identifier == "doc://com.example/documentation/examplekit/thing")
        #expect(section.tokens[1].preciseIdentifier == "s:1")
        #expect(section.tokens[1].highlight == .changed)
        #expect(section.otherDeclarations?.declarations.count == 1)
        #expect(section.otherDeclarations?.displayIndex == 0)
        #expect(section.otherDeclarations?.declarations[0].identifier == "doc://com.example/documentation/examplekit/overload")
        #expect(section.otherDeclarations?.declarations[0].conformance != nil)
    }

    @Test func roundTrips() throws {
        try roundTrip(DeclarationRenderSection.self, """
        {
          "platforms": ["exampleOS"],
          "languages": ["swift"],
          "tokens": [{ "kind": "keyword", "text": "func" }],
          "otherDeclarations": {
            "declarations": [
              {
                "tokens": [{ "kind": "identifier", "text": "exampleOverload" }],
                "identifier": "doc://com.example/documentation/examplekit/overload"
              }
            ],
            "displayIndex": 0
          }
        }
        """)
    }

    @Test func missingRequiredKeyThrows() throws {
        #expect(throws: (any Error).self) {
            try decode(DeclarationRenderSection.self, "{ \"platforms\": [] }")
        }
    }
}
