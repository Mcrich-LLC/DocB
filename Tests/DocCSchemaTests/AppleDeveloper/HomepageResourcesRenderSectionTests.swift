// Shape tests for HomepageResourcesRenderSection: the `homepageResources`-kind strip of
// resource tiles at the bottom of the developer.apple.com homepage.

import Testing
@testable import DocCSchema

@Suite struct HomepageResourcesRenderSectionTests {
    @Test func decodesMinimalPayload() throws {
        let json = """
        {
            "kind": "homepageResources",
            "resources": [
                {
                    "title": "Downloads",
                    "destination": { "type": "text", "text": "doc://com.example/documentation/examplekit/downloads" },
                    "content": []
                }
            ]
        }
        """
        let section = try decode(HomepageResourcesRenderSection.self, json)
        #expect(section.kind == .homepageResources)
        #expect(section.resources.count == 1)
        #expect(section.resources[0].title == "Downloads")
        #expect(section.resources[0].image == nil)
        #expect(section.resources[0].content == [])
    }

    @Test func decodesFullPayloadWithEveryOptionalKey() throws {
        let json = """
        {
            "kind": "homepageResources",
            "resources": [
                {
                    "title": "Downloads",
                    "image": "https://example.com/downloads.png",
                    "destination": { "type": "text", "text": "doc://com.example/documentation/examplekit/downloads" },
                    "content": [{ "type": "text", "text": "Get the latest tools." }]
                }
            ]
        }
        """
        let section = try decode(HomepageResourcesRenderSection.self, json)
        let resource = section.resources[0]
        #expect(resource.image?.identifier == "https://example.com/downloads.png")
        #expect(resource.content.count == 1)
    }

    @Test func roundTrips() throws {
        let json = """
        {
            "kind": "homepageResources",
            "resources": [
                {
                    "title": "Downloads",
                    "image": "https://example.com/downloads.png",
                    "destination": { "type": "text", "text": "doc://com.example/documentation/examplekit/downloads" },
                    "content": [{ "type": "text", "text": "Get the latest tools." }]
                }
            ]
        }
        """
        try roundTrip(HomepageResourcesRenderSection.self, json)
    }

    @Test func missingResourcesThrows() throws {
        let json = """
        { "kind": "homepageResources" }
        """
        #expect(throws: (any Error).self) {
            try decode(HomepageResourcesRenderSection.self, json)
        }
    }
}
