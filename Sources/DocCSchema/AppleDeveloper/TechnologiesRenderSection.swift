// The developer.apple.com technologies catalog (section kind `technologies`): named groups of
// technologies, each pointing at a documentation archive or an external site. This is the
// discovery payload a multi-archive source is built from. Not part of upstream DocC.

/// The grouped list of technologies on developer.apple.com.
public struct TechnologiesRenderSection: RenderSection, Equatable {
    public var kind: RenderSectionKind = .technologies

    /// The technology groups, in display order.
    public var groups: [Group]

    public init(groups: [Group]) {
        self.groups = groups
    }

    /// A named group of technologies.
    public struct Group: Codable, Equatable {
        /// The group name, for example a product area.
        public var name: String

        /// The technologies in the group.
        public var technologies: [Technology]

        public init(name: String, technologies: [Technology]) {
            self.name = name
            self.technologies = technologies
        }
    }

    /// A single technology entry.
    public struct Technology: Codable, Equatable {
        /// The technology title.
        public var title: String

        /// A short description.
        public var content: [RenderInlineContent] = []

        /// The link to the technology's documentation, as an inline reference.
        public var destination: RenderInlineContent

        /// Source language identifiers the documentation is available in.
        public var languages: [String]

        /// Tags used for filtering the catalog.
        public var tags: [String]

        public init(title: String, content: [RenderInlineContent], destination: RenderInlineContent, languages: [String], tags: [String]) {
            self.title = title
            self.content = content
            self.destination = destination
            self.languages = languages
            self.tags = tags
        }
    }
}
