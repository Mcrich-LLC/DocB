// Integration shape tests for the AppleDeveloper hooks into types that live outside this folder:
// RenderNode.Kind's `root`/`technologies` cases, RenderNode.legalNotices, and RenderHierarchy's
// `.homepage` case. Each per-type file in this folder covers its own type in isolation; these
// tests exercise them wired together the way a real developer.apple.com payload does.

import Testing
@testable import DocCSchema

@Suite struct RenderNodeAppleDeveloperTests {
    @Test func decodesRootNodeWithHomepageSections() throws {
        let json = """
        {
            "schemaVersion": { "major": 0, "minor": 3, "patch": 0 },
            "identifier": { "url": "doc://com.example/documentation/examplekit", "interfaceLanguage": "swift" },
            "kind": "root",
            "metadata": {},
            "hierarchy": { "homepageNavigation": [{ "reference": "doc://com.example/documentation/examplekit" }] },
            "sections": [
                { "kind": "hero", "title": "Example Kit" },
                {
                    "kind": "section",
                    "body": {
                        "kind": "cards",
                        "cards": [
                            {
                                "isFeatured": true,
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
                },
                {
                    "kind": "section",
                    "body": {
                        "kind": "highlightedLinks",
                        "highlightedLinks": [
                            {
                                "title": "Get started",
                                "content": [],
                                "destination": "doc://com.example/documentation/examplekit/getting-started"
                            }
                        ]
                    }
                },
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
            ]
        }
        """
        let node = try decode(RenderNode.self, json)
        #expect(node.kind == .root)
        #expect(node.sections.count == 4)

        #expect(node.sections[0] is IntroRenderSection)
        guard let heroSection = node.sections[0] as? IntroRenderSection else {
            Issue.record("Expected an IntroRenderSection")
            return
        }
        #expect(heroSection.title == "Example Kit")

        guard let cardsSection = node.sections[1] as? HomepageRenderSection,
              case .cards(let groups) = cardsSection.body else {
            Issue.record("Expected a cards HomepageRenderSection")
            return
        }
        #expect(groups[0].isFeatured == true)

        guard let linksSection = node.sections[2] as? HomepageRenderSection,
              case .highlightedLinks(_, let links) = linksSection.body else {
            Issue.record("Expected a highlightedLinks HomepageRenderSection")
            return
        }
        #expect(links[0].title == "Get started")

        guard let resourcesSection = node.sections[3] as? HomepageResourcesRenderSection else {
            Issue.record("Expected a HomepageResourcesRenderSection")
            return
        }
        #expect(resourcesSection.resources[0].title == "Downloads")
    }

    @Test func decodesTechnologiesNodeWithDefaultSuggestedTags() throws {
        let json = """
        {
            "schemaVersion": { "major": 0, "minor": 3, "patch": 0 },
            "identifier": { "url": "doc://com.example/documentation/technologies", "interfaceLanguage": "swift" },
            "kind": "technologies",
            "metadata": { "defaultSuggestedTags": ["Featured", "New"] },
            "sections": [
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
            ]
        }
        """
        let node = try decode(RenderNode.self, json)
        #expect(node.kind == .technologies)
        #expect(node.metadata.defaultSuggestedTags == ["Featured", "New"])
        guard let section = node.sections.first as? TechnologiesRenderSection else {
            Issue.record("Expected a TechnologiesRenderSection")
            return
        }
        #expect(section.groups[0].technologies[0].title == "Example Kit")
    }

    @Test func decodesLegalNoticesOnANode() throws {
        let json = """
        {
            "schemaVersion": { "major": 0, "minor": 3, "patch": 0 },
            "identifier": { "url": "doc://com.example/documentation/examplekit", "interfaceLanguage": "swift" },
            "kind": "root",
            "metadata": {},
            "sections": [],
            "legalNotices": {
                "copyright": "Copyright &copy; 2026 Example Inc. All rights reserved.",
                "privacyPolicy": "https://example.com/privacy",
                "termsOfUse": "https://example.com/terms"
            }
        }
        """
        let node = try decode(RenderNode.self, json)
        #expect(node.legalNotices?.copyright == "Copyright &copy; 2026 Example Inc. All rights reserved.")
        #expect(node.legalNotices?.privacyPolicy == "https://example.com/privacy")
        #expect(node.legalNotices?.termsOfUse == "https://example.com/terms")
    }

    @Test func hierarchyDecodesToHomepageCase() throws {
        let json = """
        {
            "schemaVersion": { "major": 0, "minor": 3, "patch": 0 },
            "identifier": { "url": "doc://com.example/documentation/examplekit", "interfaceLanguage": "swift" },
            "kind": "root",
            "metadata": {},
            "sections": [],
            "hierarchy": { "homepageNavigation": [{ "reference": "doc://com.example/documentation/examplekit" }] }
        }
        """
        let node = try decode(RenderNode.self, json)
        guard case .homepage(let hierarchy) = node.hierarchyVariants.defaultValue else {
            Issue.record("Expected the hierarchy to decode to .homepage")
            return
        }
        #expect(hierarchy.homepageNavigation.count == 1)
        #expect(hierarchy.homepageNavigation[0].reference.identifier == "doc://com.example/documentation/examplekit")
    }
}
