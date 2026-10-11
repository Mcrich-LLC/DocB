// Covers RenderHierarchyLandmark and its Kind enum: a landmark tree node for a task, assessment,
// or heading on a tutorial page.

import Testing
@testable import DocCSchema

@Suite struct RenderHierarchyLandmarkTests {
    @Test func decodesTaskLandmark() throws {
        let json = """
        {"reference": "doc://com.example/tutorials/ExampleKit/Thing#task", "kind": "task"}
        """
        let value = try decode(RenderHierarchyLandmark.self, json)
        #expect(value.reference.identifier == "doc://com.example/tutorials/ExampleKit/Thing#task")
        #expect(value.kind == .task)
    }

    @Test func kindRawValuesMatchWireFormat() throws {
        #expect(RenderHierarchyLandmark.Kind.task.rawValue == "task")
        #expect(RenderHierarchyLandmark.Kind.assessment.rawValue == "assessment")
        #expect(RenderHierarchyLandmark.Kind.heading.rawValue == "heading")
    }

    @Test func roundTrips() throws {
        let json = """
        {"reference": "doc://com.example/tutorials/ExampleKit/Thing#heading", "kind": "heading"}
        """
        try roundTrip(RenderHierarchyLandmark.self, json)
    }

    @Test func unknownKindIsPreserved() throws {
        let json = """
        {"reference": "doc://com.example/tutorials/ExampleKit/Thing", "kind": "bogus"}
        """
        let value = try roundTrip(RenderHierarchyLandmark.self, json)
        #expect(value.kind == .unknown("bogus"))
    }

    @Test func missingKindThrows() {
        let json = """
        {"reference": "doc://com.example/tutorials/ExampleKit/Thing"}
        """
        #expect(throws: (any Error).self) {
            try decode(RenderHierarchyLandmark.self, json)
        }
    }
}
