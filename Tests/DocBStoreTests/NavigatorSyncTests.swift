// Navigator sync: the index is fetched conditionally, swapped into rows, read back as a tree,
// and the swap purges exactly the pages it orphaned.

import Foundation
import Testing
import DocBSources
@testable import DocBStore

@Suite struct NavigatorSyncTests {
    @Test func syncBuildsTheTreeAndFetchesNoPagesWhenNotOffline() async throws {
        let fake = FakeTransport()
        fake.set("https://example.com/docs/index/index.json", body: indexJSON(["swift": [("Thing", "struct", "/documentation/examplekit/thing")]]), etag: "v1")
        let library = try makeLibrary(fake)
        try await library.add(docc)
        let events = try await library.sync().collect()
        #expect(events == [.navigatorUpdated(docc), .remaining(0), .finished])

        let tree = try await library.navigator(for: docc, language: "swift")
        #expect(tree.count == 1)
        #expect(tree[0].title == "ExampleKit")
        #expect(tree[0].location == PageLocation(base: base, path: "documentation/examplekit"))
        #expect(tree[0].children.map(\.title) == ["Essentials", "Thing"])
        #expect(tree[0].children[0].type == "groupMarker" && tree[0].children[0].location == nil)
        #expect(tree[0].children[1].location?.path == "documentation/examplekit/thing")
        #expect(fake.requests.count == 1)
        let records = try await library.sources()
        #expect(records.map(\.fetchedPages) == [0] && records.map(\.pendingPages) == [0])
    }

    @Test func unchangedIndexIsA304AndSkipsTheSwap() async throws {
        let fake = FakeTransport()
        fake.set("https://example.com/docs/index/index.json", body: indexJSON(["swift": []]), etag: "v1")
        let clock = Clock()
        let library = try makeLibrary(fake, clock: clock)
        try await library.add(docc)
        _ = try await library.sync().collect()
        clock.advance(2 * 24 * 60 * 60)
        let events = try await library.sync().collect()
        #expect(events.first == .navigatorUnchanged(docc))
        #expect(fake.requests.last?.value(forHTTPHeaderField: "If-None-Match") == "v1")
    }

    @Test func freshNavigatorIsNotRefetched() async throws {
        let fake = FakeTransport()
        fake.set("https://example.com/docs/index/index.json", body: indexJSON(["swift": []]), etag: "v1")
        let library = try makeLibrary(fake)
        try await library.add(docc)
        _ = try await library.sync().collect()
        _ = try await library.sync().collect()
        #expect(fake.requests.count == 1)
    }

    @Test func forcedSyncRefetchesAFreshNavigatorWithoutItsETag() async throws {
        let fake = FakeTransport()
        fake.set("https://example.com/docs/index/index.json", body: indexJSON(["swift": []]), etag: "v1")
        let library = try makeLibrary(fake)
        try await library.add(docc)
        _ = try await library.sync().collect()
        let events = try await library.sync(force: true).collect()
        #expect(fake.requests.count == 2)
        #expect(fake.requests.last?.value(forHTTPHeaderField: "If-None-Match") == nil)
        #expect(events.first == .navigatorUpdated(docc))
    }

    @Test func swapPurgesRemovedPagesButKeepsSharedAndUntouchedOnes() async throws {
        let fake = FakeTransport()
        let index = "https://example.com/docs/index/index.json"
        fake.set(index, body: indexJSON(["swift": [("Old", "struct", "/documentation/examplekit/old"), ("Kept", "struct", "/documentation/examplekit/kept")]]), etag: "v1")
        for name in ["old", "kept", "elsewhere", "examplekit"] {
            fake.set("https://example.com/docs/data/documentation/examplekit/\(name).json", body: pageJSON(title: name, identifier: "doc://x/documentation/ExampleKit/\(name)"))
        }
        fake.set("https://example.com/docs/data/documentation/examplekit.json", body: pageJSON(title: "ExampleKit", identifier: "doc://x/documentation/ExampleKit"))
        let clock = Clock()
        let library = try makeLibrary(fake, clock: clock)
        try await library.add(docc, offline: true)
        _ = try await library.sync().collect()
        // A page reached only through a link, never in a navigator.
        _ = try await library.page(at: PageLocation(base: base, path: "documentation/examplekit/elsewhere"))
        // A second source at the same base still referencing "old".
        let other = Source(base: base, kind: .doccWithoutIndex(root: "documentation/examplekit/old"), title: "Other", languages: ["swift"])
        try await library.add(other)
        _ = try await library.sync().collect()

        fake.set(index, body: indexJSON(["swift": [("Kept", "struct", "/documentation/examplekit/kept")]]), etag: "v2")
        clock.advance(2 * 24 * 60 * 60)
        _ = try await library.sync().collect()

        let stored = try await library.writer.read { db in try Set(String.fetchAll(db, sql: "SELECT path FROM page ORDER BY path")) }
        #expect(stored == ["documentation/examplekit", "documentation/examplekit/elsewhere", "documentation/examplekit/kept", "documentation/examplekit/old"])

        try await library.remove(other)
        let afterRemove = try await library.writer.read { db in try Set(String.fetchAll(db, sql: "SELECT path FROM page ORDER BY path")) }
        #expect(afterRemove == ["documentation/examplekit", "documentation/examplekit/elsewhere", "documentation/examplekit/kept"])
    }

    @Test func removingASourcePurgesItsPages() async throws {
        let fake = FakeTransport()
        fake.set("https://example.com/docs/index/index.json", body: indexJSON(["swift": [("Thing", "struct", "/documentation/examplekit/thing")]]), etag: "v1")
        fake.set("https://example.com/docs/data/documentation/examplekit/thing.json", body: pageJSON(title: "Thing", identifier: "doc://x/documentation/ExampleKit/Thing"))
        fake.set("https://example.com/docs/data/documentation/examplekit.json", body: pageJSON(title: "ExampleKit", identifier: "doc://x/documentation/ExampleKit"))
        let library = try makeLibrary(fake)
        try await library.add(docc, offline: true)
        _ = try await library.sync().collect()
        try await library.remove(docc)
        let counts = try await library.writer.read { db in
            try ["page", "navigator", "navigator_fts", "source"].map { table in
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(table)") ?? -1
            }
        }
        #expect(counts == [0, 0, 0, 0])
        #expect(try await library.sources().isEmpty)
    }

    @Test func navigatorFailureIsReportedAndSyncContinues() async throws {
        let fake = FakeTransport()
        fake.set("https://example.com/docs/index/index.json", status: 500, body: "")
        let library = try makeLibrary(fake)
        try await library.add(docc)
        let events = try await library.sync().collect()
        #expect(events.count == 3)
        if case .navigatorFailed(let source, _) = events[0] { #expect(source == docc) } else { Issue.record("expected navigatorFailed, got \(events[0])") }
    }

    @Test func externalNodesWithBaseRelativePathsStillOpen() async throws {
        let fake = FakeTransport()
        fake.set("https://example.com/docs/index/index.json", body: """
        {"schemaVersion": {"major": 0, "minor": 1, "patch": 2}, "interfaceLanguages": {"swift": [
          {"title": "ExampleKit", "type": "module", "path": "/documentation/examplekit", "children": [
            {"title": "Elsewhere in this host", "type": "article", "path": "/documentation/otherkit/thing", "external": true},
            {"title": "Another host", "type": "article", "path": "https://elsewhere.example.com/documentation/x", "external": true}
          ]}]}}
        """, etag: "v1")
        let library = try makeLibrary(fake)
        try await library.add(docc)
        _ = try await library.sync().collect()
        let children = try await library.navigator(for: docc, language: "swift")[0].children
        #expect(children[0].location == PageLocation(base: base, path: "documentation/otherkit/thing") && children[0].isExternal)
        #expect(children[1].location == nil && children[1].isExternal)
        #expect(try await library.sources(containing: "documentation/otherkit/thing").isEmpty)
        #expect(try await library.sources(containing: "documentation/examplekit") == [docc])
    }

    @Test func languagesAreSeparateTrees() async throws {
        let fake = FakeTransport()
        fake.set("https://example.com/docs/index/index.json", body: indexJSON(["swift": [("Thing", "struct", "/documentation/examplekit/thing")], "occ": [("NSThing", "class", "/documentation/examplekit/nsthing")]]), etag: "v1")
        let library = try makeLibrary(fake)
        try await library.add(docc)
        _ = try await library.sync().collect()
        #expect(try await library.navigator(for: docc, language: "occ")[0].children.map(\.title) == ["Essentials", "NSThing"])
        #expect(try await library.navigator(for: docc, language: "swift")[0].children.map(\.title) == ["Essentials", "Thing"])
    }

    @Test func aSourceWithoutTheLanguageGivesTheTreeItHas() async throws {
        let fake = FakeTransport()
        fake.set("https://example.com/docs/index/index.json", body: indexJSON(["data": [("Payload", "dictionarySymbol", "/documentation/examplekit/payload")]]), etag: "v1")
        let library = try makeLibrary(fake)
        try await library.add(docc)
        _ = try await library.sync().collect()
        #expect(try await library.navigator(for: docc, language: "swift")[0].children.map(\.title) == ["Essentials", "Payload"])
    }
}
