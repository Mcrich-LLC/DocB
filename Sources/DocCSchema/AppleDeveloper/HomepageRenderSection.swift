// A titled content section of the developer.apple.com homepage (section kind `section`), whose
// body is one of several layouts discriminated by its own `kind`. Not part of upstream DocC.

/// A titled section of the developer.apple.com homepage.
public struct HomepageRenderSection: RenderSection, Equatable {
    public var kind: RenderSectionKind = .section

    /// The section heading.
    public var title: String?

    /// Introductory content shown under the heading.
    public var content: [RenderBlockContent] = []

    /// The section's layout and links.
    public var body: Body

    public init(title: String?, content: [RenderBlockContent], body: Body) {
        self.title = title
        self.content = content
        self.body = body
    }

    private enum CodingKeys: String, CodingKey {
        case kind, title, content, body
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        // Live payloads emit `"content": null` for some sections.
        content = try container.decodeIfPresent([RenderBlockContent].self, forKey: .content) ?? []
        body = try container.decode(Body.self, forKey: .body)
    }

    /// The layout of a homepage section, discriminated by the body's `kind` value.
    public enum Body: Codable, Equatable {
        /// Rows of cards, each row optionally featured.
        case cards([CardGroup])
        /// A hero image with one or more highlighted links.
        case highlightedLinks(image: RenderReferenceIdentifier?, links: [HighlightedLink])
        /// A body whose `kind` this version of the schema does not know, preserved verbatim.
        case unknown(JSON)

        /// The discriminator values of a homepage section body.
        public enum Kind: TolerantStringEnum {
            case cards, highlightedLinks
            /// A value this version of the schema does not know. The raw string is preserved and re-encoded unchanged.
            case unknown(String)

            public init(rawValue: String) {
                switch rawValue {
                case "cards": self = .cards
                case "highlightedLinks": self = .highlightedLinks
                default: self = .unknown(rawValue)
                }
            }

            public var rawValue: String {
                switch self {
                case .cards: "cards"
                case .highlightedLinks: "highlightedLinks"
                case .unknown(let rawValue): rawValue
                }
            }
        }

        private enum CodingKeys: String, CodingKey {
            case kind, cards, image, highlightedLinks
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch try container.decode(Kind.self, forKey: .kind) {
            case .cards:
                self = .cards(try container.decode([CardGroup].self, forKey: .cards))
            case .highlightedLinks:
                self = .highlightedLinks(
                    image: try container.decodeIfPresent(RenderReferenceIdentifier.self, forKey: .image),
                    links: try container.decode([HighlightedLink].self, forKey: .highlightedLinks)
                )
            case .unknown:
                self = .unknown(try JSON(from: decoder))
            }
        }

        public func encode(to encoder: any Encoder) throws {
            if case .unknown(let json) = self {
                try json.encode(to: encoder)
                return
            }

            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .cards(let groups):
                try container.encode(Kind.cards, forKey: .kind)
                try container.encode(groups, forKey: .cards)
            case .highlightedLinks(let image, let links):
                try container.encode(Kind.highlightedLinks, forKey: .kind)
                try container.encodeIfPresent(image, forKey: .image)
                try container.encode(links, forKey: .highlightedLinks)
            case .unknown:
                break // Handled above.
            }
        }
    }

    /// A row of cards.
    public struct CardGroup: Codable, Equatable {
        /// Whether the row is displayed prominently.
        public var isFeatured: Bool

        /// The cards in the row.
        public var cards: [Card]

        public init(isFeatured: Bool, cards: [Card]) {
            self.isFeatured = isFeatured
            self.cards = cards
        }
    }

    /// A single card linking to a page.
    public struct Card: Codable, Equatable {
        /// Small text shown above the title.
        public var eyebrow: String?

        /// The card title.
        public var title: String

        /// The card image.
        public var image: RenderReferenceIdentifier?

        /// The link the card opens, as an inline reference.
        public var destination: RenderInlineContent

        /// Descriptive text shown on the card.
        public var content: [RenderInlineContent] = []

        /// Call-to-action labels, keyed by context.
        public var callToAction: CallToAction?

        /// Call-to-action labels, keyed by context. Some payloads use this key instead of `callToAction`.
        public var callToActionText: CallToAction?

        public init(
            eyebrow: String?,
            title: String,
            image: RenderReferenceIdentifier?,
            destination: RenderInlineContent,
            content: [RenderInlineContent],
            callToAction: CallToAction?,
            callToActionText: CallToAction?
        ) {
            self.eyebrow = eyebrow
            self.title = title
            self.image = image
            self.destination = destination
            self.content = content
            self.callToAction = callToAction
            self.callToActionText = callToActionText
        }
    }

    /// Call-to-action labels for a card, one per viewing context.
    public struct CallToAction: Codable, Equatable {
        /// The label shown inside Xcode.
        public var ide: String?

        /// The label shown on the web.
        public var web: String?

        public init(ide: String?, web: String?) {
            self.ide = ide
            self.web = web
        }
    }

    /// A prominent link with descriptive text.
    public struct HighlightedLink: Codable, Equatable {
        /// The link title.
        public var title: String

        /// Descriptive text shown under the title.
        public var content: [RenderInlineContent] = []

        /// The call-to-action label.
        public var callToActionText: String?

        /// The link target, as a raw identifier or URL string.
        public var destination: String

        public init(title: String, content: [RenderInlineContent], callToActionText: String?, destination: String) {
            self.title = title
            self.content = content
            self.callToActionText = callToActionText
            self.destination = destination
        }
    }
}
