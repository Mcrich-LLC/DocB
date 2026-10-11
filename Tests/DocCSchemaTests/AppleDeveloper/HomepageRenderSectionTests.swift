// Shape tests for HomepageRenderSection: the `section`-kind homepage section, its two `Body`
// layouts (`cards` and `highlightedLinks`), and the null-tolerant `content` decode.

import Testing
@testable import DocCSchema

@Suite struct HomepageRenderSectionTests {
    @Test func decodesMinimalCardsPayload() throws {
        let json = """
        {
            "kind": "section",
            "body": {
                "kind": "cards",
                "cards": [
                    {
                        "isFeatured": false,
                        "cards": [
                            {
                                "title": "Example Kit",
                                "destination": { "type": "text", "text": "doc://com.example/documentation/examplekit" },
                                "content": []
                            }
                        ]
                    }
                ]
            }
        }
        """
        let section = try decode(HomepageRenderSection.self, json)
        #expect(section.kind == .section)
        #expect(section.title == nil)
        #expect(section.content == [])
        guard case .cards(let groups) = section.body else {
            Issue.record("Expected a cards body")
            return
        }
        #expect(groups.count == 1)
        #expect(groups[0].isFeatured == false)
        #expect(groups[0].cards.count == 1)
        #expect(groups[0].cards[0].title == "Example Kit")
        #expect(groups[0].cards[0].eyebrow == nil)
        #expect(groups[0].cards[0].content == [])
    }

    @Test func decodesFullCardsPayloadWithEveryOptionalKey() throws {
        let json = """
        {
            "kind": "section",
            "title": "Featured",
            "content": [
                { "type": "paragraph", "inlineContent": [{ "type": "text", "text": "Example intro." }] }
            ],
            "body": {
                "kind": "cards",
                "cards": [
                    {
                        "isFeatured": true,
                        "cards": [
                            {
                                "eyebrow": "New",
                                "title": "Example Kit",
                                "image": "examplekit-card.png",
                                "destination": { "type": "text", "text": "doc://com.example/documentation/examplekit" },
                                "content": [{ "type": "text", "text": "Build things with Example Kit." }],
                                "callToAction": { "ide": "Open in Xcode", "web": "View on the web" },
                                "callToActionText": { "ide": "Open", "web": "View" }
                            }
                        ]
                    }
                ]
            }
        }
        """
        let section = try decode(HomepageRenderSection.self, json)
        #expect(section.title == "Featured")
        #expect(section.content.count == 1)
        guard case .cards(let groups) = section.body else {
            Issue.record("Expected a cards body")
            return
        }
        let card = groups[0].cards[0]
        #expect(groups[0].isFeatured == true)
        #expect(card.eyebrow == "New")
        #expect(card.image?.identifier == "examplekit-card.png")
        #expect(card.content.count == 1)
        #expect(card.callToAction?.ide == "Open in Xcode")
        #expect(card.callToAction?.web == "View on the web")
        #expect(card.callToActionText?.ide == "Open")
        #expect(card.callToActionText?.web == "View")
    }

    @Test func decodesHighlightedLinksBody() throws {
        let json = """
        {
            "kind": "section",
            "body": {
                "kind": "highlightedLinks",
                "image": "https://example.com/hero.png",
                "highlightedLinks": [
                    {
                        "title": "Get started",
                        "content": [{ "type": "text", "text": "Learn the basics." }],
                        "callToActionText": "Start",
                        "destination": "doc://com.example/documentation/examplekit/getting-started"
                    }
                ]
            }
        }
        """
        let section = try decode(HomepageRenderSection.self, json)
        guard case .highlightedLinks(let image, let links) = section.body else {
            Issue.record("Expected a highlightedLinks body")
            return
        }
        #expect(image?.identifier == "https://example.com/hero.png")
        #expect(links.count == 1)
        #expect(links[0].title == "Get started")
        #expect(links[0].callToActionText == "Start")
        #expect(links[0].destination == "doc://com.example/documentation/examplekit/getting-started")
    }

    @Test func nullContentDecodesToEmptyArray() throws {
        let json = """
        {
            "kind": "section",
            "content": null,
            "body": { "kind": "cards", "cards": [] }
        }
        """
        let section = try decode(HomepageRenderSection.self, json)
        #expect(section.content == [])
    }

    @Test func roundTrips() throws {
        let json = """
        {
            "kind": "section",
            "title": "Featured",
            "content": [
                { "type": "paragraph", "inlineContent": [{ "type": "text", "text": "Example intro." }] }
            ],
            "body": {
                "kind": "cards",
                "cards": [
                    {
                        "isFeatured": true,
                        "cards": [
                            {
                                "eyebrow": "New",
                                "title": "Example Kit",
                                "image": "examplekit-card.png",
                                "destination": { "type": "text", "text": "doc://com.example/documentation/examplekit" },
                                "content": [{ "type": "text", "text": "Build things with Example Kit." }],
                                "callToAction": { "ide": "Open in Xcode", "web": "View on the web" },
                                "callToActionText": { "ide": "Open", "web": "View" }
                            }
                        ]
                    }
                ]
            }
        }
        """
        try roundTrip(HomepageRenderSection.self, json)
    }

    @Test func missingBodyThrows() throws {
        let json = """
        { "kind": "section" }
        """
        #expect(throws: (any Error).self) {
            try decode(HomepageRenderSection.self, json)
        }
    }

    @Test func unknownBodyKindIsPreserved() throws {
        let json = """
        {
            "kind": "section",
            "body": { "kind": "unknownLayout" }
        }
        """
        let value = try roundTrip(HomepageRenderSection.self, json)
        guard case .unknown(let payload) = value.body, case .dictionary(let object) = payload else {
            Issue.record("Expected .unknown body")
            return
        }
        #expect(object["kind"] == .string("unknownLayout"))
    }
}
