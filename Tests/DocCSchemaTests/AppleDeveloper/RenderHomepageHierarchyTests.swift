// Shape tests for RenderHomepageHierarchy: the ordered top-level navigation list used by the
// developer.apple.com homepage and technologies catalog, in place of upstream's path hierarchies.

import Testing
@testable import DocCSchema

@Suite struct RenderHomepageHierarchyTests {
    @Test func decodesMinimalPayload() throws {
        let json = """
        { "homepageNavigation": [{ "reference": "doc://com.example/documentation/examplekit" }] }
        """
        let hierarchy = try decode(RenderHomepageHierarchy.self, json)
        #expect(hierarchy.homepageNavigation.count == 1)
        #expect(hierarchy.homepageNavigation[0].reference.identifier == "doc://com.example/documentation/examplekit")
    }

    @Test func decodesMultipleEntriesInOrder() throws {
        let json = """
        {
            "homepageNavigation": [
                { "reference": "doc://com.example/documentation/examplekit" },
                { "reference": "doc://com.example/documentation/exampletools" }
            ]
        }
        """
        let hierarchy = try decode(RenderHomepageHierarchy.self, json)
        #expect(hierarchy.homepageNavigation.map(\.reference.identifier) == [
            "doc://com.example/documentation/examplekit",
            "doc://com.example/documentation/exampletools",
        ])
    }

    @Test func roundTrips() throws {
        let json = """
        {
            "homepageNavigation": [
                { "reference": "doc://com.example/documentation/examplekit" },
                { "reference": "doc://com.example/documentation/exampletools" }
            ]
        }
        """
        try roundTrip(RenderHomepageHierarchy.self, json)
    }

    @Test func missingHomepageNavigationThrows() throws {
        let json = "{}"
        #expect(throws: (any Error).self) {
            try decode(RenderHomepageHierarchy.self, json)
        }
    }
}
