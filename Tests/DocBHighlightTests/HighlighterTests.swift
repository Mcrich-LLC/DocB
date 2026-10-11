import DocBHighlight
import Testing

@MainActor struct HighlighterTests {
    @Test func swiftTokenizesAsOnTheWeb() {
        let tokens = Highlighter.tokens(for: "@objc class Foo {\n    func f(a b: Int) {}\n}", language: "swift")
        #expect(tokens.map(\.text).joined() == "@objc class Foo {\n    func f(a b: Int) {}\n}")
        #expect(tokens.first == SyntaxToken("@objc", scopes: ["keyword"]), "meta takes the keyword color in Swift")
        #expect(tokens.contains(SyntaxToken("class", scopes: ["keyword"])), "the class span around the line is transparent")
        #expect(tokens.contains(SyntaxToken("a", scopes: ["params"])))
        #expect(tokens.contains(SyntaxToken("b", scopes: [])), "an internal parameter name has no color")
        #expect(tokens.contains(SyntaxToken("Int", scopes: ["type"])))
    }

    @Test func aliasesAndUnknownLanguages() {
        #expect(Highlighter.tokens(for: "@interface A", language: "occ").first == SyntaxToken("@interface", scopes: ["class", "keyword"]), "occ is Objective-C")
        #expect(Highlighter.tokens(for: "{\"k\": 1}", language: "json").contains(SyntaxToken("\"k\"", scopes: ["string"])), "JSON keys take the string color")
        #expect(Highlighter.tokens(for: "kernel void f() {}", language: "metal") == [SyntaxToken("kernel void f() {}")])
        #expect(Highlighter.tokens(for: "x", language: nil) == [SyntaxToken("x")])
    }

    @Test func entitiesComeBackAsText() {
        let tokens = Highlighter.tokens(for: "let s = \"a < b && c\"", language: "swift")
        #expect(tokens.map(\.text).joined() == "let s = \"a < b && c\"")
    }
}
