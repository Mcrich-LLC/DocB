// Index-less sources: the navigator is built by walking topic sections from the root page,
// storing every page reached, with cycles and off-base links ignored.

import Foundation
import Testing
import DocBSources
@testable import DocBStore

@Suite struct CrawlTests {
    @Test func crawlBuildsNavigatorAndStoresPages() async throws {
        let fake = FakeTransport()
        let data = "https://example.com/docs/data/documentation/examplekit"
        fake.set("\(data).json", body: pageJSON(title: "Example Kit", identifier: "doc://x/documentation/ExampleKit", topics: [
            ("doc://x/documentation/ExampleKit/Thing", "/documentation/examplekit/thing"),
            ("doc://x/documentation/ExampleKit/Other", "/documentation/examplekit/other"),
            ("doc://elsewhere/documentation/Far", "https://elsewhere.example.com/documentation/far"),
        ], role: "collection"))
        fake.set("\(data)/thing.json", body: pageJSON(title: "Thing", identifier: "doc://x/documentation/ExampleKit/Thing", topics: [
            ("doc://x/documentation/ExampleKit/Thing/init()", "/documentation/examplekit/thing/init()"),
            ("doc://x/documentation/ExampleKit", "/documentation/examplekit"),   // a cycle back to the root
        ]))
        fake.set("\(data)/thing/init().json", body: pageJSON(title: "init()", identifier: "doc://x/documentation/ExampleKit/Thing/init()"))
        fake.set("\(data)/other.json", body: pageJSON(title: "Other", identifier: "doc://x/documentation/ExampleKit/Other"))
        let source = Source(base: base, kind: .doccWithoutIndex(root: "documentation/examplekit"), title: "Example Kit", languages: ["swift"])
        let library = try makeLibrary(fake)
        try await library.add(source)
        let events = try await library.sync().collect()
        #expect(events.contains(.navigatorUpdated(source)))

        let tree = try await library.navigator(for: source, language: "swift")
        #expect(tree.map(\.title) == ["Example Kit"])
        #expect(tree[0].type == "collection")
        let topics = tree[0].children
        #expect(topics.map(\.title) == ["Topics"])
        #expect(topics[0].children.map(\.title) == ["Thing", "Other"])
        #expect(topics[0].children[0].children[0].children.map(\.title) == ["init()"])
        #expect(topics[0].children[0].location?.path == "documentation/examplekit/thing")

        let record = try await library.sources()[0]
        #expect(record.fetchedPages == 4)
        #expect(fake.requests.count == 4)
        #expect(try await library.page(at: PageLocation(base: base, path: "documentation/examplekit/thing/init()")).metadata.title == "init()")
    }
}
