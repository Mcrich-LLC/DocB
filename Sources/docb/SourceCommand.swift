// `docb source`: add, list, and delete sources.

import ArgumentParser
import Foundation
import DocBSources
import DocBStore

struct SourceCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "source",
        abstract: "Manage documentation sources.",
        subcommands: [Add.self, List.self, Delete.self],
        defaultSubcommand: List.self
    )

    struct Add: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Discover the documentation at a URL and add it.")

        @Argument(help: "A documentation site, a page on it, or developer.apple.com.")
        var url: String

        @Option(name: .shortAndLong, parsing: .upToNextOption, help: "For a catalog, the module(s) to add. Defaults to the module named by the URL.")
        var module: [String] = []

        @Flag(help: "For a catalog, add every technology it lists.")
        var all = false

        @Flag(help: "Download every page for offline reading, not just the navigator.")
        var offline = false

        @Flag(help: "Add without syncing.")
        var noSync = false

        @OptionGroup var options: LibraryOptions

        func run() async throws {
            guard let parsed = URL(string: url.contains("://") ? url : "https://" + url) else {
                throw ValidationError("'\(url)' is not a URL.")
            }
            let discovered: [Source]
            do {
                discovered = try await Discovery.discover(parsed)
            } catch let error as DiscoveryError {
                throw ValidationError("No DocC documentation found. Tried:\n" + error.tried.map { "  \($0.absoluteString)" }.joined(separator: "\n"))
            }

            let selected: [Source]
            if discovered.count == 1 {
                selected = discovered
            } else if all {
                selected = discovered
            } else {
                let wanted = module.isEmpty ? Self.moduleNamed(by: parsed).map { [$0] } ?? [] : module
                selected = discovered.filter { source in wanted.contains { source.matches($0) } }
                if selected.isEmpty {
                    print("This URL offers \(discovered.count) technologies. Pass --module <name> (or --all), for example:")
                    for source in discovered.prefix(12) { print("  \(source.scope ?? source.title)\t\(source.title)") }
                    if discovered.count > 12 { print("  ... and \(discovered.count - 12) more") }
                    throw ExitCode.failure
                }
                let unmatched = wanted.filter { name in !discovered.contains { $0.matches(name) } }
                if !unmatched.isEmpty { throw ValidationError("Not in this catalog: \(unmatched.joined(separator: ", "))") }
            }

            let library = try options.open()
            for source in selected {
                do {
                    try await library.add(source, offline: offline)
                } catch StoreError.duplicateSource {
                    print("\(source.title) is already in the library (\(describe(source))).")
                    continue
                }
                print("Added \(source.title) (\(describe(source)))")
                if !noSync {
                    try await report(library.sync(only: source))
                }
            }
        }

        /// The module a pasted URL names, if its path has one after `documentation`.
        static func moduleNamed(by url: URL) -> String? {
            let components = url.pathComponents.filter { $0 != "/" }
            guard let index = components.firstIndex(where: { $0.lowercased() == "documentation" }), components.count > index + 1 else { return nil }
            return components[index + 1].lowercased()
        }
    }

    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "list", abstract: "List sources.", aliases: ["ls"])

        @OptionGroup var options: LibraryOptions

        func run() async throws {
            let records = try await options.open().sources()
            if records.isEmpty {
                print("No sources. Add one with `docb source add <url>`.")
                return
            }
            let width = records.map(\.source.title.count).max() ?? 0
            for record in records {
                let pages = record.offline
                    ? "offline, \(record.fetchedPages) pages" + (record.pendingPages > 0 ? ", \(record.pendingPages) pending" : "")
                    : "\(record.fetchedPages) pages cached"
                let synced = record.indexSyncedAt.map { "synced \($0.formatted(.relative(presentation: .named)))" } ?? "never synced"
                print("\(record.source.title.padding(toLength: width, withPad: " ", startingAt: 0))  \(describe(record.source))  \(pages), \(synced)")
            }
        }
    }

    struct Delete: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "delete", abstract: "Delete a source and the pages only it reached.", aliases: ["rm"])

        @Argument(help: "The source's title, module, or base URL.")
        var source: String

        @OptionGroup var options: LibraryOptions

        func run() async throws {
            let library = try options.open()
            let match = try await library.source(matching: source)
            try await library.remove(match)
            print("Deleted \(match.title)")
        }
    }
}

/// "base (module)" for Apple sources, "base" otherwise.
func describe(_ source: Source) -> String {
    switch source.kind {
    case .docc: source.base.absoluteString
    case .doccWithoutIndex: "\(source.base.absoluteString), no index"
    case .appleDeveloper(let module): "\(source.base.absoluteString) · \(module)"
    }
}
