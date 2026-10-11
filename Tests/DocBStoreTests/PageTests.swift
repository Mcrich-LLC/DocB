// Pages: offline drain, cache-as-you-go reads, stale-while-revalidate, 404 and error handling,
// row claims, and revalidation after an index change.

import Foundation
import Testing
import DocBSources
@testable import DocBStore

@Suite struct PageTests {
    let index = "https://example.com/docs/index/index.json"
    let thing = PageLocation(base: base, path: "documentation/examplekit/thing")
    let thingURL = "https://example.com/docs/data/documentation/examplekit/thing.json"
    let rootURL = "https://example.com/docs/data/documentation/examplekit.json"

    func fakeWithPages() -> FakeTransport {
        let fake = FakeTransport()
        fake.set(index, body: indexJSON(["swift": [("Thing", "struct", "/documentation/examplekit/thing")]]), etag: "idx1")
        fake.set(rootURL, body: pageJSON(title: "ExampleKit", identifier: "doc://x/documentation/ExampleKit"), etag: "root1")
        fake.set(thingURL, body: pageJSON(title: "Thing", identifier: "doc://x/documentation/ExampleKit/Thing"), etag: "thing1")
        return fake
    }

    @Test func offlineSourceDrainsEveryNavigatorPage() async throws {
        let fake = fakeWithPages()
        let library = try makeLibrary(fake)
        try await library.add(docc, offline: true)
        let events = try await library.sync().collect()
        #expect(events.contains(.pageFetched(thing)))
        #expect(events.contains(.pageFetched(PageLocation(base: base, path: "documentation/examplekit"))))
        #expect(events.last == .finished && events.dropLast().last == .remaining(0))
        let record = try await library.sources()[0]
        #expect(record.fetchedPages == 2 && record.pendingPages == 0)
        #expect(record.storedBytes > 0)
        let node = try await library.page(at: thing)
        #expect(node.metadata.title == "Thing")
        #expect(fake.requestCount(for: thingURL) == 1)
    }

    @Test func readFetchesAndStoresAnUnknownPage() async throws {
        let fake = fakeWithPages()
        let library = try makeLibrary(fake)
        try await library.add(docc)
        _ = try await library.sync().collect()
        let first = try await library.page(at: thing)
        let second = try await library.page(at: thing)
        #expect(first.metadata.title == "Thing" && second.metadata.title == "Thing")
        #expect(fake.requestCount(for: thingURL) == 1)
    }

    @Test func readOfUnknownBaseThrows() async throws {
        let library = try makeLibrary(FakeTransport())
        await #expect(throws: StoreError.unknownBase(base)) {
            try await library.page(at: thing)
        }
    }

    @Test func readOfMissingPageThrowsNotFound() async throws {
        let fake = fakeWithPages()
        let library = try makeLibrary(fake)
        try await library.add(docc)
        let missing = PageLocation(base: base, path: "documentation/examplekit/nope")
        await #expect(throws: StoreError.pageNotFound(missing, status: 404)) {
            try await library.page(at: missing)
        }
    }

    @Test func staleReadReturnsStoredPageAndRevalidatesInBackground() async throws {
        let fake = fakeWithPages()
        let clock = Clock()
        let library = try makeLibrary(fake, clock: clock)
        try await library.add(docc)
        _ = try await library.page(at: thing)
        clock.advance(2 * 24 * 60 * 60)
        fake.set(thingURL, body: pageJSON(title: "Thing v2", identifier: "doc://x/documentation/ExampleKit/Thing"), etag: "thing2")

        let updated = Confirmation()
        await library.setEventHandler { event in if event == .pageUpdated(thing) { updated.signal() } }
        let stale = try await library.page(at: thing)
        #expect(stale.metadata.title == "Thing")
        try await updated.wait()
        #expect(fake.requests.last?.value(forHTTPHeaderField: "If-None-Match") == "thing1")
        #expect(try await library.page(at: thing).metadata.title == "Thing v2")
    }

    @Test func revalidationWith304OnlyTouchesTheRow() async throws {
        let fake = fakeWithPages()
        let clock = Clock()
        let library = try makeLibrary(fake, clock: clock)
        try await library.add(docc, offline: true)
        _ = try await library.sync().collect()
        clock.advance(2 * 24 * 60 * 60)
        fake.set(index, body: indexJSON(["swift": [("Thing", "struct", "/documentation/examplekit/thing")]]), etag: "idx1")
        let events = try await library.sync().collect()
        #expect(events.contains(.navigatorUnchanged(docc)))
        #expect(events.contains(.pageUnchanged(thing)))
        #expect(!events.contains(.pageUpdated(thing)))
        #expect(fake.requestCount(for: thingURL) == 2)
    }

    @Test func indexChangeFlagsEveryFetchedPageForRevalidation() async throws {
        let fake = fakeWithPages()
        let clock = Clock()
        let library = try makeLibrary(fake, clock: clock)
        try await library.add(docc, offline: true)
        _ = try await library.sync().collect()
        // Same paths, new ETag: titles unchanged but the page may have been edited.
        fake.set(index, body: indexJSON(["swift": [("Thing", "struct", "/documentation/examplekit/thing")]]), etag: "idx2")
        fake.set(thingURL, body: pageJSON(title: "Thing edited", identifier: "doc://x/documentation/ExampleKit/Thing"), etag: "thing2")
        clock.advance(2 * 24 * 60 * 60)
        let events = try await library.sync().collect()
        #expect(events.contains(.navigatorUpdated(docc)))
        #expect(events.contains(.pageUpdated(thing)))
        #expect(try await library.page(at: thing).metadata.title == "Thing edited")
    }

    @Test func missingPendingPageIsMarkedMissingAndNotRetried() async throws {
        let fake = fakeWithPages()
        fake.remove(thingURL)
        let library = try makeLibrary(fake)
        try await library.add(docc, offline: true)
        let events = try await library.sync().collect()
        #expect(events.contains(.pageMissing(thing)))
        _ = try await library.sync().collect()
        #expect(fake.requestCount(for: thingURL) == 1)
        let status = try await library.writer.read { db in try String.fetchOne(db, sql: "SELECT status FROM page WHERE path = ?", arguments: [thing.path]) }
        #expect(status == "missing")
    }

    @Test func missingOnRevalidationKeepsTheStoredBody() async throws {
        let fake = fakeWithPages()
        let clock = Clock()
        let library = try makeLibrary(fake, clock: clock)
        try await library.add(docc, offline: true)
        _ = try await library.sync().collect()
        fake.remove(thingURL)
        fake.set(index, body: indexJSON(["swift": [("Thing", "struct", "/documentation/examplekit/thing")]]), etag: "idx2")
        clock.advance(2 * 24 * 60 * 60)
        let events = try await library.sync().collect()
        #expect(events.contains(.pageMissing(thing)))
        #expect(try await library.page(at: thing).metadata.title == "Thing")
    }

    @Test func transportErrorsBackOffAndRestAfterTheCap() async throws {
        let fake = fakeWithPages()
        let clock = Clock()
        let library = try makeLibrary(fake, clock: clock)
        try await library.add(docc, offline: true)
        _ = try await library.sync().collect()
        clock.advance(24 * 60 * 60 + 1)              // pages are now stale
        fake.failing = true
        func failures() async throws -> Int {
            try await library.sync().collect().filter { if case .pageFailed = $0 { return true } else { return false } }.count
        }
        #expect(try await failures() == 2)           // both pages attempted once
        #expect(try await failures() == 0)           // inside the 10s backoff
        for _ in 2...5 {
            clock.advance(200)
            #expect(try await failures() == 2)
        }
        clock.advance(200)
        #expect(try await failures() == 0)           // capped: resting for a full stale period
        clock.advance(24 * 60 * 60)
        #expect(try await failures() == 2)           // and retried after it
        fake.failing = false
        // The stored body survived every failed revalidation.
        #expect(try await library.page(at: thing).metadata.title == "Thing")
    }

    @Test func claimsAreDisjointAndExpire() async throws {
        let fake = fakeWithPages()
        let clock = Clock()
        let library = try makeLibrary(fake, clock: clock)
        try await library.add(docc, offline: true)
        try await library.syncNavigator(try await library.writer.read { db in try SourceRow.fetchOne(db, key: docc.storeID)! }, source: docc, force: false) { _ in }
        let first = try await library.claim()
        let second = try await library.claim()
        #expect(first.count == 2 && second.isEmpty)
        clock.advance(121)
        #expect(try await library.claim().count == 2)
    }

    @Test func budgetStopsTheDrainEarly() async throws {
        let fake = fakeWithPages()
        let clock = Clock()
        let library = try makeLibrary(fake, clock: clock)
        try await library.add(docc, offline: true)
        let events = try await library.sync(budget: .seconds(0)).collect()
        #expect(events.contains(.remaining(2)))
    }

    @Test func aPageReadsInALanguageItHasAVariantFor() async throws {
        let fake = fakeWithPages()
        let body = pageJSON(title: "Thing", identifier: "doc://x/documentation/ExampleKit/Thing")
            .replacingOccurrences(of: "\"kind\": \"symbol\",", with: """
            "kind": "symbol",
             "variants": [{"traits": [{"interfaceLanguage": "occ"}], "paths": ["/documentation/examplekit/thing"]}],
             "variantOverrides": [{"traits": [{"interfaceLanguage": "occ"}], "patch": [{"op": "replace", "path": "/metadata/title", "value": "EKThing"}]}],
            """)
        fake.set(thingURL, body: body, etag: "thing1")
        let library = try makeLibrary(fake)
        try await library.add(docc)
        let swift = try await library.page(at: thing, language: "swift")
        #expect(swift.metadata.title == "Thing")
        #expect(swift.availableLanguages == ["occ", "swift"])
        let occ = try await library.page(at: thing, language: "occ")
        #expect(occ.metadata.title == "EKThing")
        // A language the page lacks: as authored.
        #expect(try await library.page(at: thing, language: "data").metadata.title == "Thing")
    }

}

/// A one-shot signal for awaiting a background event.
final class Confirmation: @unchecked Sendable {
    private let stream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation
    init() { (stream, continuation) = AsyncStream.makeStream() }
    func signal() { continuation.yield() }
    func wait() async throws {
        for await _ in stream { return }
    }
}

@Suite struct AssetTests {
    @Test func anAssetIsFetchedOnceAndKept() async throws {
        let fake = FakeTransport()
        fake.set("https://example.com/docs/index/index.json", body: indexJSON([:]), etag: "idx1")
        fake.set("https://example.com/docs/images/a.png", body: "PNG")
        let library = try makeLibrary(fake)
        try await library.add(docc)
        let first = try await library.asset("/images/a.png", base: base)
        let second = try await library.asset("images/a.png", base: base)
        #expect(first == Data("PNG".utf8) && second == first)
        #expect(fake.requestCount(for: "https://example.com/docs/images/a.png") == 1)
        await #expect(throws: StoreError.assetNotFound(URL(string: "https://example.com/docs/images/b.png")!, status: 404)) {
            try await library.asset("images/b.png", base: base)
        }
    }
}
