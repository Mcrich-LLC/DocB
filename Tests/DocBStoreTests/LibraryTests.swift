// Source management: ordering, duplicates.

import Foundation
import Testing
import DocBSources
@testable import DocBStore

@Suite struct LibraryTests {
    @Test func sourcesAreSortedByTitleIgnoringCase() async throws {
        let library = try makeLibrary(FakeTransport())
        let base = URL(string: "https://example.com")!
        for (module, title) in [("z", "zeta"), ("a", "Alpha"), ("m", "mid")] {
            try await library.add(Source(base: base, kind: .appleDeveloper(module: module), title: title, languages: []))
        }
        #expect(try await library.sources().map(\.source.title) == ["Alpha", "mid", "zeta"])
    }

    @Test func addingTheSameSourceTwiceThrowsAndKeepsTheOriginal() async throws {
        let library = try makeLibrary(FakeTransport())
        try await library.add(docc, offline: true)
        var renamed = docc
        renamed.title = "Renamed"
        await #expect(throws: StoreError.duplicateSource(renamed)) {
            try await library.add(renamed)
        }
        let records = try await library.sources()
        #expect(records.map(\.source.title) == ["Example Kit"] && records[0].offline)
    }
}
