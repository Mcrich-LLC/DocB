#if DEBUG
import SwiftUI
// Debug-only access keeps the package's internal renderers out of its public API.
@testable import DocCKit
import ImageIO
import UniformTypeIdentifiers

/// Provides an interactive gallery of DocCKit's renderers using local mock documentation.
///
/// Run the DocCPlayground app
/// to change controls, copy code, select tabs, follow mock links, and enlarge images.
/// All sample payloads live in this file.
@MainActor
struct DocCComponentPlayground: View {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// Whether the controls are presented over the compact catalog layout.
    @State private var showsControls = false
    #endif
    /// The page or gallery currently being explored.
    @State private var page = PlaygroundPage.catalog
    /// The component family displayed in the catalog.
    @State private var catalogFamily = CatalogFamily.all
    /// Text used to filter catalog families.
    @State private var catalogFilter = ""
    /// The maximum width available to the sample content.
    @State private var contentWidth = 900.0
    /// The appearance applied to the playground.
    @State private var appearance = PlaygroundAppearance.system
    /// The title used by the mock article.
    @State private var title = "Building a documentation browser"
    /// The editable abstract and callout text.
    @State private var sampleText = "Explore real DocC components with local sample data. Change the controls to compare their appearance."
    /// Whether the mock article displays beta notices.
    @State private var isBeta = true
    /// Whether the mock article displays deprecation notices.
    @State private var isDeprecated = false
    /// Whether reference lists show symbol badges.
    @State private var showsSymbolBadges = true
    /// The layout applied to topic links.
    @State private var linkStyle = ContentSection.Content.Style.list
    /// The semantic role used to style the mock article.
    @State private var role = Role.article
    /// The callout style displayed in the gallery.
    @State private var asideStyle = ContentSection.Content.Style.tip
    /// The size of symbol badges displayed in the gallery.
    @State private var badgeSize = 24.0
    /// An optional media URL supplied when exploring the video component.
    @State private var videoURL = ""
    /// The in-memory navigator used by the sample renderers.
    @State private var navigator = PlaygroundNavigator()
    /// The local fixtures, or a recoverable fixture creation error.
    private let samples: Result<PlaygroundSamples, Error>

    /// Creates a playground containing local sample documentation and interactive controls.
    init() {
        samples = PlaygroundSamples.shared
    }

    fileprivate init(page: PlaygroundPage) {
        samples = PlaygroundSamples.shared
        _page = State(initialValue: page)
    }

    var body: some View {
        navigation
            .preferredColorScheme(appearance.colorScheme)
            .environment(\.docCIsUsingSplitView, navigator.isUsingSplitView)
            .environment(\.docCDeepLinkScheme, navigator.deepLinkScheme)
            .environment(\.docCNavigateToReference, DocCReferenceNavigationAction { reference in
                navigator.setReference(reference, forceHistory: false)
            })
            .environment(\.openURL, OpenURLAction { url in
                navigator.lastAction = "Selected link: \(url.absoluteString)"
                return .handled
            })
    }

    @ViewBuilder
    private var navigation: some View {
        #if os(iOS)
        if horizontalSizeClass == .compact {
            NavigationStack {
                detail
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Controls", systemImage: "slider.horizontal.3") {
                                showsControls = true
                            }
                        }
                    }
            }
            .sheet(isPresented: $showsControls) {
                NavigationStack {
                    controls
                        .navigationTitle("Playground controls")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showsControls = false }
                            }
                        }
                }
            }
        } else {
            splitNavigation
        }
        #else
        splitNavigation
        #endif
    }

    private var splitNavigation: some View {
        NavigationSplitView {
            controls
                .navigationTitle("DocC Playground")
                .navigationSplitViewColumnWidth(min: 260, ideal: 290, max: 340)
        } detail: {
            detail
        }
    }

    private var detail: some View {
        VStack(spacing: 0) {
            switch samples {
            case .success(let samples):
                GeometryReader { geometry in
                    samplePage(samples)
                        .frame(width: min(contentWidth, geometry.size.width), height: geometry.size.height)
                        .clipped()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            case .failure(let error):
                ContentUnavailableView("Couldn’t create samples", systemImage: "exclamationmark.triangle", description: Text(error.localizedDescription))
            }
            Divider()
            Text(navigator.lastAction)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
        }
        .navigationTitle(page.rawValue)
    }

    private var controls: some View {
        Form {
            Section("Explore") {
                Picker("Example", selection: $page) {
                    ForEach(PlaygroundPage.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Picker("Appearance", selection: $appearance) {
                    ForEach(PlaygroundAppearance.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                LabeledContent("Content width", value: "\(Int(contentWidth)) pt")
                Slider(value: $contentWidth, in: 320...1400, step: 20)
                Toggle("Split-view layout", isOn: $navigator.isUsingSplitView)
                if page != .catalog {
                    Toggle("Reference symbol badges", isOn: $showsSymbolBadges)
                }
            }
            if page == .catalog {
                Section("Catalog") {
                    Picker("Component family", selection: $catalogFamily) {
                        ForEach(CatalogFamily.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    TextField("Filter component families", text: $catalogFilter)
                    TextField("Callout text", text: $sampleText, axis: .vertical)
                        .lineLimit(3...6)
                    Text("Compare variations together. Appearance and content width apply to every sample.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if page != .catalog {
                Section("Article") {
                    TextField("Title", text: $title)
                    TextField("Abstract and callout", text: $sampleText, axis: .vertical)
                        .lineLimit(3...6)
                    Picker("Role", selection: $role) {
                        ForEach([Role.article, .symbol, .sampleCode, .collection, .collectionGroup], id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    Toggle("Beta", isOn: $isBeta)
                    Toggle("Deprecated", isOn: $isDeprecated)
                    Picker("Topic layout", selection: $linkStyle) {
                        ForEach([ContentSection.Content.Style.list, .compactGrid, .detailedGrid, .hidden], id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                }
            }
            Section(page == .catalog ? "Media" : "Gallery") {
                if page != .catalog {
                    Picker("Callout", selection: $asideStyle) {
                        ForEach([ContentSection.Content.Style.tip, .note, .warning, .important, .experiment, .deprecated], id: \.self) {
                            Text($0.rawValue.capitalized).tag($0)
                        }
                    }
                    LabeledContent("Badge size", value: "\(Int(badgeSize)) pt")
                    Slider(value: $badgeSize, in: 12...48, step: 2)
                }
                TextField("Video URL (optional)", text: $videoURL)
                Text("Video playback uses the URL you enter. Other samples work offline.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button("Reset controls", action: reset)
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func samplePage(_ samples: PlaygroundSamples) -> some View {
        let article = samples.article(title: title, text: sampleText, role: role, status: (isBeta, isDeprecated), style: linkStyle)
        switch page {
        case .catalog:
            DocCComponentCatalog(samples: samples, family: catalogFamily, filter: catalogFilter, text: sampleText, videoURL: videoURL, navigator: navigator)
        case .components:
            gallery(samples, article: article)
        case .article:
            DocCArticleView(article: article, navigator: navigator, showsReferenceSymbolBadges: showsSymbolBadges)
        case .endpoint:
            DocCArticleView(article: samples.endpoint, navigator: navigator, showsReferenceSymbolBadges: showsSymbolBadges)
        case .homepage:
            DocCHomepageView(homepage: samples.homepage, navigator: navigator)
        case .framework:
            DocCFrameworkView(framework: samples.framework, frameworkSection: samples.frameworkSection, navigator: navigator)
        }
    }

    private func gallery(_ samples: PlaygroundSamples, article: Article) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                gallerySection("Abstract") {
                    AbstractView(abstract: article.abstract ?? [])
                }
                gallerySection("Status badges and platform capsules") {
                    WrappingHStack(alignment: .leading, horizontalSpacing: 10) {
                        ForEach(ArticleBadge.Badge.allCases, id: \.self) { ArticleBadge(badge: $0) }
                        ForEach(article.metadata.platforms ?? []) { PlatformCapsule(platform: $0) }
                    }
                }
                gallerySection("Symbol badges") {
                    symbolBadges
                }
                gallerySection("Declaration and copy button") {
                    ForEach(samples.baseArticle.primaryContentSections?.flatMap { $0.declarations ?? [] } ?? []) {
                        DeclarationContentView(content: $0, article: article)
                    }
                }
                gallerySection("Callout") {
                    AsideView(style: asideStyle, content: samples.message(sampleText), references: article.references)
                        .id(sampleText)
                }
                ForEach(samples.blocks.indices, id: \.self) { index in
                    gallerySection(samples.blockTitles[index]) {
                        ArticleContentView(content: samples.blocks[index], references: article.references)
                    }
                }
                gallerySection("Video") {
                    if let url = URL(string: videoURL), ["https", "http", "file"].contains(url.scheme?.lowercased() ?? "") {
                        ArticleContentView(content: samples.video, references: [
                            "playground-video": Reference(identifier: "playground-video", type: "video", variants: [.init(url: url.absoluteString, traits: [])])
                        ])
                        .frame(height: 260)
                        .id(url)
                    } else {
                        Text("Enter a video URL in the controls to explore the video player.")
                            .foregroundStyle(.secondary)
                    }
                }
                gallerySection("Reference links") {
                    LinksGridListView(identifiers: samples.identifiers, style: linkStyle, references: article.references, showsSymbolKindBadge: showsSymbolBadges)
                }
                gallerySection("Topics, relationships, and see also") {
                    TopicsView(article: article)
                    RelationshipsView(article: article)
                    SeeAlsoView(article: article)
                }
                gallerySection("Mentions and details") {
                    MentionsView(mentions: samples.identifiers, article: article)
                    if let details = samples.baseArticle.primaryContentSections?.first(where: { $0.kind == .details })?.details {
                        DetailsView(details: details)
                    }
                }
                gallerySection("Sample download and legal notices") {
                    if let download = article.sampleCodeDownload {
                        DownloadButtonView(sampleCodeDownload: download, references: article.references)
                    }
                    if let notices = article.legalNotices { DocCLegalNoticesView(legalNotices: notices) }
                }
            }
            .padding(24)
        }
    }

    private func gallerySection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title2.bold())
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var symbolBadges: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], alignment: .leading, spacing: 16) {
            ForEach(PlaygroundSamples.symbolKinds, id: \.self) { kind in
                HStack {
                    DocCSymbolBadge(symbolKind: kind, size: badgeSize)
                    Text(SidebarSearchSymbolKind.title(for: kind, fallback: "Unknown"))
                        .font(.caption)
                }
            }
        }
    }

    private func reset() {
        page = .catalog
        catalogFamily = .all
        catalogFilter = ""
        contentWidth = 900
        appearance = .system
        title = "Building a documentation browser"
        sampleText = "Explore real DocC components with local sample data. Change the controls to compare their appearance."
        isBeta = true
        isDeprecated = false
        showsSymbolBadges = true
        linkStyle = .list
        role = .article
        asideStyle = .tip
        badgeSize = 24
        videoURL = ""
        navigator.showHomepage()
        navigator.isUsingSplitView = true
    }
}

fileprivate enum PlaygroundPage: String, CaseIterable {
    case catalog = "Component catalog"
    case components = "Interactive gallery"
    case article = "Article"
    case endpoint = "REST endpoint"
    case homepage = "Homepage"
    case framework = "Framework"
}

private enum PlaygroundAppearance: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Records mock navigation without loading documentation or changing application state.
@MainActor
@Observable
final class PlaygroundNavigator: DocCNavigator {
    var reference: Reference?
    var technology: AppleTechnologies.FrameworkSection?
    var isUsingSplitView = true
    let deepLinkScheme = DocCDeepLinkScheme("docc-playground")
    var lastAction = "Select a link to see its destination here. Tap an image to enlarge it."

    func setReference(_ reference: Reference?, forceHistory: Bool) {
        self.reference = reference
        lastAction = "Selected reference: \(reference?.title ?? reference?.identifier ?? "None")"
    }

    func setTechnology(_ technology: AppleTechnologies.FrameworkSection?, noHistory: Bool) {
        self.technology = technology
        lastAction = "Selected framework: \(technology?.title ?? "None")"
    }

    func showHomepage() {
        reference = nil
        technology = nil
        lastAction = "Select a link to see its destination here. Tap an image to enlarge it."
    }
}

/// Decodes representative DocC payloads once so controls preserve tab and content identities.
@MainActor
struct PlaygroundSamples {
    static let shared = Result { try PlaygroundSamples() }
    static let symbolKinds: [SidebarSearchSymbolKind] = [
        .article, .classSymbol, .collection, .collectionGroup, .enumeration, .enumerationCase,
        .framework, .function, .initializer, .macro, .method, .property, .protocolSymbol,
        .structure, .typeAlias, .variable, .unknown
    ]

    let baseArticle: Article
    let endpoint: Article
    let homepage: HomepageParser
    let framework: Framework
    let frameworkSection: AppleTechnologies.FrameworkSection
    let blocks: [ContentSection.Content]
    let blockTitles: [String]
    let video: ContentSection.Content
    let identifiers: [String]

    // Build fixtures through the real decoder, including polymorphic lists, tabs, and tables.
    // Edit these dictionaries to try additional DocC payload shapes in the app.
    private init() throws {
        let imageURL = try Self.makeImage()
        identifiers = ["doc://playground/documentation/Browser", "doc://playground/documentation/Browser/open", "doc://playground/documentation/Guide"]
        let references: [String: Any] = [
            identifiers[0]: Self.reference("Browser", id: identifiers[0], roleHeading: "Structure", image: true),
            identifiers[1]: Self.reference("open(_:)", id: identifiers[1], roleHeading: "Instance Method", beta: true),
            identifiers[2]: Self.reference("Getting started", id: identifiers[2], roleHeading: "Article", deprecated: true),
            "playground-image": ["identifier": "playground-image", "type": "image", "variants": [["url": imageURL.absoluteString, "traits": ["light"]]]],
            "playground-download": ["identifier": "playground-download", "type": "download", "title": "Download sample", "url": "https://playground.invalid/sample.zip"]
        ]
        let notices: [String: Any] = [
            "copyright": "<p>© 2026 Playground Samples</p>",
            "privacyPolicy": "https://playground.invalid/privacy",
            "termsOfUse": "https://playground.invalid/terms"
        ]
        let examples = Self.contentExamples(identifiers: identifiers)
        blockTitles = examples.map(\.0)
        blocks = try Self.decode(examples.map(\.1))
        video = try Self.decode(["type": "video", "identifier": "playground-video"])
        let topic: [String: Any] = ["title": "Essentials", "identifiers": identifiers]
        let articleJSON: [String: Any] = [
            "metadata": ["title": "Building a documentation browser", "role": "article", "roleHeading": "Article", "platforms": [
                ["name": "iOS", "introducedAt": "18.0"], ["name": "macOS", "introducedAt": "15.0"], ["name": "visionOS", "introducedAt": "2.0"]
            ]],
            "abstract": [Self.inline("A local example of a rich DocC article.")],
            "primaryContentSections": [
                ["kind": "declarations", "declarations": [[
                    "tokens": [["kind": "text", "text": "struct Browser: View {\n    var body: some View { Text(\"Hello, DocC!\") }\n}"]],
                    "languages": ["swift"]
                ]]],
                ["kind": "content", "content": examples.map(\.1)],
                ["kind": "details", "details": ["name": "Browser", "value": [["baseType": "structure"]]]],
                ["kind": "mentions", "mentions": identifiers]
            ],
            "topicSections": [topic], "seeAlsoSections": [topic],
            "relationshipsSections": [["title": "Conforms To", "identifiers": [identifiers[0]]]],
            "sampleCodeDownload": ["action": ["isActive": true, "identifier": "playground-download", "type": "reference"]],
            "references": references, "legalNotices": notices
        ]
        baseArticle = try Self.decode(articleJSON)
        var endpointJSON = articleJSON
        endpointJSON["metadata"] = ["title": "Create a bookmark", "role": "restRequestSymbol", "roleHeading": "Web Service Endpoint"]
        endpointJSON["primaryContentSections"] = Self.endpointSections(identifiers: identifiers)
        endpoint = try Self.decode(endpointJSON)
        homepage = try Self.decode([
            "metadata": ["title": "Documentation", "role": "overview"],
            "sections": Self.homepageSections(identifiers: identifiers),
            "references": references, "legalNotices": notices
        ])
        framework = try Self.decode([
            "metadata": ["title": "BrowserKit", "role": "framework"],
            "topicSections": [topic], "references": references, "legalNotices": notices
        ])
        frameworkSection = .init(
            languages: ["swift"], title: "BrowserKit", tags: [],
            destination: .init(type: "topic", isActive: true, identifier: "doc://playground/documentation/BrowserKit"),
            legalNotices: nil, docCSite: nil, index: nil
        )
    }

    func article(title: String, text: String, role: Role, status: (beta: Bool, deprecated: Bool), style: ContentSection.Content.Style) -> Article {
        Article(
            metadata: .init(role: role, roleHeading: role == .symbol ? "Structure" : role.rawValue.capitalized, color: nil, images: nil, title: title, platforms: baseArticle.metadata.platforms?.map {
                .init(introducedAt: $0.introducedAt, unavailable: false, beta: status.beta, name: $0.name, deprecated: status.deprecated, deprecatedAt: status.deprecated ? "26.0" : nil)
            }),
            topicSectionsStyle: style, abstract: [Self.textNode(text)],
            primaryContentSections: baseArticle.primaryContentSections, references: baseArticle.references,
            legalNotices: baseArticle.legalNotices, seeAlsoSections: baseArticle.seeAlsoSections,
            topicSections: baseArticle.topicSections, relationshipsSections: baseArticle.relationshipsSections,
            sampleCodeDownload: baseArticle.sampleCodeDownload,
            deprecationSummary: status.deprecated ? message("This sample is deprecated. Try changing the Deprecated control.") : nil,
            betaSummary: status.beta ? message("This sample is in beta. Try changing the Beta control.") : nil,
            variants: nil, variantOverrides: nil
        )
    }

    func message(_ text: String) -> [ContentSection.Content] {
        // Reuse a decoded node's identity while updating the editable inline text.
        guard var paragraph = blocks.first(where: { $0.type == .paragraph }) else { return [] }
        paragraph.inlineContent = [Self.textNode(text)]
        return [paragraph]
    }

    private static func textNode(_ text: String) -> ContentStruct {
        .init(text: text, code: nil, identifier: nil, metadata: nil, inlineContent: nil, font: nil, fontWeight: nil, type: .text, orderedListInt: nil)
    }

    private static func decode<T: Decodable>(_ object: Any) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: object))
    }

    private static func inline(_ text: String) -> [String: Any] { ["type": "text", "text": text] }
    private static func paragraph(_ text: String) -> [String: Any] { ["type": "paragraph", "inlineContent": [inline(text)]] }

    private static func reference(_ title: String, id: String, roleHeading: String, image: Bool = false, beta: Bool = false, deprecated: Bool = false) -> [String: Any] {
        var reference: [String: Any] = [
            "title": title, "identifier": id, "type": "topic", "role": roleHeading == "Article" ? "article" : "symbol",
            "roleHeading": roleHeading, "abstract": [inline("Learn how to use \(title) in your documentation browser.")],
            "beta": beta, "deprecated": deprecated
        ]
        if image { reference["images"] = [["identifier": "playground-image", "type": "card"]] }
        return reference
    }

    private static func contentExamples(identifiers: [String]) -> [(String, [String: Any])] {
        var examples: [(String, [String: Any])] = []
        examples.append(("Headings", ["type": "heading", "level": 2, "text": "Overview", "anchor": "overview"]))
        let strong: [String: Any] = ["type": "strong", "inlineContent": [inline("bold")]]
        let emphasis: [String: Any] = ["type": "emphasis", "inlineContent": [inline("italic")]]
        let code: [String: Any] = ["type": "codeVoice", "code": "monospaced code"]
        let reference: [String: Any] = ["type": "reference", "identifier": identifiers[0]]
        let richInline = [inline("Combine "), strong, inline(", "), emphasis, inline(", "), code, inline(", and "), reference, inline(" in a paragraph.")]
        examples.append(("Rich inline text", ["type": "paragraph", "inlineContent": richInline]))
        examples.append(("Plain text", ["type": "text", "text": "A plain text block."]))
        examples.append(("Strong text", ["type": "strong", "text": "A strong text block."]))
        examples.append(("Small text", ["type": "small", "text": "A small-print caption."]))
        examples.append(("Emphasis", ["type": "emphasis", "inlineContent": [inline("An emphasized block.")]]))
        examples.append(("Inline code", ["type": "code", "code": ["let browser = Browser()"]]))
        examples.append(("Code voice", ["type": "codeVoice", "code": ["Browser.open(_:)"]]))
        examples.append(("Code listing and copy button", ["type": "codeListing", "code": [
            "import SwiftUI", "", "struct Welcome: View {", "    var body: some View {", "        Text(\"Welcome to DocC\")", "    }", "}"
        ]]))
        examples.append(("Unordered list", ["type": "unorderedList", "items": [["content": [paragraph("Choose a documentation source.")]], ["content": [paragraph("Browse a framework.")]]]]))
        examples.append(("Ordered list", ["type": "orderedList", "items": [["content": [paragraph("Open the browser.")]], ["content": [paragraph("Select an article.")]]]]))
        let term: [String: Any] = ["inlineContent": [inline("Reference")]]
        let definition: [String: Any] = ["content": [paragraph("A destination with a title, role, and identifier.")]]
        examples.append(("Term list", ["type": "termList", "items": [["term": term, "definition": definition]]]))
        let swiftTab: [String: Any] = ["title": "Swift", "content": [["type": "codeListing", "code": ["let title = \"Documentation\""]]]]
        let objcTab: [String: Any] = ["title": "Objective-C", "content": [["type": "codeListing", "code": ["NSString *title = @\"Documentation\";"]]]]
        let longTab: [String: Any] = ["title": "A longer tab title", "content": [paragraph("Try this tab at a narrow content width.")]]
        examples.append(("Tabs and multiline picker", ["type": "tabNavigator", "tabs": [swiftTab, objcTab, longTab]]))
        examples.append(("Table", ["type": "table", "rows": [
            [[paragraph("Platform")], [paragraph("Minimum version")]],
            [[paragraph("iOS")], [paragraph("18.0")]], [[paragraph("macOS")], [paragraph("15.0")]]
        ]]))
        examples.append(("Adaptive row and columns", ["type": "row", "numberOfColumns": 2, "columns": [
            ["size": 1, "content": [paragraph("First column")]], ["size": 1, "content": [paragraph("Second column")]]
        ]]))
        examples.append(("Image and enlarged image sheet", ["type": "image", "identifier": "playground-image"]))
        examples.append(("Reference", ["type": "reference", "identifier": identifiers[1]]))
        examples.append(("Link grid", ["type": "links", "style": "compactGrid", "items": identifiers]))
        examples.append(("Embedded callout", ["type": "aside", "style": "note", "content": [paragraph("This callout is embedded in article content.")]]))
        examples.append(("Thematic break", ["type": "thematicBreak"]))
        return examples
    }

    private static func endpointSections(identifiers: [String]) -> [[String: Any]] {
        let type: [String: Any] = ["text": "Browser", "kind": "typeIdentifier", "identifier": "docc-playground://playground/documentation/Browser"]
        let property: [String: Any] = ["name": "title", "type": [["text": "String", "kind": "text"]], "content": [paragraph("The bookmark's display title.")]]
        var sections: [[String: Any]] = []
        sections.append(["kind": "restEndpoint", "title": "URL", "tokens": [["kind": "text", "text": "POST https://api.example.invalid/bookmarks"]]])
        sections.append(["kind": "restBody", "title": "Request Body", "bodyContentType": [type], "mimeType": "application/json", "content": [paragraph("The bookmark to create.")]])
        sections.append(["kind": "restParameters", "title": "Query Parameters", "items": [property]])
        sections.append(["kind": "properties", "title": "Properties", "items": [property]])
        let responses: [[String: Any]] = [
            ["status": 201, "reason": "Created", "type": [type], "content": [paragraph("The new bookmark.")]],
            ["status": 400, "reason": "Invalid request", "type": [type], "content": [paragraph("Check the supplied title.")]]
        ]
        sections.append(["kind": "restResponses", "title": "Responses", "mimeType": "application/json", "items": responses])
        sections.append(["kind": "attributes", "title": "Attributes", "attributes": [["name": "required"]]])
        sections.append(["kind": "details", "details": ["name": "Bookmark", "value": [["baseType": "dictionary"]]]])
        sections.append(["kind": "mentions", "mentions": identifiers])
        return sections
    }

    private static func homepageSections(identifiers: [String]) -> [[String: Any]] {
        let destination = reference("BrowserKit", id: identifiers[0], roleHeading: "Framework")
        var sections: [[String: Any]] = []
        sections.append(["kind": "hero", "title": "Explore BrowserKit", "content": [paragraph("Build a documentation experience with SwiftUI.")]])
        sections.append(["kind": "section", "title": "Getting started", "body": ["kind": "links", "links": [["type": "links", "style": "detailedGrid", "items": identifiers]]]])
        let sampleCard: [String: Any] = [
            "title": "Build your first browser", "eyebrow": "SAMPLE CODE", "destination": destination,
            "image": "playground-image", "content": [paragraph("Explore a complete SwiftUI documentation interface.")],
            "callToAction": ["web": "View sample"]
        ]
        let guideCard: [String: Any] = [
            "title": "Organize your references", "eyebrow": "GUIDE", "destination": destination,
            "content": [paragraph("Group related symbols and articles.")], "callToActionText": ["web": "Read guide"]
        ]
        sections.append(["kind": "section", "title": "Featured", "body": ["kind": "cards", "cards": [["isFeatured": true, "cards": [sampleCard, guideCard]]]]])
        let highlight: [String: Any] = [
            "title": "Made for discovery", "content": [paragraph("Find the content you need with clear navigation.")],
            "callToActionText": "Explore", "destination": "https://playground.invalid/explore"
        ]
        sections.append(["kind": "section", "title": "Highlights", "body": ["kind": "highlightedLinks", "image": "playground-image", "highlightedLinks": [highlight]]])
        sections.append(["kind": "section", "title": "Quick links", "body": ["kind": "homepageLinks", "homepageLinks": [destination]]])
        let resources: [[String: Any]] = [
            ["title": "Documentation", "destination": destination, "content": [paragraph("Browse API references and guides.")]],
            ["title": "Sample code", "destination": destination, "content": [paragraph("Learn through working examples.")]]
        ]
        sections.append(["kind": "homepageResources", "title": "Resources", "resources": resources])
        return sections
    }

    /// Produces a temporary image so image renderers and enlargement work without a server.
    private static func makeImage() throws -> URL {
        let artwork = ZStack {
            LinearGradient(colors: [.indigo, .purple, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "doc.richtext")
                .font(.system(size: 96, weight: .medium))
                .foregroundStyle(.white)
        }
        .frame(width: 600, height: 320)
        let renderer = ImageRenderer(content: artwork)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("docc-playground-\(UUID().uuidString).png")
        guard let image = renderer.cgImage,
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        // The renderer's asset resolver requires a host to preserve an absolute media URL.
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.host = "localhost"
        return components?.url ?? url
    }
}

#endif
