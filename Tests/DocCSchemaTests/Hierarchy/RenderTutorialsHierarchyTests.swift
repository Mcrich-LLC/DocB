// Covers RenderTutorialsHierarchy: the root node of a tutorials series hierarchy.

import Testing
@testable import DocCSchema

@Suite struct RenderTutorialsHierarchyTests {
    @Test func decodesMinimal() throws {
        let json = """
        {
            "reference": "doc://com.example/tutorials/ExampleKit",
            "paths": [[]]
        }
        """
        let value = try decode(RenderTutorialsHierarchy.self, json)
        #expect(value.reference.identifier == "doc://com.example/tutorials/ExampleKit")
        #expect(value.paths == [[]])
        #expect(value.modules == nil)
    }

    @Test func decodesFullPayload() throws {
        let json = """
        {
            "reference": "doc://com.example/tutorials/ExampleKit",
            "paths": [[]],
            "modules": [
                {
                    "reference": "doc://com.example/tutorials/ExampleKit/Chapter",
                    "projects": []
                }
            ]
        }
        """
        let value = try decode(RenderTutorialsHierarchy.self, json)
        #expect(value.modules?.count == 1)
    }

    @Test func roundTrips() throws {
        let json = """
        {
            "reference": "doc://com.example/tutorials/ExampleKit",
            "paths": [["doc://com.example/tutorials/ExampleKit"]],
            "modules": [
                {"reference": "doc://com.example/tutorials/ExampleKit/Chapter", "projects": []}
            ]
        }
        """
        try roundTrip(RenderTutorialsHierarchy.self, json)
    }

    @Test func missingReferenceThrows() {
        let json = """
        {"paths": [[]]}
        """
        #expect(throws: (any Error).self) {
            try decode(RenderTutorialsHierarchy.self, json)
        }
    }
}
