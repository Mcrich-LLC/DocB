// `docb search`: find navigator entries by title substring.

import ArgumentParser
import DocBSources
import DocBStore

struct SearchCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "search", abstract: "Search symbol and article titles.")

    @Argument(help: "Text to look for in titles.")
    var query: String

    @Option(name: .shortAndLong, help: "Interface language, such as swift or occ.")
    var language: String?

    @Option(name: [.customShort("n"), .long], help: "Maximum number of results.")
    var limit: Int = 20

    @OptionGroup var options: LibraryOptions

    func run() async throws {
        let hits = try await options.open().search(query, language: language, limit: limit)
        if hits.isEmpty {
            print("No matches.")
            return
        }
        let width = hits.map(\.title.count).max() ?? 0
        for hit in hits {
            print("\(hit.title.padding(toLength: width, withPad: " ", startingAt: 0))  \(hit.type.padding(toLength: 12, withPad: " ", startingAt: 0))  \(hit.location.path)  (\(hit.source.title))")
        }
    }
}
