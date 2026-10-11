// The page model: a page as a reader would describe it, built once from render JSON with every
// reference resolved. Renderers and the CLI walk this and never touch DocCSchema. It is a
// tree of plain values, so it is Sendable and Hashable for free, and deliberately smaller than
// DocC's own vocabulary: what neither the app nor the CLI can show yet arrives as
// `.unsupported(name)`, so a renderer's coverage is visible in its output.

public struct Page: Hashable, Sendable {
    public var title: String
    /// "Structure", "Article", "Framework": what DocC shows above the title.
    public var roleHeading: String?
    /// DocC's role: "symbol", "article", "collection" (a framework), "collectionGroup" (an API collection), "sampleCode".
    public var role: String?
    /// For symbols, the kind: "struct", "func", "module", and so on.
    public var symbolKind: String?
    /// A standard color the page asked for its hero: "red", "orange", "yellow", "blue", "green", "purple", "gray".
    public var standardColor: String?
    /// The source language of the page's symbols, as DocC names it: "swift" or "occ".
    public var language: String?
    public var abstract: [Run] = []
    public var isBeta = false
    public var isDeprecated = false
    public var platforms: [Platform] = []
    /// A sample code page's download, shown as a button under the abstract.
    public var download: Download?
    /// The page's ancestors, root first, as the web's breadcrumb shows them.
    public var parents: [Links.Item] = []
    /// Everything below the header, in reading order: primary content first, then the link
    /// sections DocC puts at the end (Topics, Relationships, See Also) under headings of their own.
    public var body: [Block] = []

    public init(title: String, roleHeading: String? = nil, role: String? = nil, symbolKind: String? = nil, standardColor: String? = nil, language: String? = nil, abstract: [Run] = [], isBeta: Bool = false, isDeprecated: Bool = false, platforms: [Platform] = [], download: Download? = nil, parents: [Links.Item] = [], body: [Block] = []) {
        self.title = title
        self.roleHeading = roleHeading
        self.role = role
        self.symbolKind = symbolKind
        self.standardColor = standardColor
        self.language = language
        self.abstract = abstract
        self.isBeta = isBeta
        self.isDeprecated = isDeprecated
        self.platforms = platforms
        self.download = download
        self.parents = parents
        self.body = body
    }
}

/// A sample code download: what the button says and where it goes. The URL is the payload's,
/// which may be relative to the source's assets; the host resolves it.
public struct Download: Hashable, Sendable {
    public var title: String
    public var url: String

    public init(title: String, url: String) {
        self.title = title
        self.url = url
    }
}

public struct Platform: Hashable, Sendable {
    public var name: String
    public var introduced: String?
    public var deprecated: String?
    public var isBeta = false

    public init(name: String, introduced: String? = nil, deprecated: String? = nil, isBeta: Bool = false) {
        self.name = name
        self.introduced = introduced
        self.deprecated = deprecated
        self.isBeta = isBeta
    }
}

// MARK: Inline

/// A run of text with one set of styles. Nested inline markup is flattened into runs.
public struct Run: Hashable, Sendable {
    public var text: String
    public var style: Style = []
    /// Where the run leads, as the payload wrote it: a page path, a `doc://` identifier, or an
    /// absolute URL. The host resolves it against the page's source.
    public var link: String?

    public init(_ text: String, _ style: Style = [], link: String? = nil) {
        self.text = text
        self.style = style
        self.link = link
    }

    public struct Style: OptionSet, Hashable, Sendable {
        public let rawValue: UInt8
        public init(rawValue: UInt8) { self.rawValue = rawValue }

        public static let code = Style(rawValue: 1 << 0)
        public static let emphasis = Style(rawValue: 1 << 1)
        public static let strong = Style(rawValue: 1 << 2)
        public static let strikethrough = Style(rawValue: 1 << 3)
        public static let `subscript` = Style(rawValue: 1 << 4)
        public static let superscript = Style(rawValue: 1 << 5)
    }
}

extension [Run] {
    /// The runs' text with no styling.
    public var plainText: String { map(\.text).joined() }
}

// MARK: Blocks

public enum Block: Hashable, Sendable {
    /// Levels follow DocC: the page title is level 1, so content headings start at 2.
    case heading(level: Int, text: String, anchor: String? = nil)
    case paragraph([Run])
    /// Small print, as DocC's `@Small`.
    case small([Run])
    case code(Code)
    /// A symbol's declaration, token by token so renderers can color it and link its types.
    case declaration([Token])
    case list(List)
    case terms([Term])
    case table(Table)
    case aside(Aside)
    case image(Media)
    /// A video and the picture shown before it plays, when the page offers one.
    case video(Media, poster: Media?)
    case links(Links)
    case tabs([Tab])
    case row(Row)
    case divider
    /// Something the model does not carry yet, named as DocC names it.
    case unsupported(String)
}

public struct Code: Hashable, Sendable {
    public var lines: [String]
    public var language: String?

    public init(lines: [String], language: String? = nil) {
        self.lines = lines
        self.language = language
    }
}

public struct Token: Hashable, Sendable {
    public var text: String
    /// DocC's token kind: keyword, identifier, typeIdentifier, externalParam, text, and so on.
    public var kind: String
    public var link: String?

    public init(_ text: String, kind: String, link: String? = nil) {
        self.text = text
        self.kind = kind
        self.link = link
    }
}

extension [Token] {
    public var plainText: String { map(\.text).joined() }
}

public struct List: Hashable, Sendable {
    public var isOrdered: Bool
    public var start = 1
    public var items: [[Block]]

    public init(isOrdered: Bool, start: Int = 1, items: [[Block]]) {
        self.isOrdered = isOrdered
        self.start = start
        self.items = items
    }
}

public struct Term: Hashable, Sendable {
    public var term: [Run]
    public var definition: [Block]

    public init(term: [Run], definition: [Block]) {
        self.term = term
        self.definition = definition
    }
}

public struct Table: Hashable, Sendable {
    public enum Header: Hashable, Sendable { case row, column, both, none }
    public enum Alignment: Hashable, Sendable { case left, center, right, unset }

    public var header: Header
    /// One entry per column; empty when the payload did not say.
    public var alignments: [Alignment] = []
    public var rows: [[Cell]]

    public init(header: Header, alignments: [Alignment] = [], rows: [[Cell]]) {
        self.header = header
        self.alignments = alignments
        self.rows = rows
    }

    public struct Cell: Hashable, Sendable {
        public var blocks: [Block]
        public var columnSpan = 1
        public var rowSpan = 1

        public init(_ blocks: [Block], columnSpan: Int = 1, rowSpan: Int = 1) {
            self.blocks = blocks
            self.columnSpan = columnSpan
            self.rowSpan = rowSpan
        }
    }
}

/// A callout. DocC has dozens of aside kinds ("Precondition", "Throws", "To Do") but renders
/// each in one of the web's styles; the kind is the style, the name is the label.
public struct Aside: Hashable, Sendable {
    public enum Kind: String, Hashable, Sendable, CaseIterable {
        case note, tip, important, warning, experiment, deprecated

        /// The label the kind shows when the aside has no name of its own.
        public var label: String { rawValue.capitalized }
    }

    public var kind: Kind
    /// The label DocC shows: the kind's own, or a custom one like "Precondition".
    public var name: String
    public var blocks: [Block]

    public init(kind: Kind, name: String? = nil, blocks: [Block]) {
        self.kind = kind
        self.name = name ?? kind.label
        self.blocks = blocks
    }
}

/// An image or video, with every variant the payload offers so the host can pick by appearance
/// and scale. URLs are as written: usually paths relative to the source.
public struct Media: Hashable, Sendable {
    public var variants: [Variant]
    public var alt: String?
    public var caption: [Run] = []

    public init(variants: [Variant], alt: String? = nil, caption: [Run] = []) {
        self.variants = variants
        self.alt = alt
        self.caption = caption
    }

    public struct Variant: Hashable, Sendable {
        public var url: String
        public var isDark = false
        public var scale = 1

        public init(url: String, isDark: Bool = false, scale: Int = 1) {
            self.url = url
            self.isDark = isDark
            self.scale = scale
        }
    }

    /// The variant to show when nothing better is known: light, at the lowest scale.
    public var defaultVariant: Variant? {
        variants.min { ($0.isDark ? 1 : 0, $0.scale) < ($1.isDark ? 1 : 0, $1.scale) }
    }
}

/// A group of links to other pages: a topic section, a see-also section, or a links directive.
public struct Links: Hashable, Sendable {
    public enum Style: Hashable, Sendable { case list, compactGrid, detailedGrid }

    public var style: Style
    public var items: [Item]

    public init(style: Style = .list, items: [Item]) {
        self.style = style
        self.items = items
    }

    public struct Item: Hashable, Sendable {
        public var title: String
        /// A symbol's title as declaration tokens, which the web shows in place of the title.
        public var fragments: [Token] = []
        /// Nil when the page could not be resolved; the title still names it.
        public var link: String?
        public var abstract: [Run] = []
        public var isBeta = false
        public var isDeprecated = false
        /// The page's role: "sampleCode", "article", "collection", "symbol", and so on. A card's
        /// link line is worded by it.
        public var role: String?
        /// The page's card image, for the grid styles.
        public var image: Media?

        public init(title: String, fragments: [Token] = [], link: String?, abstract: [Run] = [], isBeta: Bool = false, isDeprecated: Bool = false, role: String? = nil, image: Media? = nil) {
            self.title = title
            self.fragments = fragments
            self.link = link
            self.abstract = abstract
            self.isBeta = isBeta
            self.isDeprecated = isDeprecated
            self.role = role
            self.image = image
        }
    }
}

/// Columns side by side, as DocC's `@Row` and `@Column`; a column's size is its share of the row.
public struct Row: Hashable, Sendable {
    public var columns: [Column]

    public init(columns: [Column]) {
        self.columns = columns
    }

    public struct Column: Hashable, Sendable {
        public var size: Int
        public var blocks: [Block]

        public init(size: Int = 1, blocks: [Block]) {
            self.size = size
            self.blocks = blocks
        }
    }
}

public struct Tab: Hashable, Sendable {
    public var title: String
    public var blocks: [Block]

    public init(title: String, blocks: [Block]) {
        self.title = title
        self.blocks = blocks
    }
}

extension Block {
    /// A paragraph with nothing to read, as REST payloads carry for a response with no text.
    public var isBlank: Bool {
        if case .paragraph(let runs) = self { return runs.allSatisfy { $0.text.allSatisfy(\.isWhitespace) } }
        return false
    }
}
