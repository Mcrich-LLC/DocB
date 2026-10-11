// The docb command: source management, sync, search, and reading, over a shared library file.

import ArgumentParser

@main
struct DocB: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "docb",
        abstract: "Offline DocC documentation browser.",
        subcommands: [SourceCommand.self, SyncCommand.self, SearchCommand.self, ShowCommand.self]
    )
}
