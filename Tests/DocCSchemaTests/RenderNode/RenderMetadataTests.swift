// Covers RenderMetadata: an empty payload's defaults, a payload exercising most optional keys,
// author-provided extra metadata for unrecognized keys, and the "tutorial"/"project" role
// backwards-compatibility mapping.

import Testing
@testable import DocCSchema

private let fullMetadataJSON = """
{
    "title": "Example Title",
    "role": "symbol",
    "roleHeading": "Structure",
    "symbolKind": "struct",
    "symbolAccessLevel": "public",
    "modules": [{ "name": "ExampleKit" }],
    "extendedModule": "ExampleKitExtras",
    "platforms": [{ "name": "iOS", "introducedAt": "1.0" }],
    "required": true,
    "externalID": "s:ExampleKit",
    "fragments": [{ "text": "struct", "kind": "keyword" }],
    "navigatorTitle": [{ "text": "Thing", "kind": "identifier" }],
    "conformance": {
        "availabilityPrefix": [{ "type": "text", "text": "Available when" }],
        "conformancePrefix": [{ "type": "text", "text": "Conforms when" }],
        "constraints": [{ "type": "text", "text": "T conforms to Equatable" }]
    },
    "sourceFileURI": "file:///Thing.swift",
    "remoteSource": { "fileName": "Thing.swift", "url": "https://example.com/Thing.swift" },
    "tags": [{ "type": "spi", "text": "SPI" }],
    "images": [{ "type": "icon", "identifier": "example-icon" }],
    "color": { "standardColorIdentifier": "orange" },
    "customMetadata": { "exampleKey": "exampleValue" },
    "hasNoExpandedDocumentation": true,
    "category": "Example Category",
    "categoryPathComponent": "example-category",
    "estimatedTime": "5 min"
}
"""

@Suite struct RenderMetadataTests {
    @Test func decodesEmptyPayload() throws {
        let metadata = try decode(RenderMetadata.self, "{}")
        #expect(metadata.title == nil)
        #expect(metadata.tags == nil)
        #expect(metadata.images == [])
        #expect(metadata.customMetadata == [:])
        #expect(metadata.required == false)
        #expect(metadata.hasNoExpandedDocumentation == false)
    }

    @Test func decodesFullPayload() throws {
        let metadata = try decode(RenderMetadata.self, fullMetadataJSON)
        #expect(metadata.title == "Example Title")
        #expect(metadata.role == "symbol")
        #expect(metadata.symbolKind == "struct")
        #expect(metadata.required == true)
        #expect(metadata.modules?.map(\.name) == ["ExampleKit"])
        #expect(metadata.conformance != nil)
        #expect(metadata.tags == [RenderNode.Tag(type: "spi", text: "SPI")])
        #expect(metadata.color == TopicColor(standardColorIdentifier: "orange"))
    }

    @Test func roundTripsFullPayload() throws {
        try roundTrip(RenderMetadata.self, fullMetadataJSON)
    }

    @Test func extraMetadataCapturesUnknownKey() throws {
        let metadata = try roundTrip(RenderMetadata.self, """
        { "title": "Example Title", "undocumentedFlag": "custom-value" }
        """)
        #expect(metadata.extraMetadata[RenderMetadata.CodingKeys(stringValue: "undocumentedFlag")] as? String == "custom-value")
    }

    @Test func tutorialRoleBackwardsCompatibilityMapsToProject() throws {
        let metadata = try decode(RenderMetadata.self, """
        { "role": "tutorial" }
        """)
        #expect(metadata.role == RenderMetadata.Role.tutorial.rawValue)
        #expect(metadata.role == "project")
    }
}
