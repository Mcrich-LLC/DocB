// Discovery tests: candidate bases from pasted URLs, probe order, the catalog walk, the
// static-site case, and the error listing every URL tried. All over a fake transport.

import Foundation
import Testing
@testable import DocBSources

@Suite struct DiscoveryTests {
    @Test func candidatesStripPageAndWalkToRoot() {
        let pasted = URL(string: "https://example.com/owner/pkg/main/documentation/examplekit/thing?language=objc#anchor")!
        #expect(Discovery.candidates(for: pasted).map(\.absoluteString) == [
            "https://example.com/owner/pkg/main",
            "https://example.com/owner/pkg",
            "https://example.com/owner",
            "https://example.com",
        ])
    }

    @Test func candidatesKeepPathCase() {
        #expect(Discovery.candidates(for: URL(string: "https://example.com/CareKit/Documentation/carekit/")!).first?.absoluteString == "https://example.com/CareKit")
    }

    @Test func candidatesForRootAndForJSONURL() {
        #expect(Discovery.candidates(for: URL(string: "https://example.com/")!).map(\.absoluteString) == ["https://example.com"])
        #expect(Discovery.candidates(for: URL(string: "https://example.com/docs/data/documentation/x.json")!).first?.absoluteString == "https://example.com/docs")
    }

    @Test func catalogYieldsOneSourcePerModuleWithNestedEntriesFolded() async throws {
        let fake = FakeTransport([
            "https://example.com/tutorials/data/documentation/technologies.json": catalogJSON([
                ("Deep Thing", "doc://com.example/documentation/ExampleKit/deep-thing", ["swift"]),
                ("Example Kit", "doc://com.example/documentation/ExampleKit", ["occ", "swift"]),
                ("Other Kit", "doc://com.example/documentation/OtherKit", ["swift"]),
                ("Elsewhere", "https://elsewhere.example.com/documentation/x", []),
            ]),
        ])
        let sources = try await Discovery.discover(URL(string: "https://example.com/documentation/examplekit")!, transport: fake.transport)
        #expect(sources.map(\.kind) == [.appleDeveloper(module: "examplekit"), .appleDeveloper(module: "otherkit")])
        #expect(sources.first?.title == "Example Kit")
        #expect(sources.first?.languages == ["occ", "swift"])
        #expect(sources.first?.tags == ["Example Tag"])
        #expect(sources.allSatisfy { $0.base.absoluteString == "https://example.com" })
        #expect(fake.requested.count == 1)
    }

    @Test func staticSiteYieldsOneSourceAtTheDeepestBaseThatHasAnIndex() async throws {
        let fake = FakeTransport([
            "https://example.com/owner/pkg/main/index/index.json": indexJSON(languages: ["swift": ["ExampleKit", "OtherKit"], "occ": ["ExampleKit"]]),
        ])
        let sources = try await Discovery.discover(URL(string: "https://example.com/owner/pkg/main/documentation/examplekit")!, transport: fake.transport)
        #expect(sources == [Source(base: URL(string: "https://example.com/owner/pkg/main")!, kind: .docc, title: "ExampleKit, OtherKit", languages: ["occ", "swift"])])
        #expect(fake.requested.map(\.absoluteString) == [
            "https://example.com/owner/pkg/main/tutorials/data/documentation/technologies.json",
            "https://example.com/owner/pkg/main/index/index.json",
        ])
        #expect(sources[0].navigator == .index(URL(string: "https://example.com/owner/pkg/main/index/index.json")!))
    }

    @Test func indexlessSiteIsFoundThroughMetadataAndRootPage() async throws {
        let fake = FakeTransport([
            "https://example.com/ExampleKit/metadata.json": metadataJSON(name: "ExampleKit"),
            "https://example.com/ExampleKit/data/documentation/examplekit.json": pageJSON(identifier: "doc://com.example.ExampleKit/documentation/ExampleKit"),
        ])
        let sources = try await Discovery.discover(URL(string: "https://example.com/ExampleKit/documentation/examplekit/")!, transport: fake.transport)
        #expect(sources == [Source(base: URL(string: "https://example.com/ExampleKit")!, kind: .doccWithoutIndex(root: "documentation/examplekit"), title: "ExampleKit", languages: ["swift"])])
        #expect(sources[0].navigator == .crawl(root: PageLocation(base: URL(string: "https://example.com/ExampleKit")!, path: "documentation/examplekit")))
    }

    @Test func indexlessSiteRootComesFromMetadataWhenTheURLHasNoPage() async throws {
        let fake = FakeTransport([
            "https://example.com/metadata.json": metadataJSON(name: "ExampleKit"),
            "https://example.com/data/documentation/examplekit.json": pageJSON(identifier: "doc://com.example.ExampleKit/documentation/ExampleKit"),
        ])
        let sources = try await Discovery.discover(URL(string: "https://example.com")!, transport: fake.transport)
        #expect(sources.first?.kind == .doccWithoutIndex(root: "documentation/examplekit"))
    }

    @Test func metadataWithoutARootPageIsAMiss() async {
        let fake = FakeTransport(["https://example.com/metadata.json": metadataJSON(name: "ExampleKit")])
        await #expect(throws: DiscoveryError.self) {
            try await Discovery.discover(URL(string: "https://example.com")!, transport: fake.transport)
        }
        #expect(fake.requested.last?.absoluteString == "https://example.com/data/documentation/examplekit.json")
    }

    @Test func undecodableBodyIsAMiss() async throws {
        let fake = FakeTransport([
            "https://example.com/index/index.json": "<html>not json</html>",
        ])
        await #expect(throws: DiscoveryError.self) {
            try await Discovery.discover(URL(string: "https://example.com")!, transport: fake.transport)
        }
    }

    @Test func errorListsEveryURLTried() async {
        let fake = FakeTransport([:])
        do {
            _ = try await Discovery.discover(URL(string: "https://example.com/a")!, transport: fake.transport)
            Issue.record("expected DiscoveryError")
        } catch let error as DiscoveryError {
            #expect(error.tried.map(\.absoluteString) == [
                "https://example.com/a/tutorials/data/documentation/technologies.json",
                "https://example.com/a/index/index.json",
                "https://example.com/a/metadata.json",
                "https://example.com/tutorials/data/documentation/technologies.json",
                "https://example.com/index/index.json",
                "https://example.com/metadata.json",
            ])
        } catch {
            Issue.record("unexpected \(error)")
        }
    }

    @Test func transportFailuresPropagate() async {
        let failing = Transport { _ in throw URLError(.notConnectedToInternet) }
        await #expect(throws: URLError.self) {
            try await Discovery.discover(URL(string: "https://example.com")!, transport: failing)
        }
    }
}
