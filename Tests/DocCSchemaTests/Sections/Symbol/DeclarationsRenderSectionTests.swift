// Shape tests for DeclarationsRenderSection: the compound "declarations" render section
// that groups per-platform DeclarationRenderSection values, including dispatch through
// RenderNode.primaryContentSections via its "declarations" kind.

import Testing
@testable import DocCSchema

@Suite struct DeclarationsRenderSectionTests {
    static let minimalJSON = """
    {
      "kind": "declarations",
      "declarations": [
        {
          "platforms": ["exampleOS"],
          "tokens": [{ "kind": "keyword", "text": "func" }]
        }
      ]
    }
    """

    @Test func decodesMinimalPayload() throws {
        let section = try decode(DeclarationsRenderSection.self, Self.minimalJSON)
        #expect(section.kind == .declarations)
        #expect(section.declarations.count == 1)
        #expect(section.declarations[0].platforms[0]?.rawValue == "exampleOS")
    }

    @Test func roundTrips() throws {
        try roundTrip(DeclarationsRenderSection.self, Self.minimalJSON)
    }

    @Test func dispatchesThroughRenderNodePrimaryContentSections() throws {
        let node = try decode(RenderNode.self, renderNodeJSON(primaryContentSection: Self.minimalJSON))
        let sections = node.primaryContentSections
        #expect(sections.count == 1)
        let declarations = try #require(sections[0] as? DeclarationsRenderSection)
        #expect(declarations.kind == .declarations)
        #expect(declarations.declarations.count == 1)
    }

    @Test func missingRequiredKeyThrows() throws {
        #expect(throws: (any Error).self) {
            try decode(DeclarationsRenderSection.self, "{ \"kind\": \"declarations\" }")
        }
    }
}
