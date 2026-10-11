// `docb show`: read a page as Markdown, or dump its render JSON.

import ArgumentParser
import Foundation
import DocCSchema
import DocBSources
import DocBStore
import DocBMarkdown
import DocBPage

struct ShowCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "show", abstract: "Read a page.", aliases: ["read"])

    @Argument(help: "A page path like documentation/swiftui/view, a doc:// identifier, or a page URL.")
    var page: String

    @Option(name: .shortAndLong, help: "The source the path belongs to, when the library has more than one base.")
    var source: String?

    @Option(name: .shortAndLong, help: "Interface language to render, such as occ.")
    var language: String?

    @Flag(help: "Print the render JSON instead of text.")
    var json = false

    @OptionGroup var options: LibraryOptions

    func run() async throws {
        let library = try options.open()
        let source = try await resolveSource(library)
        guard let location = source.location(for: page) else {
            throw ValidationError("'\(page)' is not on \(source.base.absoluteString).")
        }
        if json {
            var data = try await library.pageData(at: location)
            if let language, language != "swift" {
                data = try RenderNodeVariantOverridesApplier().applyVariantOverrides(in: data, for: [.interfaceLanguage(language)])
            }
            print(String(decoding: data, as: UTF8.self))
            return
        }
        let node = try await library.page(at: location, language: language ?? "swift")
        print(Markdown.render(Page(node: node)), terminator: "")
    }

    /// The source whose base the page is on: the named one, the one whose base prefixes an absolute URL,
    /// the one whose navigator lists the path, or the only base in the library.
    func resolveSource(_ library: Library) async throws -> Source {
        if let source {
            return try await library.source(matching: source)
        }
        let all = try await library.sources().map(\.source)
        if page.contains("://"), !page.hasPrefix("doc://") {
            if let match = all.first(where: { page.lowercased().hasPrefix($0.base.absoluteString.lowercased()) }) {
                return match
            }
            throw ValidationError("No source covers \(page). Add one with `docb source add`.")
        }
        if let path = all.first?.location(for: page)?.path {
            let listing = try await library.sources(containing: path)
            if let first = listing.first { return first }
        }
        let bases = Set(all.map(\.base))
        switch bases.count {
        case 0: throw ValidationError("No sources. Add one with `docb source add <url>`.")
        case 1: return all[0]
        default: throw ValidationError("No source lists '\(page)' and the library has \(bases.count) bases; pass --source to say which one it is on.")
        }
    }
}
