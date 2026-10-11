// Shape tests for TopicRenderReference: a reference to another documentation page, carrying
// the summary information (title, abstract, kind, availability) needed to render a link to
// it. Covers the minimal payload, every optional key, the `kind` discriminator (including its
// backwards-compatibility default and the property-list title-style trio), and how a
// RenderNode-level variant override patches a reference's title.

import Foundation
import Testing
@testable import DocCSchema

@Suite struct TopicRenderReferenceTests {
    @Test func decodesMinimalPayload() throws {
        let reference = try decode(TopicRenderReference.self, """
        {"type":"topic","identifier":"doc://com.example/documentation/examplekit/thing","title":"Example Title","url":"/documentation/examplekit/thing"}
        """)
        #expect(reference.type == .topic)
        #expect(reference.title == "Example Title")
        #expect(reference.url == "/documentation/examplekit/thing")
        // No `kind` key is backwards-compatibility for `.tutorial`.
        #expect(reference.kind == .tutorial)
        #expect(reference.required == false)
        #expect(reference.isBeta == false)
        #expect(reference.isDeprecated == false)
        #expect(reference.abstract == [])
        #expect(reference.images == [])
        #expect(reference.propertyListKeyNames == nil)
    }

    @Test func decodesWithAbstractFragmentsAndConformance() throws {
        let reference = try decode(TopicRenderReference.self, """
        {
          "type": "topic",
          "identifier": "doc://com.example/documentation/examplekit/thing",
          "title": "Example Title",
          "url": "/documentation/examplekit/thing",
          "abstract": [{"type": "text", "text": "An abstract."}],
          "kind": "symbol",
          "required": true,
          "role": "collectionGroup",
          "fragments": [{"text": "func thing()", "kind": "identifier"}],
          "navigatorTitle": [{"text": "thing()", "kind": "identifier"}],
          "estimatedTime": "5 min",
          "conformance": {
            "availabilityPrefix": [{"type": "text", "text": "Available when"}],
            "conformancePrefix": [{"type": "text", "text": "Conforms when"}],
            "constraints": [{"type": "text", "text": "Element conforms to Equatable"}]
          },
          "beta": true,
          "deprecated": true,
          "defaultImplementations": 2
        }
        """)
        #expect(reference.abstract == [.text("An abstract.")])
        #expect(reference.kind == .symbol)
        #expect(reference.required == true)
        #expect(reference.role == "collectionGroup")
        #expect(reference.fragments == [.init(text: "func thing()", kind: .identifier)])
        #expect(reference.navigatorTitle == [.init(text: "thing()", kind: .identifier)])
        #expect(reference.estimatedTime == "5 min")
        #expect(reference.conformance != nil)
        #expect(reference.isBeta == true)
        #expect(reference.isDeprecated == true)
        #expect(reference.defaultImplementationCount == 2)
    }

    @Test func decodesWithImages() throws {
        let reference = try decode(TopicRenderReference.self, """
        {
          "type": "topic",
          "identifier": "doc://com.example/documentation/examplekit/thing",
          "title": "Example Title",
          "url": "/documentation/examplekit/thing",
          "images": [{"type": "icon", "identifier": "doc://com.example/documentation/examplekit/icon.png"}]
        }
        """)
        #expect(reference.images.count == 1)
        #expect(reference.images[0].type == .icon)
        #expect(reference.images[0].identifier.identifier == "doc://com.example/documentation/examplekit/icon.png")
    }

    @Test func decodesPropertyListKeyNames() throws {
        let reference = try decode(TopicRenderReference.self, """
        {
          "type": "topic",
          "identifier": "doc://com.example/documentation/examplekit/thing",
          "title": "Example Title",
          "url": "/documentation/examplekit/thing",
          "titleStyle": "symbol",
          "name": "com.example.key",
          "ideTitle": "Example Key"
        }
        """)
        #expect(reference.propertyListKeyNames?.titleStyle == .useRawKey)
        #expect(reference.propertyListKeyNames?.rawKey == "com.example.key")
        #expect(reference.propertyListKeyNames?.displayName == "Example Key")
    }

    @Test func kindDiscriminatorValuesIncludingUnknown() throws {
        let cases: [(String, RenderNode.Kind)] = [
            ("symbol", .symbol),
            ("article", .article),
            ("project", .tutorial),
            ("tutorial", .tutorial),
            ("section", .section),
            ("overview", .overview),
        ]
        for (raw, expected) in cases {
            let reference = try decode(TopicRenderReference.self, """
            {"type":"topic","identifier":"doc://com.example/documentation/examplekit/thing","title":"Example Title","url":"/documentation/examplekit/thing","kind":"\(raw)"}
            """)
            #expect(reference.kind == expected)
        }

        let unknownJSON = """
        {"type":"topic","identifier":"doc://com.example/documentation/examplekit/thing","title":"Example Title","url":"/documentation/examplekit/thing","kind":"bogus"}
        """
        let reference = try roundTrip(TopicRenderReference.self, unknownJSON)
        #expect(reference.kind == .unknown("bogus"))
    }

    @Test func roundTrips() throws {
        try roundTrip(TopicRenderReference.self, """
        {
          "type": "topic",
          "identifier": "doc://com.example/documentation/examplekit/thing",
          "title": "Example Title",
          "url": "/documentation/examplekit/thing",
          "abstract": [{"type": "text", "text": "An abstract."}],
          "kind": "symbol",
          "required": true,
          "role": "collectionGroup",
          "fragments": [{"text": "func thing()", "kind": "identifier"}],
          "navigatorTitle": [{"text": "thing()", "kind": "identifier"}],
          "estimatedTime": "5 min",
          "beta": true,
          "deprecated": true,
          "defaultImplementations": 2,
          "titleStyle": "symbol",
          "name": "com.example.key",
          "ideTitle": "Example Key",
          "tags": [{"type": "spi", "text": "SPI"}],
          "images": [{"type": "icon", "identifier": "doc://com.example/documentation/examplekit/icon.png"}]
        }
        """)
    }

    @Test func missingTitleThrows() {
        #expect(throws: (any Error).self) {
            try decode(TopicRenderReference.self, """
            {"type":"topic","identifier":"doc://com.example/documentation/examplekit/thing","url":"/documentation/examplekit/thing"}
            """)
        }
    }

    /// The `titleVariants`/`abstractVariants` etc. properties only ever decode a scalar default
    /// value directly (`VariantCollection.init(from:)` never sees per-trait overrides); trait
    /// overrides for a reference instead live in the enclosing render node's top-level
    /// `variantOverrides` JSON Patch, keyed by a pointer into `references`. Exercise that path
    /// with `RenderNodeVariantOverridesApplier` directly on hand-built JSON.
    @Test func variantOverridePatchesReferenceTitle() throws {
        let identifier = "doc://com.example/documentation/examplekit/thing"
        let pointer = JSONPointer(pathComponents: ["references", identifier, "title"])

        let outerJSON = """
        {
          "variantOverrides": [
            {
              "traits": [{"interfaceLanguage": "occ"}],
              "patch": [{"op": "replace", "path": "\(pointer.description)", "value": "Alternate Title"}]
            }
          ],
          "references": {
            "\(identifier)": {
              "type": "topic",
              "identifier": "\(identifier)",
              "title": "Example Title",
              "url": "/documentation/examplekit/thing"
            }
          }
        }
        """

        let patchedData = try RenderNodeVariantOverridesApplier().applyVariantOverrides(
            in: Data(outerJSON.utf8),
            for: [.interfaceLanguage("occ")]
        )

        let patchedJSON = try JSONSerialization.jsonObject(with: patchedData) as? [String: Any]
        #expect(patchedJSON?["variantOverrides"] == nil)

        let references = try #require(patchedJSON?["references"] as? [String: Any])
        let referenceObject = try #require(references[identifier])
        let referenceData = try JSONSerialization.data(withJSONObject: referenceObject)
        let patchedReference = try decode(TopicRenderReference.self, String(decoding: referenceData, as: UTF8.self))

        #expect(patchedReference.title == "Alternate Title")
    }
}
