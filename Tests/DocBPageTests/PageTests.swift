// A page built from render JSON: references resolved, inline markup flattened, sections in
// reading order, and whatever the model cannot carry named as unsupported.

import Foundation
import Testing
import DocCSchema
@testable import DocBPage

@Suite struct PageTests {
    static let symbol = """
    {"schemaVersion": {"major": 0, "minor": 3, "patch": 0},
     "identifier": {"url": "doc://x/documentation/ExampleKit/Thing", "interfaceLanguage": "swift"},
     "metadata": {"title": "Thing", "role": "symbol", "roleHeading": "Structure", "symbolKind": "struct",
       "platforms": [{"name": "iOS", "introducedAt": "13.0", "beta": true}, {"name": "macOS", "introducedAt": "10.15", "deprecatedAt": "14.0"}]},
     "kind": "symbol",
     "abstract": [{"type": "text", "text": "A "}, {"type": "codeVoice", "code": "thing"}, {"type": "text", "text": " with a "},
                  {"type": "reference", "identifier": "doc://x/documentation/ExampleKit/Other", "isActive": true},
                  {"type": "text", "text": " and "}, {"type": "reference", "identifier": "doc://x/documentation/ExampleKit/Gone", "isActive": false}],
     "deprecationSummary": [{"type": "paragraph", "inlineContent": [{"type": "text", "text": "Use something else."}]}],
     "sections": [],
     "primaryContentSections": [
       {"kind": "declarations", "declarations": [{"platforms": [], "tokens": [
          {"kind": "keyword", "text": "struct"}, {"kind": "text", "text": " "}, {"kind": "identifier", "text": "Thing"},
          {"kind": "text", "text": ": "}, {"kind": "typeIdentifier", "text": "Other", "identifier": "doc://x/documentation/ExampleKit/Other"}]}]},
       {"kind": "parameters", "parameters": [{"name": "count", "content": [{"type": "paragraph", "inlineContent": [{"type": "text", "text": "How many."}]}]}]},
       {"kind": "content", "content": [
         {"type": "heading", "level": 2, "text": "Overview", "anchor": "overview"},
         {"type": "paragraph", "inlineContent": [
           {"type": "text", "text": "Plain, "},
           {"type": "strong", "inlineContent": [{"type": "text", "text": "bold and "}, {"type": "emphasis", "inlineContent": [{"type": "text", "text": "both"}]}]},
           {"type": "text", "text": ", then "},
           {"type": "reference", "identifier": "https://example.com", "isActive": true, "overridingTitle": "a site"},
           {"type": "text", "text": "."}]},
         {"type": "paragraph", "inlineContent": [{"type": "image", "identifier": "figure-1", "metadata": {"abstract": [{"type": "text", "text": "A figure."}]}}]},
         {"type": "aside", "style": "warning", "name": "Warning", "content": [{"type": "paragraph", "inlineContent": [{"type": "text", "text": "Careful."}]}]},
         {"type": "codeListing", "syntax": "swift", "code": ["let a = 1", "let b = 2"]},
         {"type": "orderedList", "start": 3, "items": [{"content": [{"type": "paragraph", "inlineContent": [{"type": "text", "text": "third"}]}]}]},
         {"type": "table", "header": "row", "alignments": ["left", "right"], "extendedData": {"1_0": {"colspan": 2, "rowspan": 1}, "1_1": {"colspan": 0, "rowspan": 0}}, "rows": [
           [[{"type": "paragraph", "inlineContent": [{"type": "text", "text": "Name"}]}], [{"type": "paragraph", "inlineContent": [{"type": "text", "text": "Value"}]}]],
           [[{"type": "paragraph", "inlineContent": [{"type": "text", "text": "wide"}]}], []]]},
         {"type": "tabNavigator", "tabs": [{"title": "One", "content": [{"type": "paragraph", "inlineContent": [{"type": "text", "text": "in one"}]}]}]},
         {"type": "video", "identifier": "clip-1", "metadata": {"abstract": [{"type": "text", "text": "A clip."}]}},
         {"type": "row", "numberOfColumns": 3, "columns": [{"size": 2, "content": [{"type": "paragraph", "inlineContent": [{"type": "text", "text": "wide column"}]}]}, {"size": 1, "content": [{"type": "paragraph", "inlineContent": [{"type": "text", "text": "narrow column"}]}]}]},
         {"type": "hologram", "beams": 3},
         {"type": "thematicBreak"}]}
     ],
     "topicSections": [{"title": "Essentials", "identifiers": ["doc://x/documentation/ExampleKit/Other", "doc://x/documentation/ExampleKit/Gone", "doc://x/nothing"]}],
     "seeAlsoSections": [{"identifiers": ["doc://x/documentation/ExampleKit/Other"]}],
     "references": {
       "doc://x/documentation/ExampleKit/Other": {"type": "topic", "identifier": "doc://x/documentation/ExampleKit/Other", "title": "Other", "url": "/documentation/examplekit/other", "kind": "symbol", "role": "symbol", "abstract": [{"type": "text", "text": "Another."}], "beta": true},
       "doc://x/documentation/ExampleKit/Gone": {"type": "unresolvable", "identifier": "doc://x/documentation/ExampleKit/Gone", "title": "Gone"},
       "https://example.com": {"type": "link", "identifier": "https://example.com", "title": "Example", "titleInlineContent": [{"type": "text", "text": "Example"}], "url": "https://example.com"},
       "figure-1": {"type": "image", "identifier": "figure-1", "alt": "Figure one", "variants": [
         {"url": "/images/figure-1~dark@2x.png", "traits": ["2x", "dark"]},
         {"url": "/images/figure-1.png", "traits": ["1x", "light"]}]},
       "clip-1": {"type": "video", "identifier": "clip-1", "alt": "Clip one", "poster": "figure-1", "variants": [{"url": "/videos/clip-1.mp4", "traits": ["1x", "light"]}]}
     }}
    """

    static func page(_ json: String = symbol) throws -> Page {
        Page(node: try RenderJSONDecoder.makeDecoder().decode(RenderNode.self, from: Data(json.utf8)))
    }

    @Test func theHeaderComesFromMetadata() throws {
        let page = try Self.page()
        #expect(page.title == "Thing")
        #expect(page.roleHeading == "Structure")
        #expect(page.role == "symbol" && page.symbolKind == "struct" && page.standardColor == nil)
        #expect(page.language == "swift")
        #expect(page.platforms == [Platform(name: "iOS", introduced: "13.0", isBeta: true), Platform(name: "macOS", introduced: "10.15", deprecated: "14.0")])
        #expect(page.isBeta == false)
        #expect(page.isDeprecated == true)
    }

    @Test func referencesResolveToTitlesAndTargets() throws {
        let page = try Self.page()
        #expect(page.abstract == [
            Run("A "), Run("thing", .code), Run(" with a "),
            Run("Other", .code, link: "/documentation/examplekit/other"),
            Run(" and Gone"),   // unresolvable, so plain text merged with its neighbour
        ])
    }

    @Test func nestedInlineMarkupFlattensIntoRuns() throws {
        let page = try Self.page()
        guard case .paragraph(let runs)? = page.body.first(where: { if case .paragraph = $0 { true } else { false } }) else {
            Issue.record("no paragraph"); return
        }
        #expect(runs == [
            Run("Plain, "), Run("bold and ", .strong), Run("both", [.strong, .emphasis]), Run(", then "),
            Run("a site", link: "https://example.com"), Run("."),
        ])
    }

    @Test func theBodyIsInReadingOrder() throws {
        let page = try Self.page()
        let kinds = page.body.map { block -> String in
            switch block {
            case .heading(let level, let text, _): "h\(level) \(text)"
            case .paragraph: "paragraph"
            case .code: "code"
            case .declaration: "declaration"
            case .list: "list"
            case .terms: "terms"
            case .table: "table"
            case .aside(let aside): "aside \(aside.name)"
            case .image: "image"
            case .video: "video"
            case .links: "links"
            case .tabs: "tabs"
            case .row: "row"
            case .divider: "divider"
            case .small: "small"
            case .unsupported(let name): "unsupported \(name)"
            }
        }
        #expect(kinds == [
            "aside Deprecated", "declaration", "h2 Parameters", "terms",
            "h2 Overview", "paragraph", "image", "aside Warning", "code", "list", "table", "tabs", "video", "row", "unsupported hologram", "divider",
            "h2 Topics", "h3 Essentials", "links", "h2 See Also", "links",
        ])
    }

    @Test func declarationsKeepTokenKindsAndLinks() throws {
        let page = try Self.page()
        guard case .declaration(let tokens)? = page.body.first(where: { if case .declaration = $0 { true } else { false } }) else {
            Issue.record("no declaration"); return
        }
        #expect(tokens.plainText == "struct Thing: Other")
        #expect(tokens.last == Token("Other", kind: "typeIdentifier", link: "/documentation/examplekit/other"))
        #expect(tokens.first?.kind == "keyword")
    }

    @Test func figuresBecomeImageBlocksWithEveryVariant() throws {
        let page = try Self.page()
        guard case .image(let media)? = page.body.first(where: { if case .image = $0 { true } else { false } }) else {
            Issue.record("no image"); return
        }
        #expect(media.alt == "Figure one")
        #expect(media.caption == [Run("A figure.")])
        #expect(media.variants == [Media.Variant(url: "/images/figure-1.png"), Media.Variant(url: "/images/figure-1~dark@2x.png", isDark: true, scale: 2)])
        #expect(media.defaultVariant?.url == "/images/figure-1.png")
    }

    @Test func videosKeepTheirPosterAndCaption() throws {
        let page = try Self.page()
        guard case .video(let media, let poster)? = page.body.first(where: { if case .video = $0 { true } else { false } }) else {
            Issue.record("no video"); return
        }
        #expect(media.alt == "Clip one")
        #expect(media.caption == [Run("A clip.")])
        #expect(media.variants == [Media.Variant(url: "/videos/clip-1.mp4")])
        #expect(poster?.alt == "Figure one")
    }

    @Test func tablesKeepHeaderAlignmentsAndSpans() throws {
        let page = try Self.page()
        guard case .table(let table)? = page.body.first(where: { if case .table = $0 { true } else { false } }) else {
            Issue.record("no table"); return
        }
        #expect(table.header == .row)
        #expect(table.alignments == [.left, .right])
        #expect(table.rows.count == 2)
        #expect(table.rows[1] == [Table.Cell([.paragraph([Run("wide")])], columnSpan: 2)])
    }

    @Test func listsAndCodeKeepTheirDetails() throws {
        let page = try Self.page()
        #expect(page.body.contains(.code(Code(lines: ["let a = 1", "let b = 2"], language: "swift"))))
        #expect(page.body.contains(.list(List(isOrdered: true, start: 3, items: [[.paragraph([Run("third")])]]))))
        #expect(page.body.contains(.tabs([Tab(title: "One", blocks: [.paragraph([Run("in one")])])])))
        #expect(page.body.contains(.row(Row(columns: [Row.Column(size: 2, blocks: [.paragraph([Run("wide column")])]), Row.Column(size: 1, blocks: [.paragraph([Run("narrow column")])])]))))
        #expect(page.body.contains(.terms([Term(term: [Run("count", .code)], definition: [.paragraph([Run("How many.")])])])))
    }

    @Test func linkSectionsResolveWhatTheyCanAndSkipTheRest() throws {
        let page = try Self.page()
        let links = page.body.compactMap { if case .links(let links) = $0 { links } else { nil } }
        #expect(links.count == 2)
        #expect(links[0].items == [
            Links.Item(title: "Other", link: "/documentation/examplekit/other", abstract: [Run("Another.")], isBeta: true, role: "symbol"),
            Links.Item(title: "Gone", link: nil),
        ])
    }

    @Test func hiddenTopicsAndUnknownSectionsAreReported() throws {
        let json = Self.symbol
            .replacingOccurrences(of: "\"kind\": \"symbol\",", with: "\"kind\": \"symbol\", \"topicSectionsStyle\": \"hidden\",")
            .replacingOccurrences(of: "{\"kind\": \"parameters\",", with: "{\"kind\": \"attributes\", \"title\": \"Attributes\", \"attributes\": []}, {\"kind\": \"mentions\", \"mentions\": [\"doc://x/documentation/ExampleKit/Other\"]}, {\"kind\": \"parameters\",")
        let page = try Self.page(json)
        #expect(!page.body.contains(.heading(level: 2, text: "Topics", anchor: "topics")))
        #expect(!page.body.contains(.unsupported("attributes")), "an attributes section with nothing in it shows nothing")
        #expect(page.body.contains(.heading(level: 2, text: "Mentioned In", anchor: "mentions")))
        #expect(page.body.contains(.heading(level: 2, text: "See Also", anchor: "see-also")))
    }
}

@Suite struct BreadcrumbTests {
    @Test func theHierarchyBecomesParentLinks() throws {
        let json = """
        {"identifier":{"url":"doc://x/documentation/x/leaf","interfaceLanguage":"swift"},"kind":"symbol","schemaVersion":{"major":0,"minor":3,"patch":0},
         "metadata":{"title":"Leaf"},"sections":[],
         "hierarchy":{"paths":[["doc://x/documentation/x","doc://x/documentation/x/mid"]]},
         "references":{"doc://x/documentation/x":{"type":"topic","identifier":"doc://x/documentation/x","title":"X","url":"/documentation/x","kind":"symbol","role":"collection","abstract":[]},
                       "doc://x/documentation/x/mid":{"type":"topic","identifier":"doc://x/documentation/x/mid","title":"Mid","url":"/documentation/x/mid","kind":"symbol","role":"symbol","abstract":[]}}}
        """
        let page = Page(node: try RenderJSONDecoder.makeDecoder().decode(RenderNode.self, from: Data(json.utf8)))
        #expect(page.parents == [Links.Item(title: "X", link: "/documentation/x"), Links.Item(title: "Mid", link: "/documentation/x/mid")])
    }
}

@Suite struct SampleDownloadTests {
    @Test func aSampleCodePageCarriesItsDownload() throws {
        let json = """
        {"identifier":{"url":"doc://x/documentation/x/sample","interfaceLanguage":"swift"},"kind":"article","schemaVersion":{"major":0,"minor":3,"patch":0},
         "metadata":{"title":"Sample","role":"sampleCode"},"sections":[],
         "sampleCodeDownload":{"kind":"sampleDownload","action":{"type":"reference","identifier":"abc/Sample.zip","isActive":true,"overridingTitle":"Download"}},
         "references":{"abc/Sample.zip":{"type":"download","identifier":"abc/Sample.zip","url":"abc/Sample.zip","checksum":null}}}
        """
        let page = Page(node: try RenderJSONDecoder.makeDecoder().decode(RenderNode.self, from: Data(json.utf8)))
        #expect(page.download == Download(title: "Download", url: "abc/Sample.zip"))
    }
}

@Suite struct RESTTests {
    static let endpoint = """
    {"identifier":{"url":"doc://x/documentation/api/get-apps","interfaceLanguage":"data"},"kind":"symbol","schemaVersion":{"major":0,"minor":3,"patch":0},
     "metadata":{"title":"List Apps","roleHeading":"Web Service Endpoint"},"sections":[],
     "primaryContentSections":[
       {"kind":"restEndpoint","title":"URL","tokens":[{"kind":"method","text":"GET"},{"kind":"text","text":" "},{"kind":"baseURL","text":"https://api.example.com/"},{"kind":"path","text":"v1/apps"}]},
       {"kind":"restParameters","title":"Query Parameters","source":"query","items":[
         {"name":"limit","type":[{"kind":"text","text":"integer"}],"required":false,"content":[{"type":"paragraph","inlineContent":[{"type":"text","text":"How many."}]}],"attributes":[{"kind":"maximum","value":"200"},{"kind":"allowedValues","values":["a","b"]}]}]},
       {"kind":"restResponses","title":"Response Codes","items":[
         {"status":200,"reason":"OK","mimeType":"application/json","type":[{"kind":"typeIdentifier","text":"AppsResponse","identifier":"doc://x/documentation/api/appsresponse"}],"content":[{"type":"paragraph","inlineContent":[{"type":"text","text":""}]}]}]},
       {"kind":"properties","title":"Properties","items":[
         {"name":"id","type":[{"kind":"text","text":"string"}],"required":true,"content":[{"type":"paragraph","inlineContent":[{"type":"text","text":"The id."}]}]}]}
     ],
     "references":{"doc://x/documentation/api/appsresponse":{"type":"topic","identifier":"doc://x/documentation/api/appsresponse","title":"AppsResponse","url":"/documentation/api/appsresponse","kind":"symbol","role":"symbol","abstract":[]}}}
    """

    @Test func anEndpointPageHasItsSections() throws {
        let page = Page(node: try RenderJSONDecoder.makeDecoder().decode(RenderNode.self, from: Data(Self.endpoint.utf8)))
        #expect(page.body[0] == .heading(level: 2, text: "URL", anchor: "url"))
        #expect(page.body[1] == .declaration([Token("GET", kind: "keyword"), Token(" ", kind: "text"), Token("https://api.example.com/", kind: "label"), Token("v1/apps", kind: "text")]))
        #expect(page.body[2] == .heading(level: 2, text: "Query Parameters", anchor: "query-parameters"))
        #expect(page.body[3] == .terms([Term(term: [Run("limit", .code)], definition: [
            .paragraph([Run("integer", .code)]),
            .paragraph([Run("How many.")]),
            .paragraph([Run("Maximum:", .strong), Run(" "), Run("200", .code)]),
            .paragraph([Run("Possible Values:", .strong), Run(" "), Run("a", .code), Run(", "), Run("b", .code)]),
        ])]))
        #expect(page.body[5] == .terms([Term(term: [Run("200", .code), Run(" OK")], definition: [
            .paragraph([Run("AppsResponse", .code, link: "/documentation/api/appsresponse")]),
            .small([Run("Content-Type: application/json")]),
        ])]), "a blank paragraph is dropped")
        #expect(page.body[7] == .terms([Term(term: [Run("id", .code)], definition: [.paragraph([Run("string", .code), Run(" (Required)")]), .paragraph([Run("The id.")])])]))
        #expect(!page.body.contains { if case .unsupported = $0 { true } else { false } })
    }
}
