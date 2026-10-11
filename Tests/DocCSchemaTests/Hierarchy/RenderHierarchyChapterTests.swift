// Covers RenderHierarchyChapter: a chapter node in a tutorial series hierarchy, including its
// "tutorials"/"projects" legacy key aliasing.

import Testing
@testable import DocCSchema

@Suite struct RenderHierarchyChapterTests {
    @Test func decodesWithCurrentKey() throws {
        let json = """
        {
            "reference": "doc://com.example/tutorials/ExampleKit/Chapter",
            "tutorials": [
                {"reference": "doc://com.example/tutorials/ExampleKit/Thing", "sections": []}
            ]
        }
        """
        let value = try decode(RenderHierarchyChapter.self, json)
        #expect(value.reference.identifier == "doc://com.example/tutorials/ExampleKit/Chapter")
        #expect(value.tutorials.count == 1)
    }

    @Test func decodesWithLegacyKey() throws {
        let json = """
        {
            "reference": "doc://com.example/tutorials/ExampleKit/Chapter",
            "projects": [
                {"reference": "doc://com.example/tutorials/ExampleKit/Thing", "sections": []}
            ]
        }
        """
        let value = try decode(RenderHierarchyChapter.self, json)
        #expect(value.tutorials.count == 1)
    }

    @Test func roundTripsWithLegacyKey() throws {
        // The encoder always writes the legacy "projects" key, so this is a normal round trip.
        let json = """
        {
            "reference": "doc://com.example/tutorials/ExampleKit/Chapter",
            "projects": []
        }
        """
        try roundTrip(RenderHierarchyChapter.self, json)
    }

    @Test func roundTripsWithCurrentKeyOmittingIt() throws {
        // "tutorials" is only ever a decode-time alias for "projects" -- the encoder never
        // emits it, so it must be omitted from the round-trip subset check.
        let json = """
        {
            "reference": "doc://com.example/tutorials/ExampleKit/Chapter",
            "tutorials": []
        }
        """
        try roundTrip(RenderHierarchyChapter.self, json, omitting: ["tutorials"])
    }

    @Test func missingTutorialsAndProjectsThrows() {
        let json = """
        {"reference": "doc://com.example/tutorials/ExampleKit/Chapter"}
        """
        #expect(throws: (any Error).self) {
            try decode(RenderHierarchyChapter.self, json)
        }
    }
}
