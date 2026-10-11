// Markdown from the page model: a whole page as a golden string, and the corners where Markdown
// needs care: escaping, code spans with backticks, tables with spans and no header, nesting.

import Foundation
import Testing
import DocBPage
import DocCSchema
@testable import DocBMarkdown

@Suite struct MarkdownTests {
    @Test func aWholePage() throws {
        let json = """
        {"schemaVersion": {"major": 0, "minor": 3, "patch": 0},
         "identifier": {"url": "doc://x/documentation/ExampleKit/Thing", "interfaceLanguage": "swift"},
         "metadata": {"title": "Thing", "role": "symbol", "roleHeading": "Structure",
           "platforms": [{"name": "iOS", "introducedAt": "13.0", "beta": true}, {"name": "macOS", "introducedAt": "10.15", "deprecatedAt": "14.0"}]},
         "kind": "symbol",
         "abstract": [{"type": "text", "text": "A "}, {"type": "codeVoice", "code": "thing"}, {"type": "text", "text": " with a "},
                      {"type": "reference", "identifier": "doc://x/documentation/ExampleKit/Other", "isActive": true}, {"type": "text", "text": "."}],
         "sections": [],
         "primaryContentSections": [
           {"kind": "declarations", "declarations": [{"platforms": [], "tokens": [{"kind": "keyword", "text": "struct"}, {"kind": "text", "text": " Thing"}]}]},
           {"kind": "parameters", "parameters": [{"name": "count", "content": [{"type": "paragraph", "inlineContent": [{"type": "text", "text": "How many."}]}]}]},
           {"kind": "content", "content": [
             {"type": "heading", "level": 2, "text": "Overview", "anchor": "overview"},
             {"type": "paragraph", "inlineContent": [{"type": "text", "text": "Plain, "}, {"type": "strong", "inlineContent": [{"type": "text", "text": "bold"}]}, {"type": "text", "text": " and "}, {"type": "emphasis", "inlineContent": [{"type": "text", "text": "italic"}]}, {"type": "text", "text": "."}]},
             {"type": "aside", "style": "note", "name": "Note", "content": [{"type": "paragraph", "inlineContent": [{"type": "text", "text": "Careful."}]}, {"type": "paragraph", "inlineContent": [{"type": "text", "text": "Very."}]}]},
             {"type": "codeListing", "syntax": "swift", "code": ["let a = 1", "let b = 2"]},
             {"type": "unorderedList", "items": [{"content": [{"type": "paragraph", "inlineContent": [{"type": "text", "text": "one"}]}]}, {"content": [{"type": "paragraph", "inlineContent": [{"type": "text", "text": "two"}]}]}]},
             {"type": "paragraph", "inlineContent": [{"type": "image", "identifier": "figure-1"}]},
             {"type": "hologram"},
             {"type": "thematicBreak"}]}
         ],
         "topicSections": [{"title": "Essentials", "identifiers": ["doc://x/documentation/ExampleKit/Other"]}],
         "references": {
           "doc://x/documentation/ExampleKit/Other": {"type": "topic", "identifier": "doc://x/documentation/ExampleKit/Other", "title": "Other", "url": "/documentation/examplekit/other", "kind": "symbol", "role": "symbol", "abstract": [{"type": "text", "text": "Another."}], "beta": true},
           "figure-1": {"type": "image", "identifier": "figure-1", "alt": "Figure one", "variants": [{"url": "/images/figure-1.png", "traits": ["1x", "light"]}]}
         }}
        """
        let page = Page(node: try RenderJSONDecoder.makeDecoder().decode(RenderNode.self, from: Data(json.utf8)))
        #expect(Markdown.render(page) == """
        # Thing

        *Structure*

        A `thing` with a [`Other`](/documentation/examplekit/other).

        **Availability:** iOS 13.0+ (Beta) · macOS 10.15–14.0

        ```swift
        struct Thing
        ```

        ## Parameters

        - **`count`**: How many.

        ## Overview

        Plain, **bold** and *italic*.

        > [!NOTE]
        > Careful.
        >
        > Very.

        ```swift
        let a = 1
        let b = 2
        ```

        - one
        - two

        ![Figure one](/images/figure-1.png)

        <!-- unsupported: hologram -->

        ---

        ## Topics

        ### Essentials

        - [Other](/documentation/examplekit/other) *Beta*: Another.

        """)
    }

    @Test func markupInTextIsEscaped() {
        #expect(Markdown.inline([Run("a * b_c [d] <e> `f`")]) == "a \\* b\\_c \\[d\\] \\<e\\> \\`f\\`")
        #expect(Markdown.inline([Run("# not a heading")]) == "\\# not a heading")
        #expect(Markdown.inline([Run("1. not a list")]) == "1\\. not a list")
        #expect(Markdown.inline([Run("10) still not")]) == "10\\) still not")
        #expect(Markdown.inline([Run("- nor this")]) == "\\- nor this")
    }

    @Test func codeSpansSurviveBackticks() {
        #expect(Markdown.inline([Run("a`b", .code)]) == "``a`b``")
        #expect(Markdown.inline([Run("`quoted`", .code)]) == "`` `quoted` ``")
        #expect(Markdown.inline([Run("x", [.code, .strong], link: "/x")]) == "[**`x`**](/x)")
        #expect(Markdown.render(.code(Code(lines: ["```", "inner"], language: "md")), language: nil) == "````md\n```\ninner\n````")
    }

    @Test func stylesNestInAFixedOrder() {
        #expect(Markdown.inline([Run("all", [.emphasis, .strong, .strikethrough])]) == "~~***all***~~")
        #expect(Markdown.inline([Run("2", .superscript), Run("n", .subscript)]) == "<sup>2</sup><sub>n</sub>")
    }

    @Test func tablesGetHeadersSpansAndAlignment() {
        let table = Table(header: .row, alignments: [.left, .right], rows: [
            [Table.Cell([.paragraph([Run("Name")])]), Table.Cell([.paragraph([Run("a | b")])])],
            [Table.Cell([.paragraph([Run("wide")])], columnSpan: 2)],
            [Table.Cell([.paragraph([Run("tall")])], rowSpan: 2), Table.Cell([.paragraph([Run("x")]), .code(Code(lines: ["y | z"]))])],
            [Table.Cell([.list(List(isOrdered: false, items: [[.paragraph([Run("p")])], [.paragraph([Run("q")])]]))])],
        ])
        #expect(Markdown.render(.table(table), language: nil) == """
        | Name | a \\| b |
        | :-- | --: |
        | wide |  |
        | tall | x<br>`y \\| z` |
        |  | p<br>q |
        """)
        let headless = Table(header: .none, rows: [[Table.Cell([.paragraph([Run("only")])])]])
        #expect(Markdown.render(.table(headless), language: nil) == "|  |\n| --- |\n| only |")
    }

    @Test func nestedBlocksAreIndentedUnderTheirMarker() {
        let list = List(isOrdered: true, start: 3, items: [
            [.paragraph([Run("first")]), .code(Code(lines: ["x"]))],
            [.list(List(isOrdered: false, items: [[.paragraph([Run("inner")])]]))],
        ])
        #expect(Markdown.render(.list(list), language: nil) == """
        3. first

           ```
           x
           ```

        4. - inner
        """)
        let terms = [Term(term: [Run("k", .code)], definition: [.paragraph([Run("one")]), .paragraph([Run("two")])])]
        #expect(Markdown.render(.terms(terms), language: nil) == "- **`k`**\n\n  one\n\n  two")
        let aside = Aside(kind: .tip, blocks: [.list(List(isOrdered: false, items: [[.paragraph([Run("a")])]]))])
        #expect(Markdown.render(.aside(aside), language: nil) == "> [!TIP]\n> - a")
        let named = Aside(kind: .note, name: "Precondition", blocks: [.paragraph([Run("x > 0")])])
        #expect(Markdown.render(.aside(named), language: nil) == "> [!NOTE]\n> **Precondition**\n>\n> x \\> 0")
    }

    @Test func linksAndMediaWithoutTargetsStillRead() {
        #expect(Markdown.render(.links(Links(items: [Links.Item(title: "Gone", link: nil, isDeprecated: true)])), language: nil) == "- Gone *Deprecated*")
        let video = Media(variants: [Media.Variant(url: "/v.mp4")], alt: "Clip", caption: [Run("Watch.")])
        #expect(Markdown.render(.video(video, poster: nil), language: nil) == "[Video: Clip](/v.mp4)\n\n*Watch.*")
        #expect(Markdown.render(.tabs([Tab(title: "Swift", blocks: [.paragraph([Run("s")])])]), language: nil) == "**Swift**\n\ns")
        #expect(Markdown.render(.row(Row(columns: [Row.Column(blocks: [.paragraph([Run("a")])]), Row.Column(blocks: [.paragraph([Run("b")])])])), language: nil) == "a\n\nb")
        #expect(Markdown.render(.declaration([Token("- (void)go", kind: "text")]), language: "occ") == "```objc\n- (void)go\n```")
    }
}
