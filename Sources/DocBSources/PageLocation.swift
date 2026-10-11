// The one address a page has inside DocB: a base and an opaque lowercase path, plus the
// fragment a link may carry. Render JSON spells the same page three ways (mixed-case
// identifier, lowercase web URL, data file); everything normalizes to this before it is
// stored, compared, or fetched. Language is not part of the address: hosts serve every
// language from one page and the navigator carries the language instead.

import Foundation

/// A page address: base plus normalized path, with an optional fragment.
public struct PageLocation: Hashable, Codable, Sendable {
    /// The source base this path is relative to.
    public var base: URL

    /// Lowercase, no leading slash, no `.json`: for example `documentation/examplekit/thing`.
    public var path: String

    /// The `#anchor` a link pointed at, if any. Never part of a fetched URL.
    public var fragment: String?

    public init(base: URL, path: String, fragment: String? = nil) {
        self.base = base
        self.path = path
        self.fragment = fragment
    }
}

extension Source {
    /// Resolves an identifier or URL found in a payload to a location on this source's base.
    ///
    /// `doc://` identifiers keep their path. Absolute URLs must start with `base`, which is stripped.
    /// Anything else is taken as base-relative. Returns nil for a URL on another host.
    public func location(for reference: String) -> PageLocation? {
        var remainder: Substring
        if reference.hasPrefix("doc://") {
            let afterScheme = reference.dropFirst("doc://".count)
            remainder = afterScheme.drop(while: { $0 != "/" })   // drop the bundle identifier
        } else if reference.contains("://") {
            let prefix = base.absoluteString
            guard reference.lowercased().hasPrefix(prefix.lowercased()) else { return nil }
            remainder = reference.dropFirst(prefix.count)
        } else {
            remainder = Substring(reference)
        }

        var fragment: String?
        if let hash = remainder.firstIndex(of: "#") {
            fragment = String(remainder[remainder.index(after: hash)...]).removingPercentEncoding
            remainder = remainder[..<hash]
        }
        if let query = remainder.firstIndex(of: "?") {
            remainder = remainder[..<query]
        }

        var path = (String(remainder).removingPercentEncoding ?? String(remainder)).lowercased()
        while path.hasPrefix("/") { path.removeFirst() }
        while path.hasSuffix("/") { path.removeLast() }
        if path.hasSuffix(".json") { path.removeLast(".json".count) }
        return PageLocation(base: base, path: path, fragment: fragment)
    }

    /// The JSON file to fetch for a location.
    public func dataURL(for location: PageLocation) -> URL {
        kind.dataURL(base: location.base, path: location.path)
    }

    /// The page as a browser would open it.
    public func webURL(for location: PageLocation) -> URL {
        var url = location.base.appending(path: location.path)
        if let fragment = location.fragment {
            url = URL(string: "#" + fragment, relativeTo: url)?.absoluteURL ?? url
        }
        return url
    }

    /// Resolves an image or download URL from a payload. Absolute URLs pass through; the rest
    /// are relative to where the kind keeps its assets.
    public func assetURL(for reference: String) -> URL {
        if reference.contains("://"), let url = URL(string: reference) {
            return url
        }
        var path = Substring(reference)
        while path.hasPrefix("/") { path.removeFirst() }
        return kind.assetURL(base: base, path: String(path))
    }
}
