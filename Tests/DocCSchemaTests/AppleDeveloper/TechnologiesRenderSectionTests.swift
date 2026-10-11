// Shape tests for TechnologiesRenderSection: the `technologies`-kind grouped catalog listing on
// developer.apple.com, the discovery payload a multi-archive source is built from.

import Testing
@testable import DocCSchema

@Suite struct TechnologiesRenderSectionTests {
    @Test func decodesMinimalPayload() throws {
        let json = """
        {
            "kind": "technologies",
            "groups": [
                {
                    "name": "Frameworks",
                    "technologies": [
                        {
                            "title": "Example Kit",
                            "content": [],
                            "destination": { "type": "text", "text": "doc://com.example/documentation/examplekit" },
                            "languages": ["swift"],
                            "tags": ["Featured"]
                        }
                    ]
                }
            ]
        }
        """
        let section = try decode(TechnologiesRenderSection.self, json)
        #expect(section.kind == .technologies)
        #expect(section.groups.count == 1)
        #expect(section.groups[0].name == "Frameworks")
        let technology = section.groups[0].technologies[0]
        #expect(technology.title == "Example Kit")
        #expect(technology.content == [])
        #expect(technology.languages == ["swift"])
        #expect(technology.tags == ["Featured"])
    }

    @Test func decodesFullPayloadWithEveryOptionalKey() throws {
        let json = """
        {
            "kind": "technologies",
            "groups": [
                {
                    "name": "Frameworks",
                    "technologies": [
                        {
                            "title": "Example Kit",
                            "content": [{ "type": "text", "text": "Build things with Example Kit." }],
                            "destination": { "type": "text", "text": "doc://com.example/documentation/examplekit" },
                            "languages": ["swift", "occ"],
                            "tags": ["Featured", "New"]
                        }
                    ]
                }
            ]
        }
        """
        let section = try decode(TechnologiesRenderSection.self, json)
        let technology = section.groups[0].technologies[0]
        #expect(technology.content.count == 1)
        #expect(technology.languages == ["swift", "occ"])
        #expect(technology.tags == ["Featured", "New"])
    }

    @Test func roundTrips() throws {
        let json = """
        {
            "kind": "technologies",
            "groups": [
                {
                    "name": "Frameworks",
                    "technologies": [
                        {
                            "title": "Example Kit",
                            "content": [{ "type": "text", "text": "Build things with Example Kit." }],
                            "destination": { "type": "text", "text": "doc://com.example/documentation/examplekit" },
                            "languages": ["swift", "occ"],
                            "tags": ["Featured", "New"]
                        }
                    ]
                }
            ]
        }
        """
        try roundTrip(TechnologiesRenderSection.self, json)
    }

    @Test func missingGroupsThrows() throws {
        let json = """
        { "kind": "technologies" }
        """
        #expect(throws: (any Error).self) {
            try decode(TechnologiesRenderSection.self, json)
        }
    }
}
