// A node of a source's page tree as clients read it: the index node plus its resolved location.

import DocBSources

public struct NavigatorNode: Equatable, Sendable, Identifiable {
    /// Stable for the life of a navigator sync; changes when the navigator is swapped.
    public var id: Int64
    public var title: String
    /// Nil for group markers and external links.
    public var location: PageLocation?
    /// The index node type, such as `module`, `struct`, `article`, or `groupMarker`.
    public var type: String
    public var isDeprecated: Bool
    public var isBeta: Bool
    public var isExternal: Bool
    public var icon: String?
    public var children: [NavigatorNode]

    public init(id: Int64, title: String, location: PageLocation?, type: String, isDeprecated: Bool = false, isBeta: Bool = false, isExternal: Bool = false, icon: String? = nil, children: [NavigatorNode] = []) {
        self.id = id
        self.title = title
        self.location = location
        self.type = type
        self.isDeprecated = isDeprecated
        self.isBeta = isBeta
        self.isExternal = isExternal
        self.icon = icon
        self.children = children
    }
}
