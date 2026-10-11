// Shape and URL-rule tests for Source: index URLs per layout, origin sharing, and coding.

import Foundation
import Testing
@testable import DocBSources

@Suite struct SourceTests {
    let base = URL(string: "https://example.com/docs")!

    @Test func doccNavigatorIsTheIndexFile() {
        let source = Source(base: base, kind: .docc, title: "Example Kit", languages: ["swift"])
        #expect(source.navigator == .index(URL(string: "https://example.com/docs/index/index.json")!))
    }

    @Test func appleDeveloperNavigatorIsExtensionless() {
        let source = Source(base: base, kind: .appleDeveloper(module: "examplekit"), title: "Example Kit", languages: ["swift"])
        #expect(source.navigator == .index(URL(string: "https://example.com/docs/tutorials/data/index/examplekit")!))
    }

    @Test func indexlessNavigatorIsACrawlFromTheRoot() {
        let source = Source(base: base, kind: .doccWithoutIndex(root: "documentation/examplekit"), title: "Example Kit", languages: ["swift"])
        #expect(source.navigator == .crawl(root: PageLocation(base: base, path: "documentation/examplekit")))
    }

    @Test func dataURLPerKind() {
        let location = PageLocation(base: base, path: "documentation/examplekit/thing", fragment: "overview")
        #expect(Source(base: base, kind: .docc, title: "", languages: []).dataURL(for: location).absoluteString == "https://example.com/docs/data/documentation/examplekit/thing.json")
        #expect(Source(base: base, kind: .doccWithoutIndex(root: "documentation/examplekit"), title: "", languages: []).dataURL(for: location).absoluteString == "https://example.com/docs/data/documentation/examplekit/thing.json")
        #expect(Source(base: base, kind: .appleDeveloper(module: "examplekit"), title: "", languages: []).dataURL(for: location).absoluteString == "https://example.com/docs/tutorials/data/documentation/examplekit/thing.json")
    }

    @Test func sharesOriginRequiresSameBaseAndLayoutKind() {
        let a = Source(base: base, kind: .appleDeveloper(module: "a"), title: "A", languages: [])
        let b = Source(base: base, kind: .appleDeveloper(module: "b"), title: "B", languages: [])
        let c = Source(base: base, kind: .docc, title: "C", languages: [])
        let d = Source(base: URL(string: "https://other.example.com")!, kind: .appleDeveloper(module: "a"), title: "A", languages: [])
        let e = Source(base: base, kind: .doccWithoutIndex(root: "documentation/c"), title: "C", languages: [])
        #expect(a.sharesOrigin(with: b))
        #expect(!a.sharesOrigin(with: c))
        #expect(!a.sharesOrigin(with: d))
        #expect(c.sharesOrigin(with: e))
    }

    @Test func roundTripsThroughCodable() throws {
        let source = Source(base: base, kind: .appleDeveloper(module: "examplekit"), title: "Example Kit", languages: ["swift", "occ"], tags: ["Tag"])
        let data = try JSONEncoder().encode(source)
        #expect(try JSONDecoder().decode(Source.self, from: data) == source)
    }
}
