// Shape tests for ParametersRenderSection: the "parameters" render section grouping named
// ParameterRenderSection values, including dispatch through RenderNode.primaryContentSections.

import Testing
@testable import DocCSchema

@Suite struct ParametersRenderSectionTests {
    static let minimalJSON = """
    {
      "kind": "parameters",
      "parameters": [{ "name": "value", "content": [] }]
    }
    """

    @Test func decodesMinimalPayload() throws {
        let section = try decode(ParametersRenderSection.self, Self.minimalJSON)
        #expect(section.kind == .parameters)
        #expect(section.parameters.count == 1)
        #expect(section.parameters[0].name == "value")
    }

    @Test func roundTrips() throws {
        try roundTrip(ParametersRenderSection.self, Self.minimalJSON)
    }

    @Test func dispatchesThroughRenderNodePrimaryContentSections() throws {
        let node = try decode(RenderNode.self, renderNodeJSON(primaryContentSection: Self.minimalJSON))
        let parameters = try #require(node.primaryContentSections.first as? ParametersRenderSection)
        #expect(parameters.kind == .parameters)
        #expect(parameters.parameters.count == 1)
    }

    @Test func missingParametersThrows() throws {
        #expect(throws: (any Error).self) {
            try decode(ParametersRenderSection.self, "{ \"kind\": \"parameters\" }")
        }
    }
}
