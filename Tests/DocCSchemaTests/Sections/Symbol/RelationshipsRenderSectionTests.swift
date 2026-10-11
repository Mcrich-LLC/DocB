// Shape tests for RelationshipsRenderSection: a titled list of related-symbol identifiers
// under a relationship type, including dispatch through RenderNode.primaryContentSections.

import Testing
@testable import DocCSchema

@Suite struct RelationshipsRenderSectionTests {
    static let minimalJSON = """
    {
      "kind": "relationships",
      "type": "conformsTo",
      "title": "Conforms To",
      "identifiers": ["doc://com.example/documentation/examplekit/equatable"]
    }
    """

    @Test func decodesPayload() throws {
        let section = try decode(RelationshipsRenderSection.self, Self.minimalJSON)
        #expect(section.kind == .relationships)
        #expect(section.type == "conformsTo")
        #expect(section.title == "Conforms To")
        #expect(section.identifiers == ["doc://com.example/documentation/examplekit/equatable"])
    }

    @Test func roundTrips() throws {
        try roundTrip(RelationshipsRenderSection.self, Self.minimalJSON)
    }

    @Test func dispatchesThroughRenderNodePrimaryContentSections() throws {
        let node = try decode(RenderNode.self, renderNodeJSON(primaryContentSection: Self.minimalJSON))
        let section = try #require(node.primaryContentSections.first as? RelationshipsRenderSection)
        #expect(section.kind == .relationships)
        #expect(section.identifiers.count == 1)
    }

    @Test func missingRequiredKeyThrows() throws {
        #expect(throws: (any Error).self) {
            try decode(RelationshipsRenderSection.self, "{ \"kind\": \"relationships\", \"type\": \"conformsTo\" }")
        }
    }
}
