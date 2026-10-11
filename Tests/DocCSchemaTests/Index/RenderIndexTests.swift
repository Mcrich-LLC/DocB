// Shape tests for RenderIndex and its nested Node type: schema version, the
// interface-languages-to-nodes mapping, node flags/icon/children nesting, the
// image references dictionary, and included archive identifiers.

import Testing
@testable import DocCSchema

@Suite struct RenderIndexTests {
    @Test func decodesMinimalIndex() throws {
        let json = """
        {
          "schemaVersion": {"major": 0, "minor": 1, "patch": 2},
          "interfaceLanguages": {
            "swift": [
              {"title": "Example title"}
            ]
          }
        }
        """
        let index = try decode(RenderIndex.self, json)

        #expect(index.schemaVersion == SemanticVersion(major: 0, minor: 1, patch: 2))
        #expect(index.interfaceLanguages["swift"]?.count == 1)

        let node = try #require(index.interfaceLanguages["swift"]?.first)
        #expect(node.title == "Example title")
        #expect(node.path == nil)
        #expect(node.type == nil)
        #expect(node.children == nil)
        #expect(node.isDeprecated == false)
        #expect(node.isExternal == false)
        #expect(node.isBeta == false)
        #expect(node.icon == nil)

        #expect(index.references.isEmpty)
        #expect(index.includedArchiveIdentifiers.isEmpty)
    }

    @Test func decodesNodeWithAllFlagsIconAndNestedChildren() throws {
        let json = """
        {
          "title": "Example Container",
          "path": "documentation/examplekit/container",
          "type": "container",
          "deprecated": true,
          "external": true,
          "beta": true,
          "icon": "example-icon",
          "children": [
            {"title": "Example Child", "path": "documentation/examplekit/container/child", "type": "symbol"}
          ]
        }
        """
        let node = try decode(RenderIndex.Node.self, json)

        #expect(node.title == "Example Container")
        #expect(node.path == "documentation/examplekit/container")
        #expect(node.type == "container")
        #expect(node.isDeprecated == true)
        #expect(node.isExternal == true)
        #expect(node.isBeta == true)
        #expect(node.icon == RenderReferenceIdentifier("example-icon"))
        #expect(node.children?.count == 1)
        #expect(node.children?.first?.title == "Example Child")
    }

    @Test func decodesTwoInterfaceLanguagesIncludedArchiveIdentifiersAndReferences() throws {
        let json = """
        {
          "schemaVersion": {"major": 0, "minor": 1, "patch": 2},
          "interfaceLanguages": {
            "swift": [{"title": "Example Swift Title"}],
            "occ": [{"title": "Example ObjC Title"}]
          },
          "references": {
            "example-icon": {
              "type": "image",
              "identifier": "example-icon",
              "alt": "An example icon",
              "variants": [
                {"url": "https://example.com/image.png", "traits": ["2x", "dark"]}
              ]
            }
          },
          "includedArchiveIdentifiers": ["com.example.examplekit"]
        }
        """
        let index = try decode(RenderIndex.self, json)

        #expect(index.interfaceLanguages.keys.sorted() == ["occ", "swift"])
        #expect(index.interfaceLanguages["occ"]?.first?.title == "Example ObjC Title")
        #expect(index.includedArchiveIdentifiers == ["com.example.examplekit"])

        let reference = try #require(index.references["example-icon"])
        #expect(reference.identifier == RenderReferenceIdentifier("example-icon"))
        #expect(reference.altText == "An example icon")
    }

    @Test func roundTripsFullPayload() throws {
        let json = """
        {
          "schemaVersion": {"major": 1, "minor": 2, "patch": 3, "prerelease": "beta.1", "buildMetadata": "20260101"},
          "interfaceLanguages": {
            "swift": [
              {
                "title": "Example Container",
                "path": "documentation/examplekit/container",
                "type": "container",
                "deprecated": true,
                "external": true,
                "beta": true,
                "icon": "example-icon",
                "children": [
                  {"title": "Example Child", "path": "documentation/examplekit/container/child", "type": "symbol"}
                ]
              }
            ],
            "occ": [
              {"title": "Example ObjC Title"}
            ]
          },
          "references": {
            "example-icon": {
              "type": "image",
              "identifier": "example-icon",
              "alt": "An example icon",
              "variants": [
                {"url": "https://example.com/image.png", "traits": ["2x", "dark"], "svgID": "exampleSVGID"}
              ]
            }
          },
          "includedArchiveIdentifiers": ["com.example.examplekit"]
        }
        """
        let index = try roundTrip(RenderIndex.self, json)

        #expect(index.schemaVersion.prerelease == "beta.1")
        #expect(index.schemaVersion.buildMetadata == "20260101")
    }

    @Test func missingInterfaceLanguagesThrows() throws {
        let json = """
        {
          "schemaVersion": {"major": 0, "minor": 1, "patch": 2}
        }
        """
        #expect(throws: (any Error).self) {
            try decode(RenderIndex.self, json)
        }
    }

    @Test func missingNodeTitleThrows() throws {
        let json = """
        {
          "path": "documentation/examplekit/container"
        }
        """
        #expect(throws: (any Error).self) {
            try decode(RenderIndex.Node.self, json)
        }
    }
}
