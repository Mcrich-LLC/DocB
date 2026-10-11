// Where the library file lives, and how commands open it and find sources by a loose name.

import ArgumentParser
import Foundation
import DocBSources
import DocBStore

struct LibraryOptions: ParsableArguments {
    @Option(name: .long, help: "Path to the library file. Defaults to $DOCB_LIBRARY or ~/Library/Application Support/DocB/library.sqlite.")
    var library: String?

    func open() throws -> Library {
        try Library(path: library.map { URL(fileURLWithPath: $0) } ?? Library.defaultLocation())
    }
}

extension Source {
    /// The module for Apple sources, the root for crawled ones, nothing for static sites.
    var scope: String? {
        switch kind {
        case .docc: nil
        case .doccWithoutIndex(let root): root
        case .appleDeveloper(let module): module
        }
    }

    /// How a source is named on the command line: title, module, or base.
    func matches(_ selector: String) -> Bool {
        let needle = selector.lowercased()
        return title.lowercased() == needle
            || scope?.lowercased() == needle
            || base.absoluteString.lowercased() == needle
            || base.absoluteString.lowercased().hasSuffix("/" + needle)
    }
}

extension Library {
    /// The one source a selector names, or a validation error listing the candidates.
    func source(matching selector: String) async throws -> Source {
        let all = try await sources().map(\.source)
        let matches = all.filter { $0.matches(selector) }
        switch matches.count {
        case 1: return matches[0]
        case 0: throw ValidationError("No source matches '\(selector)'. Run `docb source ls`.")
        default: throw ValidationError("'\(selector)' matches \(matches.count) sources: \(matches.map { $0.scope ?? $0.title }.joined(separator: ", "))")
        }
    }
}
