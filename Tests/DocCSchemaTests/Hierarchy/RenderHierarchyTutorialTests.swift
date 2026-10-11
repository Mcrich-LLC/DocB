// Covers RenderHierarchyTutorial: a hierarchy tree node for a tutorial or tutorial article,
// whose `landmarks` property is coded under the wire key "sections".

import Testing
@testable import DocCSchema

@Suite struct RenderHierarchyTutorialTests {
    @Test func decodesMinimal() throws {
        // Fully-synthesized Codable via the manually-declared CodingKeys: "sections" is required
        // despite `landmarks` having a default value, since a missing key throws rather than
        // falling back for non-Optional properties.
        let json = """
        {"reference": "doc://com.example/tutorials/ExampleKit/Thing", "sections": []}
        """
        let value = try decode(RenderHierarchyTutorial.self, json)
        #expect(value.reference.identifier == "doc://com.example/tutorials/ExampleKit/Thing")
        #expect(value.landmarks.isEmpty)
    }

    @Test func decodesFullPayload() throws {
        let json = """
        {
            "reference": "doc://com.example/tutorials/ExampleKit/Thing",
            "sections": [
                {"reference": "doc://com.example/tutorials/ExampleKit/Thing#task", "kind": "task"}
            ]
        }
        """
        let value = try decode(RenderHierarchyTutorial.self, json)
        #expect(value.landmarks.count == 1)
        #expect(value.landmarks[0].kind == .task)
    }

    @Test func roundTrips() throws {
        let json = """
        {
            "reference": "doc://com.example/tutorials/ExampleKit/Thing",
            "sections": [
                {"reference": "doc://com.example/tutorials/ExampleKit/Thing#task", "kind": "task"}
            ]
        }
        """
        try roundTrip(RenderHierarchyTutorial.self, json)
    }

    @Test func missingSectionsThrows() {
        let json = """
        {"reference": "doc://com.example/tutorials/ExampleKit/Thing"}
        """
        #expect(throws: (any Error).self) {
            try decode(RenderHierarchyTutorial.self, json)
        }
    }
}
