// Shape tests for PropertyListDetailsRenderSection and its nested Details: property list
// key details, including the "details" discriminator string for its .plistDetails kind and
// dispatch through RenderNode.primaryContentSections.
//
// Note: `title`'s `= "Details"` is a Swift-construction default only; the property is
// non-Optional, so synthesized Decodable still requires the key on decode.

import Testing
@testable import DocCSchema

@Suite struct PropertyListDetailsRenderSectionTests {
    static let minimalJSON = """
    {
      "kind": "details",
      "title": "Details",
      "details": {
        "name": "com.example.exampleKey",
        "value": [{ "baseType": "String", "arrayMode": false }],
        "platforms": ["exampleOS"],
        "titleStyle": "symbol"
      }
    }
    """

    @Test func decodesMinimalPayload() throws {
        let section = try decode(PropertyListDetailsRenderSection.self, Self.minimalJSON)
        #expect(section.kind == .plistDetails)
        #expect(section.kind.rawValue == "details")
        #expect(section.title == "Details")
        #expect(section.details.rawKey == "com.example.exampleKey")
        #expect(section.details.value.count == 1)
        #expect(section.details.platforms == ["exampleOS"])
        #expect(section.details.displayName == nil)
        #expect(section.details.titleStyle == .useRawKey)
    }

    @Test func decodesFullPayload() throws {
        let json = """
        {
          "kind": "details",
          "title": "Key Details",
          "details": {
            "name": "com.example.exampleKey",
            "value": [{ "baseType": "String", "arrayMode": false }],
            "platforms": ["exampleOS"],
            "ideTitle": "Example Key",
            "titleStyle": "title"
          }
        }
        """
        let section = try decode(PropertyListDetailsRenderSection.self, json)
        #expect(section.title == "Key Details")
        #expect(section.details.displayName == "Example Key")
        #expect(section.details.titleStyle == .useDisplayName)
    }

    @Test func roundTrips() throws {
        try roundTrip(PropertyListDetailsRenderSection.self, Self.minimalJSON)
    }

    @Test func dispatchesThroughRenderNodePrimaryContentSections() throws {
        let node = try decode(RenderNode.self, renderNodeJSON(primaryContentSection: Self.minimalJSON))
        let section = try #require(node.primaryContentSections.first as? PropertyListDetailsRenderSection)
        #expect(section.kind == .plistDetails)
        #expect(section.details.rawKey == "com.example.exampleKey")
    }

    @Test func missingDetailsThrows() throws {
        #expect(throws: (any Error).self) {
            try decode(PropertyListDetailsRenderSection.self, "{ \"kind\": \"details\" }")
        }
    }
}
