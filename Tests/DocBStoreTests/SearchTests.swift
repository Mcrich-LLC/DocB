// Search: trigram substring matches, ranking of exact and prefix hits, language filtering,
// group markers excluded, and the short-query fallback.

import Foundation
import Testing
import DocBSources
@testable import DocBStore

@Suite struct SearchTests {
    func library() async throws -> Library {
        let fake = FakeTransport()
        fake.set("https://example.com/docs/index/index.json", body: indexJSON([
            "swift": [
                ("View", "protocol", "/documentation/examplekit/view"),
                ("ViewModifier", "protocol", "/documentation/examplekit/viewmodifier"),
                ("ScrollView", "struct", "/documentation/examplekit/scrollview"),
                ("Previewing your app", "article", "/documentation/examplekit/previewing"),
                ("Essentials of views", "groupMarker", "/documentation/examplekit/essentials"),
            ],
            "occ": [("NSView", "class", "/documentation/examplekit/nsview")],
        ]), etag: "v1")
        let library = try makeLibrary(fake)
        try await library.add(docc)
        _ = try await library.sync().collect()
        return library
    }

    @Test func exactThenPrefixThenSubstring() async throws {
        let hits = try await library().search("view")
        #expect(hits.map(\.title) == ["View", "ViewModifier", "NSView", "ScrollView", "Previewing your app"])
        #expect(hits[0].location == PageLocation(base: base, path: "documentation/examplekit/view"))
        #expect(hits[0].source == docc && hits[0].type == "protocol" && hits[0].language == "swift")
    }

    @Test func languageFilter() async throws {
        let hits = try await library().search("view", language: "occ")
        #expect(hits.map(\.title) == ["NSView"])
    }

    @Test func groupMarkersAreExcludedAndLimitApplies() async throws {
        let hits = try await library().search("view", limit: 2)
        #expect(hits.map(\.title) == ["View", "ViewModifier"])
        #expect(!(try await library().search("essentials").contains { $0.type == "groupMarker" }))
    }

    @Test func shortQueriesFallBackToSubstringMatching() async throws {
        let hits = try await library().search("ns")
        #expect(hits.map(\.title) == ["NSView"])
    }

    @Test func quotesInQueriesAreSafe() async throws {
        #expect(try await library().search("\"vi\" OR x").isEmpty)
        #expect(try await library().search("   ").isEmpty)
    }
}
