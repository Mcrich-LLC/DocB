// Covers RenderHierarchy: the enum that discriminates between an API reference hierarchy, a
// tutorials hierarchy, and (AppleDeveloper extension) a homepage hierarchy, purely by trying each
// shape's Decodable initializer in turn, falling back to `.unknown` when none of them match.

import Testing
@testable import DocCSchema

@Suite struct RenderHierarchyTests {
    @Test func decodesReference() throws {
        let json = """
        {"paths": [["doc://com.example/documentation/ExampleKit"]]}
        """
        let value = try decode(RenderHierarchy.self, json)
        guard case .reference(let hierarchy) = value else {
            Issue.record("expected .reference")
            return
        }
        #expect(hierarchy.paths == [["doc://com.example/documentation/ExampleKit"]])
    }

    @Test func decodesTutorials() throws {
        let json = """
        {
            "reference": "doc://com.example/tutorials/ExampleKit",
            "paths": [[]]
        }
        """
        let value = try decode(RenderHierarchy.self, json)
        guard case .tutorials(let hierarchy) = value else {
            Issue.record("expected .tutorials")
            return
        }
        #expect(hierarchy.reference.identifier == "doc://com.example/tutorials/ExampleKit")
    }

    @Test func decodesHomepage() throws {
        let json = """
        {
            "homepageNavigation": [
                {"reference": "doc://com.example/documentation/ExampleKit"}
            ]
        }
        """
        let value = try decode(RenderHierarchy.self, json)
        guard case .homepage(let hierarchy) = value else {
            Issue.record("expected .homepage")
            return
        }
        #expect(hierarchy.homepageNavigation.count == 1)
        #expect(hierarchy.homepageNavigation[0].reference.identifier == "doc://com.example/documentation/ExampleKit")
    }

    @Test func roundTripsReference() throws {
        let json = """
        {"paths": [["doc://com.example/documentation/ExampleKit"]]}
        """
        try roundTrip(RenderHierarchy.self, json)
    }

    @Test func roundTripsTutorials() throws {
        let json = """
        {
            "reference": "doc://com.example/tutorials/ExampleKit",
            "paths": [[]]
        }
        """
        try roundTrip(RenderHierarchy.self, json)
    }

    @Test func roundTripsHomepage() throws {
        let json = """
        {
            "homepageNavigation": [
                {"reference": "doc://com.example/documentation/ExampleKit"}
            ]
        }
        """
        try roundTrip(RenderHierarchy.self, json)
    }

    @Test func neitherShapeIsPreserved() throws {
        let json = """
        {"bogus": "value"}
        """
        let value = try roundTrip(RenderHierarchy.self, json)
        guard case .unknown(let payload) = value, case .dictionary(let object) = payload else {
            Issue.record("Expected .unknown")
            return
        }
        #expect(object["bogus"] == .string("value"))
    }
}
