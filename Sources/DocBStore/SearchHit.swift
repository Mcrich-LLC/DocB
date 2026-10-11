// One search result: a navigator entry with enough to open it.

import DocBSources

public struct SearchHit: Equatable, Sendable {
    public var source: Source
    public var location: PageLocation
    public var title: String
    public var type: String
    public var language: String
}
