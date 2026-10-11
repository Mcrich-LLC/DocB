// Shape tests for `LineHighlighter.Highlight`: `line` is required, `start`/`length` are optional.

import Testing
@testable import DocCSchema

@Suite struct LineHighlighterTests {
    @Test func decodesMinimalPayload() throws {
        let value = try roundTrip(LineHighlighter.Highlight.self, """
        {"line": 5}
        """)
        #expect(value.line == 5)
        #expect(value.start == nil)
        #expect(value.length == nil)
    }

    @Test func decodesFullPayload() throws {
        let value = try roundTrip(LineHighlighter.Highlight.self, """
        {"line": 10, "start": 2, "length": 6}
        """)
        #expect(value.line == 10)
        #expect(value.start == 2)
        #expect(value.length == 6)
    }

    @Test func missingRequiredKeyThrows() {
        #expect(throws: (any Error).self) {
            try decode(LineHighlighter.Highlight.self, "{}")
        }
    }
}
