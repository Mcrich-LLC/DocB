// `docb sync`: revalidate navigators and drain pending pages, printing a running summary.

import ArgumentParser
import Foundation
import DocBSources
import DocBStore

struct SyncCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "sync", abstract: "Refresh navigators and download pending pages.")

    @Option(name: .shortAndLong, help: "Stop after this many seconds; pending pages resume next time.")
    var budget: Int?

    @Option(name: .shortAndLong, help: "Sync only this source.")
    var source: String?

    @OptionGroup var options: LibraryOptions

    func run() async throws {
        let library = try options.open()
        var only: Source?
        if let source { only = try await library.source(matching: source) }
        try await report(library.sync(only: only, budget: budget.map { .seconds($0) }))
    }
}

/// Prints sync events as they arrive and a summary at the end.
func report(_ events: AsyncThrowingStream<SyncEvent, any Error>) async throws {
    var fetched = 0, updated = 0, unchanged = 0, missing = 0, failed = 0
    for try await event in events {
        switch event {
        case .navigatorUpdated(let source): print("Navigator updated: \(source.title)")
        case .navigatorUnchanged(let source): print("Navigator unchanged: \(source.title)")
        case .navigatorFailed(let source, let error): print("Navigator failed: \(source.title): \(error)")
        case .pageFetched: fetched += 1
        case .pageUpdated: updated += 1
        case .pageUnchanged: unchanged += 1
        case .pageMissing(let location): missing += 1; print("Missing: \(location.path)")
        case .pageFailed(let location, let error): failed += 1; print("Failed: \(location.path): \(error)")
        case .remaining(let count):
            var parts: [String] = []
            if fetched > 0 { parts.append("\(fetched) fetched") }
            if updated > 0 { parts.append("\(updated) updated") }
            if unchanged > 0 { parts.append("\(unchanged) unchanged") }
            if missing > 0 { parts.append("\(missing) missing") }
            if failed > 0 { parts.append("\(failed) failed") }
            if count > 0 { parts.append("\(count) still pending") }
            print("Pages: " + (parts.isEmpty ? "nothing to do" : parts.joined(separator: ", ")))
        case .finished: break
        }
    }
}
