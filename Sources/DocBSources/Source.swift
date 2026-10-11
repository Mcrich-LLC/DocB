// A documentation source: one page tree and the navigator that describes it. A static DocC
// site, a DocC site too old to ship a navigator index, and one technology on
// developer.apple.com are the three kinds. Everything the store syncs is a `Source`, and
// `Kind` is the only place their URL schemes differ.

import Foundation

/// One page tree and its navigator, as added by the user and synced by the store.
public struct Source: Hashable, Codable, Sendable {
    /// The URL everything else is relative to. Normalized: no trailing slash, query, or fragment.
    public var base: URL

    /// Which URL scheme the host uses and how its navigator is obtained.
    public var kind: Kind

    /// Display name, taken from the catalog, the index, or the build metadata at discovery time.
    public var title: String

    /// Interface language identifiers the source is available in, such as `swift` and `occ`.
    public var languages: [String]

    /// Catalog tags, used for filtering. Empty outside the Apple catalog.
    public var tags: [String]

    public init(base: URL, kind: Kind, title: String, languages: [String], tags: [String] = []) {
        self.base = base
        self.kind = kind
        self.title = title
        self.languages = languages
        self.tags = tags
    }

    /// The kinds of source, each with its own navigator and data URL rules.
    public enum Kind: Hashable, Codable, Sendable {
        /// A static DocC site: `index/index.json` and `data/<path>.json` under the base.
        case docc
        /// A DocC site built before navigator indexes existed; the page tree is crawled from `root`.
        case doccWithoutIndex(root: String)
        /// One technology on developer.apple.com: `tutorials/data/index/<module>` and `tutorials/data/<path>.json`.
        case appleDeveloper(module: String)

        /// Where this kind's navigator comes from.
        public func navigator(base: URL) -> Navigator {
            switch self {
            case .docc:
                .index(base.appending(path: "index/index.json"))
            case .doccWithoutIndex(let root):
                .crawl(root: PageLocation(base: base, path: root))
            case .appleDeveloper(let module):
                .index(base.appending(path: "tutorials/data/index/\(module)"))
            }
        }

        /// The JSON file for a page path under this kind.
        public func dataURL(base: URL, path: String) -> URL {
            switch self {
            case .docc, .doccWithoutIndex:
                base.appending(path: "data/\(path).json")
            case .appleDeveloper:
                base.appending(path: "tutorials/data/\(path).json")
            }
        }

        /// Where a root-relative asset path ("/images/x.png") lives: the renderer prefixes its
        /// base URL, which is the site's for a DocC site and `/tutorials/` on developer.apple.com.
        public func assetURL(base: URL, path: String) -> URL {
            switch self {
            case .docc, .doccWithoutIndex:
                base.appending(path: path)
            case .appleDeveloper:
                base.appending(path: "tutorials/\(path)")
            }
        }
    }

    /// How the sync engine obtains a source's page tree. Every kind has one.
    public enum Navigator: Hashable, Sendable {
        /// Fetch and decode a `RenderIndex`.
        case index(URL)
        /// Walk topic sections starting from this page.
        case crawl(root: PageLocation)
    }

    /// Where this source's navigator comes from.
    public var navigator: Navigator {
        kind.navigator(base: base)
    }

    /// Whether two sources live on the same host under the same scheme, so links between them resolve without a catalog.
    public func sharesOrigin(with other: Source) -> Bool {
        guard base == other.base else { return false }
        switch (kind, other.kind) {
        case (.docc, .docc), (.docc, .doccWithoutIndex), (.doccWithoutIndex, .docc), (.doccWithoutIndex, .doccWithoutIndex),
             (.appleDeveloper, .appleDeveloper):
            return true
        default:
            return false
        }
    }
}
