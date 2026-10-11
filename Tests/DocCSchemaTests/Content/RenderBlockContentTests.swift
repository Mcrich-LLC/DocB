// Covers RenderBlockContent: one test per block kind (paragraph, aside, codeListing, heading,
// orderedList, unorderedList, step, endpointExample, dictionaryExample, table, termList, row,
// small, tabNavigator, links, video, thematicBreak), a missing-required-key failure, and an
// unknown discriminator (bare and nested inside a list item) preserved verbatim.

import Testing
@testable import DocCSchema

@Suite struct RenderBlockContentTests {
    @Test func decodesParagraph() throws {
        let value = try roundTrip(RenderBlockContent.self, """
        { "type": "paragraph", "inlineContent": [ { "type": "text", "text": "Example text." } ] }
        """)
        #expect(value == .paragraph(.init(inlineContent: [.text("Example text.")])))
    }

    @Test func decodesAsideWithImplicitName() throws {
        let json = """
        {
            "type": "aside",
            "style": "note",
            "content": [ { "type": "paragraph", "inlineContent": [ { "type": "text", "text": "A note." } ] } ]
        }
        """
        let value = try roundTrip(RenderBlockContent.self, json)
        guard case let .aside(aside) = value else {
            Issue.record("Expected .aside, got \(value)")
            return
        }
        #expect(aside.style.rawValue == "note")
        #expect(aside.name == "Note")
    }

    @Test func decodesAsideWithExplicitName() throws {
        let json = """
        {
            "type": "aside",
            "style": "tip",
            "name": "Pro Tip",
            "content": [ { "type": "paragraph", "inlineContent": [ { "type": "text", "text": "A tip." } ] } ]
        }
        """
        let value = try roundTrip(RenderBlockContent.self, json)
        guard case let .aside(aside) = value else {
            Issue.record("Expected .aside, got \(value)")
            return
        }
        #expect(aside.style.rawValue == "tip")
        #expect(aside.name == "Pro Tip")
    }

    @Test func decodesMinimalCodeListing() throws {
        let value = try roundTrip(RenderBlockContent.self, """
        { "type": "codeListing", "code": [ "let x = 1" ] }
        """)
        guard case let .codeListing(listing) = value else {
            Issue.record("Expected .codeListing, got \(value)")
            return
        }
        #expect(listing.syntax == nil)
        #expect(listing.code == ["let x = 1"])
        #expect(listing.options == nil)
    }

    @Test func decodesFullCodeListing() throws {
        let json = """
        {
            "type": "codeListing",
            "syntax": "swift",
            "code": [ "let x = 1", "let y = 2" ],
            "metadata": { "anchor": "example-listing" },
            "copyToClipboard": true,
            "showLineNumbers": true,
            "wrap": 80,
            "lineAnnotations": [
                { "style": "highlight", "range": [ { "line": 1, "character": 0 }, { "line": 1, "character": 5 } ] }
            ]
        }
        """
        let value = try roundTrip(RenderBlockContent.self, json)
        guard case let .codeListing(listing) = value else {
            Issue.record("Expected .codeListing, got \(value)")
            return
        }
        #expect(listing.syntax == "swift")
        #expect(listing.metadata?.anchor == "example-listing")
        #expect(listing.options?.copyToClipboard == true)
        #expect(listing.options?.showLineNumbers == true)
        #expect(listing.options?.wrap == 80)
        #expect(listing.options?.lineAnnotations.count == 1)
        #expect(listing.options?.lineAnnotations.first?.style == "highlight")
    }

    @Test func decodesHeading() throws {
        let json = """
        { "type": "heading", "level": 2, "text": "Example Heading", "anchor": "example-heading" }
        """
        let value = try roundTrip(RenderBlockContent.self, json)
        #expect(value == .heading(.init(level: 2, text: "Example Heading", anchor: "example-heading")))
    }

    @Test func decodesOrderedList() throws {
        let itemJSON = """
        { "content": [ { "type": "paragraph", "inlineContent": [ { "type": "text", "text": "Item one." } ] } ] }
        """

        let defaultStart = try roundTrip(RenderBlockContent.self, """
        { "type": "orderedList", "items": [ \(itemJSON) ] }
        """)
        guard case let .orderedList(list) = defaultStart else {
            Issue.record("Expected .orderedList, got \(defaultStart)")
            return
        }
        #expect(list.startIndex == 1)
        #expect(list.items.count == 1)

        let customStart = try roundTrip(RenderBlockContent.self, """
        { "type": "orderedList", "start": 5, "items": [ \(itemJSON) ] }
        """)
        guard case let .orderedList(customList) = customStart else {
            Issue.record("Expected .orderedList, got \(customStart)")
            return
        }
        #expect(customList.startIndex == 5)
    }

    @Test func decodesUnorderedList() throws {
        let json = """
        {
            "type": "unorderedList",
            "items": [
                {
                    "content": [ { "type": "paragraph", "inlineContent": [ { "type": "text", "text": "Task item." } ] } ],
                    "checked": true
                }
            ]
        }
        """
        let value = try roundTrip(RenderBlockContent.self, json)
        guard case let .unorderedList(list) = value else {
            Issue.record("Expected .unorderedList, got \(value)")
            return
        }
        #expect(list.items.count == 1)
        #expect(list.items[0].checked == true)
    }

    @Test func decodesMinimalStep() throws {
        // media, code, and runtimePreview are decoded as non-optional-key optionals: the keys
        // must be present (here explicitly null) even though their values may be absent.
        let json = """
        {
            "type": "step",
            "content": [ { "type": "paragraph", "inlineContent": [ { "type": "text", "text": "Do the thing." } ] } ],
            "media": null,
            "code": null,
            "runtimePreview": null
        }
        """
        let value = try roundTrip(RenderBlockContent.self, json)
        guard case let .step(step) = value else {
            Issue.record("Expected .step, got \(value)")
            return
        }
        #expect(step.caption == [])
        #expect(step.media == nil)
        #expect(step.code == nil)
        #expect(step.runtimePreview == nil)
    }

    @Test func decodesFullStep() throws {
        let json = """
        {
            "type": "step",
            "content": [ { "type": "paragraph", "inlineContent": [ { "type": "text", "text": "Do the thing." } ] } ],
            "caption": [ { "type": "paragraph", "inlineContent": [ { "type": "text", "text": "Step one." } ] } ],
            "media": "example-media",
            "code": "example-code",
            "runtimePreview": "example-preview"
        }
        """
        let value = try roundTrip(RenderBlockContent.self, json)
        guard case let .step(step) = value else {
            Issue.record("Expected .step, got \(value)")
            return
        }
        #expect(step.caption.count == 1)
        #expect(step.media == RenderReferenceIdentifier("example-media"))
        #expect(step.code == RenderReferenceIdentifier("example-code"))
        #expect(step.runtimePreview == RenderReferenceIdentifier("example-preview"))
    }

    @Test func decodesEndpointExample() throws {
        let json = """
        {
            "type": "endpointExample",
            "summary": [ { "type": "paragraph", "inlineContent": [ { "type": "text", "text": "Example summary." } ] } ],
            "request": {
                "type": "http",
                "syntax": "swift",
                "content": [ { "collapsible": false, "code": [ "GET /example" ] } ]
            },
            "response": {
                "content": [ { "collapsible": true, "code": [ "200 OK" ] } ]
            }
        }
        """
        let value = try roundTrip(RenderBlockContent.self, json)
        guard case let .endpointExample(example) = value else {
            Issue.record("Expected .endpointExample, got \(value)")
            return
        }
        #expect(example.summary?.count == 1)
        #expect(example.request.syntax == "swift")
        #expect(example.request.content == [.init(collapsible: false, code: ["GET /example"])])
        #expect(example.response.content == [.init(collapsible: true, code: ["200 OK"])])
    }

    @Test func decodesDictionaryExample() throws {
        let json = """
        {
            "type": "dictionaryExample",
            "example": {
                "content": [ { "collapsible": false, "code": [ "{ \\"key\\": \\"value\\" }" ] } ]
            }
        }
        """
        let value = try roundTrip(RenderBlockContent.self, json)
        guard case let .dictionaryExample(example) = value else {
            Issue.record("Expected .dictionaryExample, got \(value)")
            return
        }
        #expect(example.summary == nil)
        #expect(example.example.content.count == 1)
    }

    @Test func decodesMinimalTable() throws {
        let json = """
        { "type": "table", "header": "none", "rows": [ [ [] ] ] }
        """
        let value = try roundTrip(RenderBlockContent.self, json)
        guard case let .table(table) = value else {
            Issue.record("Expected .table, got \(value)")
            return
        }
        #expect(table.header == .none)
        #expect(table.alignments == nil)
        #expect(table.rows == [.init(cells: [[]])])
        #expect(table.extendedData.isEmpty)
        #expect(table.metadata == nil)
    }

    @Test func decodesFullTable() throws {
        let json = """
        {
            "type": "table",
            "header": "row",
            "alignments": [ "left", "right" ],
            "rows": [
                [
                    [ { "type": "paragraph", "inlineContent": [ { "type": "text", "text": "Cell A1" } ] } ],
                    [ { "type": "paragraph", "inlineContent": [ { "type": "text", "text": "Cell B1" } ] } ]
                ]
            ],
            "extendedData": {
                "0_0": { "colspan": 2, "rowspan": 1 }
            },
            "metadata": { "anchor": "example-table" }
        }
        """
        let value = try roundTrip(RenderBlockContent.self, json)
        guard case let .table(table) = value else {
            Issue.record("Expected .table, got \(value)")
            return
        }
        #expect(table.header == .row)
        #expect(table.alignments == [.left, .right])
        #expect(table.rows.count == 1)
        #expect(table.rows[0].cells.count == 2)
        #expect(table.extendedData == [.init(rowIndex: 0, columnIndex: 0, colspan: 2, rowspan: 1)])
        #expect(table.metadata?.anchor == "example-table")
    }

    @Test func decodesTableWithAllUnsetAlignmentsAsNil() throws {
        // All-`unset` alignments collapse to `nil` on decode (and are dropped on encode), so this
        // key is intentionally omitted from the round-trip subset check.
        let json = """
        {
            "type": "table",
            "header": "none",
            "alignments": [ "unset", "unset" ],
            "rows": [ [ [] ] ]
        }
        """
        let value = try roundTrip(RenderBlockContent.self, json, omitting: ["alignments"])
        guard case let .table(table) = value else {
            Issue.record("Expected .table, got \(value)")
            return
        }
        #expect(table.alignments == nil)
    }

    @Test func decodesTermList() throws {
        let json = """
        {
            "type": "termList",
            "items": [
                {
                    "term": { "inlineContent": [ { "type": "text", "text": "Example Term" } ] },
                    "definition": { "content": [ { "type": "paragraph", "inlineContent": [ { "type": "text", "text": "Example definition." } ] } ] }
                }
            ]
        }
        """
        let value = try roundTrip(RenderBlockContent.self, json)
        guard case let .termList(list) = value else {
            Issue.record("Expected .termList, got \(value)")
            return
        }
        #expect(list.items.count == 1)
        #expect(list.items[0].term.inlineContent == [.text("Example Term")])
    }

    @Test func decodesRow() throws {
        let json = """
        {
            "type": "row",
            "numberOfColumns": 2,
            "columns": [
                {
                    "size": 1,
                    "alignment": "center",
                    "content": [ { "type": "paragraph", "inlineContent": [ { "type": "text", "text": "Column one." } ] } ]
                },
                {
                    "size": 1,
                    "content": [ { "type": "paragraph", "inlineContent": [ { "type": "text", "text": "Column two." } ] } ]
                }
            ]
        }
        """
        let value = try roundTrip(RenderBlockContent.self, json)
        guard case let .row(row) = value else {
            Issue.record("Expected .row, got \(value)")
            return
        }
        #expect(row.numberOfColumns == 2)
        #expect(row.columns[0].alignment == .center)
        // Missing "alignment" defaults to .leading.
        #expect(row.columns[1].alignment == .leading)
    }

    @Test func decodesSmall() throws {
        let value = try roundTrip(RenderBlockContent.self, """
        { "type": "small", "inlineContent": [ { "type": "text", "text": "Example small print." } ] }
        """)
        guard case let .small(small) = value else {
            Issue.record("Expected .small, got \(value)")
            return
        }
        #expect(small.inlineContent == [.text("Example small print.")])
    }

    @Test func decodesTabNavigator() throws {
        let json = """
        {
            "type": "tabNavigator",
            "tabs": [
                {
                    "title": "Tab One",
                    "content": [ { "type": "paragraph", "inlineContent": [ { "type": "text", "text": "Tab content." } ] } ]
                }
            ]
        }
        """
        let value = try roundTrip(RenderBlockContent.self, json)
        guard case let .tabNavigator(navigator) = value else {
            Issue.record("Expected .tabNavigator, got \(value)")
            return
        }
        #expect(navigator.tabs.count == 1)
        #expect(navigator.tabs[0].title == "Tab One")
    }

    @Test func decodesLinksStyles() throws {
        let styles: [(String, RenderBlockContent.Links.Style)] = [
            ("list", .list),
            ("compactGrid", .compactGrid),
            ("detailedGrid", .detailedGrid),
        ]
        for (raw, expected) in styles {
            let json = """
            { "type": "links", "style": "\(raw)", "items": [ "doc://com.example/documentation/examplekit/one" ] }
            """
            let value = try roundTrip(RenderBlockContent.self, json)
            guard case let .links(links) = value else {
                Issue.record("Expected .links, got \(value)")
                return
            }
            #expect(links.style == expected)
            #expect(links.items == ["doc://com.example/documentation/examplekit/one"])
        }
    }

    @Test func decodesVideo() throws {
        let minimal = try roundTrip(RenderBlockContent.self, """
        { "type": "video", "identifier": "example-video" }
        """)
        guard case let .video(video) = minimal else {
            Issue.record("Expected .video, got \(minimal)")
            return
        }
        #expect(video.identifier == RenderReferenceIdentifier("example-video"))
        #expect(video.metadata == nil)

        let full = try roundTrip(RenderBlockContent.self, """
        { "type": "video", "identifier": "example-video", "metadata": { "anchor": "example-caption" } }
        """)
        guard case let .video(fullVideo) = full else {
            Issue.record("Expected .video, got \(full)")
            return
        }
        #expect(fullVideo.metadata?.anchor == "example-caption")
    }

    @Test func decodesThematicBreak() throws {
        let value = try roundTrip(RenderBlockContent.self, """
        { "type": "thematicBreak" }
        """)
        #expect(value == .thematicBreak)
    }

    @Test func missingRequiredKeyThrows() {
        // "paragraph" requires the "inlineContent" key.
        #expect(throws: (any Error).self) {
            try decode(RenderBlockContent.self, """
            { "type": "paragraph" }
            """)
        }
    }

    @Test func unknownDiscriminatorIsPreserved() throws {
        let json = """
        { "type": "notARealKind" }
        """
        let value = try roundTrip(RenderBlockContent.self, json)
        guard case .unknown(let payload) = value, case .dictionary(let object) = payload else {
            Issue.record("Expected .unknown")
            return
        }
        #expect(object["type"] == .string("notARealKind"))
    }

    @Test func unknownBlockNestedInUnorderedListItemRoundTrips() throws {
        let json = """
        {
            "type": "unorderedList",
            "items": [
                {
                    "content": [ { "type": "notARealKind", "extra": "value" } ]
                }
            ]
        }
        """
        let value = try roundTrip(RenderBlockContent.self, json)
        guard case let .unorderedList(list) = value else {
            Issue.record("Expected .unorderedList, got \(value)")
            return
        }
        #expect(list.items.count == 1)
        guard let firstItem = list.items[0].content.first,
              case .unknown(let payload) = firstItem,
              case .dictionary(let object) = payload else {
            Issue.record("Expected nested .unknown block")
            return
        }
        #expect(object["extra"] == .string("value"))
    }
}
