// Integration-style tests: a RenderNode's `references` dictionary dispatches each entry to
// its concrete reference type based on the `type` discriminator (`CodableRenderReference`),
// an unknown discriminator decodes to `UnknownRenderReference` and re-encodes unchanged, and
// `assetReferences` groups the asset-like reference types by their `RenderReferenceType`.

import Testing
@testable import DocCSchema

@Suite struct RenderReferenceDecodingTests {
    private static let nodeHeader = """
    "schemaVersion": {"major": 0, "minor": 3, "patch": 0},
    "identifier": {"url": "doc://com.example/documentation/examplekit", "interfaceLanguage": "swift"},
    "kind": "article",
    "sections": [],
    "metadata": {}
    """

    @Test func decodesEachReferenceTypeFromReferencesDictionary() throws {
        let node = try decode(RenderNode.self, """
        {
          \(Self.nodeHeader),
          "references": {
            "doc://com.example/documentation/examplekit/topic-thing": {
              "type": "topic", "identifier": "doc://com.example/documentation/examplekit/topic-thing",
              "title": "Topic Thing", "url": "/documentation/examplekit/topic-thing"
            },
            "doc://com.example/documentation/examplekit/section-thing": {
              "type": "section", "identifier": "doc://com.example/documentation/examplekit/section-thing",
              "title": "Section Thing", "url": "/documentation/examplekit/section-thing"
            },
            "doc://com.example/images/thing.png": {
              "type": "image", "identifier": "doc://com.example/images/thing.png", "variants": []
            },
            "doc://com.example/videos/thing.mp4": {
              "type": "video", "identifier": "doc://com.example/videos/thing.mp4", "variants": []
            },
            "doc://com.example/files/thing.swift": {
              "type": "file", "identifier": "doc://com.example/files/thing.swift",
              "fileName": "thing.swift", "fileType": "swift", "syntax": "swift", "content": ["struct Thing {}"]
            },
            "doc://com.example/fileTypes/swift": {
              "type": "fileType", "identifier": "doc://com.example/fileTypes/swift",
              "displayName": "Swift File", "iconBase64": "aGVsbG8="
            },
            "doc://com.example/xcode/16": {
              "type": "xcodeRequirement", "identifier": "doc://com.example/xcode/16",
              "title": "Xcode 16", "url": "https://example.com/xcode16.dmg"
            },
            "doc://com.example/downloads/sample.zip": {
              "type": "download", "identifier": "doc://com.example/downloads/sample.zip",
              "url": "https://example.com/sample.zip"
            },
            "https://example.com/external": {
              "type": "externalLocation", "identifier": "https://example.com/external",
              "url": "https://example.com/external"
            },
            "doc://com.example/documentation/examplekit/missing": {
              "type": "unresolvable", "identifier": "doc://com.example/documentation/examplekit/missing",
              "title": "Missing Thing"
            },
            "doc://com.example/links/thing": {
              "type": "link", "identifier": "doc://com.example/links/thing",
              "title": "Example Link", "url": "https://example.com/thing"
            }
          }
        }
        """)

        #expect(node.references.count == 11)

        let topic = try #require(node.references["doc://com.example/documentation/examplekit/topic-thing"] as? TopicRenderReference)
        #expect(topic.type == .topic)

        let section = try #require(node.references["doc://com.example/documentation/examplekit/section-thing"] as? TopicRenderReference)
        #expect(section.type == .section)

        #expect(node.references["doc://com.example/images/thing.png"] is ImageReference)
        #expect(node.references["doc://com.example/videos/thing.mp4"] is VideoReference)
        #expect(node.references["doc://com.example/files/thing.swift"] is FileReference)
        #expect(node.references["doc://com.example/fileTypes/swift"] is FileTypeReference)
        #expect(node.references["doc://com.example/xcode/16"] is XcodeRequirementReference)

        let download = try #require(node.references["doc://com.example/downloads/sample.zip"] as? DownloadReference)
        #expect(download.type == .download)

        let externalLocation = try #require(node.references["https://example.com/external"] as? DownloadReference)
        #expect(externalLocation.type == .externalLocation)

        #expect(node.references["doc://com.example/documentation/examplekit/missing"] is UnresolvedRenderReference)
        #expect(node.references["doc://com.example/links/thing"] is LinkReference)
    }

    @Test func unknownReferenceTypeIsPreserved() throws {
        let node = try roundTrip(RenderNode.self, """
        {
          \(Self.nodeHeader),
          "references": {
            "doc://com.example/documentation/examplekit/bogus": {
              "type": "bogus", "identifier": "doc://com.example/documentation/examplekit/bogus"
            }
          }
        }
        """)

        let unknown = try #require(node.references["doc://com.example/documentation/examplekit/bogus"] as? UnknownRenderReference)
        #expect(unknown.type == .unknown("bogus"))
        #expect(unknown.identifier.identifier == "doc://com.example/documentation/examplekit/bogus")
    }

    @Test func assetReferencesGroupsByType() throws {
        let node = try decode(RenderNode.self, """
        {
          \(Self.nodeHeader),
          "references": {
            "doc://com.example/documentation/examplekit/topic-thing": {
              "type": "topic", "identifier": "doc://com.example/documentation/examplekit/topic-thing",
              "title": "Topic Thing", "url": "/documentation/examplekit/topic-thing"
            },
            "doc://com.example/images/thing.png": {
              "type": "image", "identifier": "doc://com.example/images/thing.png", "variants": []
            },
            "doc://com.example/downloads/sample.zip": {
              "type": "download", "identifier": "doc://com.example/downloads/sample.zip",
              "url": "https://example.com/sample.zip"
            }
          }
        }
        """)

        let grouped = node.assetReferences
        #expect(grouped[.image]?.count == 1)
        #expect(grouped[.download]?.count == 1)
        // Topic references aren't asset-like, so they're excluded from the grouping.
        #expect(grouped[.topic] == nil)
    }
}
