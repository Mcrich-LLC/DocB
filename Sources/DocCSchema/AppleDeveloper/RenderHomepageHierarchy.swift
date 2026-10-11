// The hierarchy of the developer.apple.com homepage and technologies catalog: an ordered list of
// top-level navigation references rather than the path lists upstream hierarchies carry.
// Not part of upstream DocC.

/// The hierarchy for the developer.apple.com homepage and technologies catalog.
public struct RenderHomepageHierarchy: Codable, Equatable {
    /// A single entry in the homepage navigation.
    public struct Item: Codable, Equatable {
        /// The reference identifier of the page the entry points to.
        public var reference: RenderReferenceIdentifier

        public init(reference: RenderReferenceIdentifier) {
            self.reference = reference
        }
    }

    /// The top-level navigation entries, in display order.
    public var homepageNavigation: [Item]

    public init(homepageNavigation: [Item]) {
        self.homepageNavigation = homepageNavigation
    }
}
