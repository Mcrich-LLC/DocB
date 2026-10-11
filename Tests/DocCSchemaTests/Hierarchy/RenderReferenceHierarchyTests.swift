// Covers RenderReferenceHierarchy: the set of breadcrumb paths from a framework landing page to
// an API reference symbol.

import Testing
@testable import DocCSchema

@Suite struct RenderReferenceHierarchyTests {
    @Test func decodesSinglePath() throws {
        let json = """
        {"paths": [["doc://com.example/documentation/ExampleKit", "doc://com.example/documentation/ExampleKit/Thing"]]}
        """
        let value = try decode(RenderReferenceHierarchy.self, json)
        #expect(value.paths.count == 1)
        #expect(value.paths[0].count == 2)
    }

    @Test func decodesMultiplePaths() throws {
        let json = """
        {
            "paths": [
                ["doc://com.example/documentation/ExampleKit", "doc://com.example/documentation/ExampleKit/Thing"],
                ["doc://com.example/documentation/ExampleKit", "doc://com.example/documentation/ExampleKit/Article", "doc://com.example/documentation/ExampleKit/Thing"]
            ]
        }
        """
        let value = try decode(RenderReferenceHierarchy.self, json)
        #expect(value.paths.count == 2)
    }

    @Test func decodesLandingPageEmptyPath() throws {
        let json = """
        {"paths": [[]]}
        """
        let value = try decode(RenderReferenceHierarchy.self, json)
        #expect(value.paths == [[]])
    }

    @Test func roundTrips() throws {
        let json = """
        {"paths": [["doc://com.example/documentation/ExampleKit"]]}
        """
        try roundTrip(RenderReferenceHierarchy.self, json)
    }

    @Test func missingPathsThrows() {
        let json = "{}"
        #expect(throws: (any Error).self) {
            try decode(RenderReferenceHierarchy.self, json)
        }
    }
}
