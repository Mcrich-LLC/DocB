// The resources strip at the bottom of the developer.apple.com homepage (section kind
// `homepageResources`). Distinct from upstream's tutorial `ResourcesRenderSection`.
// Not part of upstream DocC.

/// The resources section of the developer.apple.com homepage.
public struct HomepageResourcesRenderSection: RenderSection, Equatable {
    public var kind: RenderSectionKind = .homepageResources

    /// The resources, in display order.
    public var resources: [Resource]

    public init(resources: [Resource]) {
        self.resources = resources
    }

    /// A single resource tile.
    public struct Resource: Codable, Equatable {
        /// The tile title.
        public var title: String

        /// The tile icon.
        public var image: RenderReferenceIdentifier?

        /// The link the tile opens, as an inline reference.
        public var destination: RenderInlineContent

        /// Descriptive text shown on the tile.
        public var content: [RenderInlineContent] = []

        public init(title: String, image: RenderReferenceIdentifier?, destination: RenderInlineContent, content: [RenderInlineContent]) {
            self.title = title
            self.image = image
            self.destination = destination
            self.content = content
        }
    }
}
