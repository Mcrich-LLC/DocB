// Covers RenderNode's top-level shape: a minimal symbol page, a fuller page exercising
// hierarchy, abstract, topic/primary-content/see-also sections, topic/image/link references,
// variants and variantOverrides, the RenderNode.Kind discriminator's string mapping, and an
// unknown section kind preserved as UnknownRenderSection in both `sections` and
// `primaryContentSections`.

import Testing
@testable import DocCSchema

private let minimalRenderNodeJSON = """
{
    "schemaVersion": { "major": 0, "minor": 3, "patch": 0 },
    "identifier": { "url": "doc://com.example/documentation/examplekit/thing", "interfaceLanguage": "swift" },
    "kind": "symbol",
    "metadata": {},
    "sections": [],
    "references": {}
}
"""

private let fullRenderNodeJSON = """
{
    "schemaVersion": { "major": 0, "minor": 3, "patch": 0 },
    "identifier": { "url": "doc://com.example/documentation/examplekit/thing", "interfaceLanguage": "swift" },
    "kind": "symbol",
    "hierarchy": {
        "paths": [["doc://com.example/documentation/examplekit"]]
    },
    "abstract": [{ "type": "text", "text": "An example abstract." }],
    "metadata": { "title": "Example Title", "role": "symbol" },
    "primaryContentSections": [
        {
            "kind": "content",
            "content": [
                { "type": "paragraph", "inlineContent": [{ "type": "text", "text": "Body text." }] }
            ]
        }
    ],
    "topicSections": [
        {
            "title": "Example Group",
            "identifiers": ["doc://com.example/documentation/examplekit/other"]
        }
    ],
    "seeAlsoSections": [
        {
            "title": "Related",
            "identifiers": ["doc://com.example/documentation/examplekit/related"]
        }
    ],
    "sections": [],
    "references": {
        "doc://com.example/documentation/examplekit/other": {
            "type": "topic",
            "identifier": "doc://com.example/documentation/examplekit/other",
            "title": "Other",
            "abstract": [{ "type": "text", "text": "Other abstract." }],
            "url": "/documentation/examplekit/other",
            "kind": "symbol"
        },
        "example-icon": {
            "type": "image",
            "identifier": "example-icon",
            "alt": "An icon.",
            "variants": [{ "url": "https://example.com/icon.png", "traits": ["2x"] }]
        },
        "example-link": {
            "type": "link",
            "identifier": "example-link",
            "title": "Example Link",
            "titleInlineContent": [{ "type": "text", "text": "Example Link" }],
            "url": "https://example.com"
        }
    },
    "variants": [
        {
            "traits": [{ "interfaceLanguage": "occ" }],
            "paths": ["/documentation/examplekit/thing-objc"]
        }
    ],
    "variantOverrides": [
        {
            "traits": [{ "interfaceLanguage": "occ" }],
            "patch": [
                { "op": "replace", "path": "/title", "value": "Example Title (ObjC)" }
            ]
        }
    ]
}
"""

@Suite struct RenderNodeTests {
    @Test func decodesMinimalSymbolPage() throws {
        let node = try decode(RenderNode.self, minimalRenderNodeJSON)
        #expect(node.kind == .symbol)
        #expect(node.schemaVersion == SemanticVersion(major: 0, minor: 3, patch: 0))
        #expect(node.sections.isEmpty)
        #expect(node.references.isEmpty)
        #expect(node.hierarchyVariants.defaultValue == nil)
    }

    @Test func roundTripsMinimalSymbolPage() throws {
        try roundTrip(RenderNode.self, minimalRenderNodeJSON)
    }

    @Test func decodesFullSymbolPage() throws {
        let node = try decode(RenderNode.self, fullRenderNodeJSON)
        #expect(node.abstract?.count == 1)
        if case .reference(let hierarchy) = node.hierarchyVariants.defaultValue {
            #expect(hierarchy.paths == [["doc://com.example/documentation/examplekit"]])
        } else {
            Issue.record("Expected a reference hierarchy")
        }
        #expect(node.primaryContentSections.count == 1)
        #expect(node.topicSections.first?.identifiers == ["doc://com.example/documentation/examplekit/other"])
        #expect(node.seeAlsoSections.first?.title == "Related")
        #expect(node.references.count == 3)
        #expect(node.references["doc://com.example/documentation/examplekit/other"]?.type == .topic)
        #expect(node.references["example-icon"]?.type == .image)
        #expect(node.references["example-link"]?.type == .link)
        #expect(node.variants?.first?.paths == ["/documentation/examplekit/thing-objc"])
        #expect(node.variantOverrides?.values.first?.patch.count == 1)
    }

    @Test func roundTripsFullSymbolPage() throws {
        try roundTrip(RenderNode.self, fullRenderNodeJSON)
    }

    @Test func kindAcceptsLegacyProjectSpellingAndEncodesTutorialAsProject() throws {
        #expect(try decode(RenderNode.Kind.self, "\"project\"") == .tutorial)
        #expect(try decode(RenderNode.Kind.self, "\"tutorial\"") == .tutorial)
        // Wrapped in an array: JSONSerialization (used by `roundTrip`'s subset check) rejects a
        // bare top-level string fragment.
        try roundTrip([RenderNode.Kind].self, "[\"project\"]")
    }

    @Test func unknownKindIsPreserved() throws {
        let value = try decode(RenderNode.Kind.self, "\"bogus\"")
        #expect(value == .unknown("bogus"))
        let encoded = try RenderJSONEncoder.makeEncoder().encode(value)
        #expect(try decode(RenderNode.Kind.self, String(decoding: encoded, as: UTF8.self)) == value)
    }

    @Test func unknownSectionInSectionsRoundTrips() throws {
        let json = """
        {
            "schemaVersion": { "major": 0, "minor": 3, "patch": 0 },
            "identifier": { "url": "doc://com.example/documentation/examplekit/thing", "interfaceLanguage": "swift" },
            "kind": "symbol",
            "metadata": {},
            "sections": [
                { "kind": "bogusSection", "extra": "value" }
            ],
            "references": {}
        }
        """
        let node = try roundTrip(RenderNode.self, json)
        #expect(node.sections.count == 1)
        let section = try #require(node.sections.first as? UnknownRenderSection)
        #expect(section.kind == .unknown("bogusSection"))
    }

    @Test func unknownSectionInPrimaryContentSectionsRoundTrips() throws {
        let json = """
        {
            "schemaVersion": { "major": 0, "minor": 3, "patch": 0 },
            "identifier": { "url": "doc://com.example/documentation/examplekit/thing", "interfaceLanguage": "swift" },
            "kind": "symbol",
            "metadata": {},
            "sections": [],
            "primaryContentSections": [
                { "kind": "bogusSection", "extra": "value" }
            ],
            "references": {}
        }
        """
        let node = try roundTrip(RenderNode.self, json)
        #expect(node.primaryContentSections.count == 1)
        let section = try #require(node.primaryContentSections.first as? UnknownRenderSection)
        #expect(section.kind == .unknown("bogusSection"))
    }

    @Test func missingRequiredSectionsKeyThrows() throws {
        #expect(throws: (any Error).self) {
            try decode(RenderNode.self, """
            {
                "schemaVersion": { "major": 0, "minor": 3, "patch": 0 },
                "identifier": { "url": "doc://com.example/documentation/examplekit/thing", "interfaceLanguage": "swift" },
                "kind": "symbol",
                "metadata": {},
                "references": {}
            }
            """)
        }
    }
}
