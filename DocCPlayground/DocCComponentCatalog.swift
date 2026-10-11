#if DEBUG
import SwiftUI
@testable import DocCKit

/// Groups related renderers so the catalog can be explored without scrolling through every family.
enum CatalogFamily: String, CaseIterable {
    case all = "All components"
    case callouts = "Callouts"
    case badges = "Badges and availability"
    case text = "Text and headings"
    case code = "Code and declarations"
    case lists = "Lists and definitions"
    case tabs = "Tabs and pickers"
    case tables = "Tables"
    case layouts = "Rows and wrapping layouts"
    case links = "Reference links"
    case article = "Article headers and sections"
    case rest = "REST components"
    case homepage = "Homepage components"
    case media = "Images and video"
    case footer = "Downloads and legal notices"
}

/// Displays real DocCKit components in representative combinations of content, layout, and state.
@MainActor
struct DocCComponentCatalog: View {
    /// Shared local documentation and image fixtures.
    let samples: PlaygroundSamples
    /// Selected component family, or all families.
    let family: CatalogFamily
    /// Text used to narrow the visible families.
    let filter: String
    /// Editable content used by callout samples.
    let text: String
    /// Optional video source entered in the playground controls.
    let videoURL: String
    /// Shared navigator that records link selections.
    let navigator: PlaygroundNavigator

    private let calloutStyles: [ContentSection.Content.Style] = [.note, .tip, .important, .warning, .experiment, .deprecated]
    private let linkStyles: [ContentSection.Content.Style] = [.list, .compactGrid, .detailedGrid, .hidden]
    private let badgeSizes: [CGFloat] = [16, 24, 40]

    private var visibleFamilies: [CatalogFamily] {
        CatalogFamily.allCases.filter {
            $0 != .all && (family == .all || family == $0)
                && (filter.isEmpty || $0.rawValue.localizedCaseInsensitiveContains(filter))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Text("Component catalog")
                    .font(.largeTitle.bold())
                Text("Compare each component’s common states together. Links, copy buttons, tabs, and image enlargement remain interactive.")
                    .foregroundStyle(.secondary)
                switch CatalogFixtures.shared {
                case .success(let fixtures):
                    if visibleFamilies.isEmpty {
                        ContentUnavailableView.search(text: filter)
                    }
                    ForEach(visibleFamilies, id: \.self) { family in
                        VStack(alignment: .leading, spacing: 18) {
                            Text(family.rawValue).font(.title.bold())
                            familyContent(family, fixtures: fixtures)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Divider()
                    }
                case .failure(let error):
                    ContentUnavailableView("Couldn’t create catalog", systemImage: "exclamationmark.triangle", description: Text(error.localizedDescription))
                }
            }
            .padding(24)
        }
        .id(family)
    }

    @ViewBuilder
    private func familyContent(_ family: CatalogFamily, fixtures: CatalogFixtures) -> some View {
        switch family {
        case .callouts: callouts(fixtures)
        case .badges: badges
        case .links: referenceLinks(fixtures)
        case .article: articleSections
        case .rest: restComponents(fixtures)
        case .homepage: homepageComponents(fixtures)
        case .media: media(fixtures)
        case .footer: footer(fixtures)
        case .layouts:
            contentExamples(fixtures.groups[family] ?? [])
            wrappingLayouts
        case .code:
            contentExamples(fixtures.groups[family] ?? [])
            declarations(fixtures)
        case .text:
            contentExamples(fixtures.groups[family] ?? [])
            abstractVariants(fixtures)
        case .lists, .tabs, .tables:
            contentExamples(fixtures.groups[family] ?? [])
        case .all: EmptyView()
        }
    }

    private func card<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))
    }

    private func callouts(_ fixtures: CatalogFixtures) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("All six callout styles").font(.title2.bold())
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 270), alignment: .top)], alignment: .leading, spacing: 16) {
                ForEach(calloutStyles, id: \.self) { style in
                    AsideView(style: style, content: samples.message(text), references: samples.baseArticle.references)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id("short-\(style.rawValue)-\(text)")
                }
            }
            Text("Multiline and rich content").font(.title2.bold())
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 330), alignment: .top)], alignment: .leading, spacing: 16) {
                ForEach(calloutStyles, id: \.self) { style in
                    AsideView(style: style, content: richCalloutContent(fixtures), references: samples.baseArticle.references)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id("rich-\(style.rawValue)-\(text)")
                }
            }
        }
    }

    private func richCalloutContent(_ fixtures: CatalogFixtures) -> [ContentSection.Content] {
        samples.message(text + " This longer example wraps across several lines, so you can compare padding and readability at different widths.")
            + fixtures.richCalloutBlocks
    }

    private var badges: some View {
        VStack(alignment: .leading, spacing: 18) {
            card("Article status · normal, beta, deprecated, both") {
                WrappingHStack(horizontalSpacing: 24, verticalSpacing: 16) {
                    Text("Normal")
                    ArticleBadge(badge: .beta)
                    ArticleBadge(badge: .deprecated)
                    HStack { ArticleBadge(badge: .beta); ArticleBadge(badge: .deprecated) }
                }
            }
            card("Every symbol kind · 16, 24, and 40 pt") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), alignment: .leading)], alignment: .leading, spacing: 20) {
                    ForEach(PlaygroundSamples.symbolKinds, id: \.self) { kind in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(SidebarSearchSymbolKind.title(for: kind, fallback: "Unknown")).font(.caption)
                            HStack(spacing: 18) {
                                ForEach(badgeSizes, id: \.self) { size in
                                    DocCSymbolBadge(symbolKind: kind, size: size)
                                }
                            }
                        }
                    }
                }
            }
            card("Custom artwork · 16, 24, and 40 pt") {
                HStack(spacing: 18) {
                    ForEach(badgeSizes, id: \.self) { size in
                        DocCSymbolBadge(symbolKind: .framework, size: size, customImageIdentifier: "playground-image", references: samples.baseArticle.references)
                    }
                }
            }
            ForEach(CatalogAvailability.allCases, id: \.self) { state in
                card(state.rawValue) {
                    WrappingHStack(horizontalSpacing: 12, verticalSpacing: 12) {
                        ForEach(["iOS", "macOS", "visionOS"], id: \.self) { name in
                            PlatformCapsule(platform: state.platform(name))
                        }
                    }
                }
            }
        }
    }

    private func contentExamples(_ examples: [CatalogContentExample]) -> some View {
        ForEach(examples) { example in
            card(example.title) {
                ArticleContentView(content: example.content, references: samples.baseArticle.references)
            }
        }
    }

    private func abstractVariants(_ fixtures: CatalogFixtures) -> some View {
        ForEach(fixtures.abstracts) { example in
            card("Abstract · \(example.title)") {
                AbstractView(abstract: example.content.inlineContent ?? [])
            }
        }
    }

    private func declarations(_ fixtures: CatalogFixtures) -> some View {
        ForEach(fixtures.declarations.indices, id: \.self) { index in
            card("Declaration · \(fixtures.declarationLabels[index])") {
                DeclarationContentView(content: fixtures.declarations[index], article: samples.baseArticle)
            }
        }
    }

    private var wrappingLayouts: some View {
        ForEach([HorizontalAlignment.leading, .center, .trailing].indices, id: \.self) { index in
            card("WrappingHStack · \(["Leading", "Center", "Trailing"][index])") {
                WrappingHStack(alignment: Alignment(horizontal: [.leading, .center, .trailing][index], vertical: .top), horizontalSpacing: 12, verticalSpacing: 12) {
                    ForEach(["Short", "A longer capsule", "Documentation", "One", "An especially long item that should wrap", "Last"], id: \.self) { value in
                        Text(value).padding(8).background(.quaternary, in: Capsule())
                    }
                }
            }
        }
    }

    private func referenceLinks(_ fixtures: CatalogFixtures) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(linkStyles, id: \.self) { style in
                card("Layout · \(style.rawValue)") {
                    LinksGridListView(identifiers: fixtures.referenceIDs, style: style, references: fixtures.references, showsSymbolKindBadge: true)
                    if style == .hidden { Text("Hidden layout emits no links.").foregroundStyle(.secondary) }
                }
            }
            ForEach([false, true], id: \.self) { badges in
                card("List rows · \(badges ? "symbol badges" : "role icons")") {
                    LinksGridListView(identifiers: fixtures.referenceIDs, style: .list, references: fixtures.references, showsSymbolKindBadge: badges)
                }
            }
            ForEach(["Leading", "Center", "Trailing"].indices, id: \.self) { index in
                card("Reference alignment · \(["Leading", "Center", "Trailing"][index])") {
                    LinksGridListView(identifiers: Array(fixtures.referenceIDs.prefix(2)), style: .list, references: fixtures.references)
                        .multilineTextAlignment([.leading, .center, .trailing][index])
                }
            }
            card("Empty list and missing reference") {
                LinksGridListView(identifiers: ["missing-reference"], style: .list, references: [:])
                Text("Missing references and empty lists emit no rows.").foregroundStyle(.secondary)
            }
        }
    }

    private var articleSections: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach([Role.article, .symbol, .sampleCode, .collection, .collectionGroup], id: \.self) { role in
                articleHeader(role: role, beta: false, deprecated: false)
            }
            articleHeader(role: .symbol, beta: true, deprecated: false)
            articleHeader(role: .symbol, beta: false, deprecated: true)
            articleHeader(role: .symbol, beta: true, deprecated: true)
            ForEach(linkStyles.filter { $0 != .hidden }, id: \.self) { style in
                card("Topics · \(style.rawValue)") {
                    TopicsView(article: samples.article(title: "Browser", text: text, role: .symbol, status: (false, false), style: style))
                }
            }
            card("Relationships") { RelationshipsView(article: samples.baseArticle) }
            card("See also") { SeeAlsoView(article: samples.baseArticle) }
            card("Mentions · one and multiple") {
                MentionsView(mentions: Array(samples.identifiers.prefix(1)), article: samples.baseArticle)
                Divider()
                MentionsView(mentions: samples.identifiers, article: samples.baseArticle)
            }
            card("Details") {
                if let details = samples.baseArticle.primaryContentSections?.compactMap(\.details).first {
                    DetailsView(details: details)
                }
            }
        }
    }

    private func articleHeader(role: Role, beta: Bool, deprecated: Bool) -> some View {
        var article = samples.article(title: "A long documentation title for \(role.rawValue)", text: text, role: role, status: (beta, deprecated), style: .hidden)
        article.primaryContentSections = []
        // Use a header-only document to exercise the real private article heading renderer.
        let header = CatalogFixtures.headerOnly(article)
        return card("Header · \(role.rawValue) · \(beta ? "beta" : "stable")\(deprecated ? " + deprecated" : "")") {
            DocCArticleView(article: header, navigator: navigator)
                .frame(height: beta && deprecated ? 360 : (beta || deprecated ? 300 : 230))
        }
    }

    private func restComponents(_ fixtures: CatalogFixtures) -> some View {
        ForEach(fixtures.rest) { example in
            card(example.title) {
                restComponent(example.section)
            }
        }
    }

    @ViewBuilder
    private func restComponent(_ section: ContentSection) -> some View {
        switch section.kind {
        case .restEndpoint: WebEndpointRestEndPoint(contentSection: section, references: samples.baseArticle.references)
        case .restBody: WebEndpointRestBody(contentSection: section, references: samples.baseArticle.references)
        case .restResponses: WebEndpointRestResponse(contentSection: section, references: samples.baseArticle.references)
        case .properties, .restParameters, .parameters: WebEndpointRestPropertiesView(contentSection: section, references: samples.baseArticle.references)
        case .attributes: WebEndpointRestAttributesView(contentSection: section, references: samples.baseArticle.references)
        default: EmptyView()
        }
    }

    private func homepageComponents(_ fixtures: CatalogFixtures) -> some View {
        ForEach(fixtures.homepage) { example in
            card(example.title) {
                switch example.section.kind {
                case .hero: HomepageHero(section: example.section, homepage: samples.homepage)
                case .section: HomepageSection(section: example.section, homepage: samples.homepage)
                case .homepageResources: HomepageResources(section: example.section, homepage: samples.homepage)
                }
            }
        }
    }

    private func media(_ fixtures: CatalogFixtures) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            contentExamples(fixtures.groups[.media] ?? [])
            card("Video · no source") {
                ArticleContentView(content: samples.video, references: [:]).frame(height: 200)
            }
            if let url = URL(string: videoURL), ["https", "http", "file"].contains(url.scheme?.lowercased() ?? "") {
                card("Video · supplied source") {
                    ArticleContentView(content: samples.video, references: [
                        "playground-video": Reference(identifier: "playground-video", type: "video", variants: [.init(url: url.absoluteString, traits: [])])
                    ])
                    .frame(height: 260)
                    .id(url)
                }
            }
        }
    }

    private func footer(_ fixtures: CatalogFixtures) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(fixtures.downloads.indices, id: \.self) { index in
                card("Download · \(["Active", "Custom title", "Inactive"][index])") {
                    DownloadButtonView(sampleCodeDownload: fixtures.downloads[index], references: samples.baseArticle.references)
                }
            }
            ForEach(fixtures.notices.indices, id: \.self) { index in
                card("Legal notices · \(["Copyright only", "All links", "Empty copyright and invalid URLs"][index])") {
                    DocCLegalNoticesView(legalNotices: fixtures.notices[index])
                }
            }
        }
    }
}

/// Representative availability combinations across each platform capsule.
private enum CatalogAvailability: String, CaseIterable {
    case unversioned = "No introduction version"
    case stable = "Introduced version"
    case beta = "Beta"
    case deprecated = "Deprecated flag"
    case range = "Introduction and deprecation versions"
    case both = "Beta and deprecated"
    case unavailable = "Unavailable metadata"

    func platform(_ name: String) -> Platform {
        Platform(introducedAt: self == .unversioned ? nil : "18.0", unavailable: self == .unavailable, beta: self == .beta || self == .both, name: name, deprecated: self == .deprecated || self == .both, deprecatedAt: self == .range || self == .both ? "26.0" : nil)
    }
}

private struct CatalogContentExample: Identifiable {
    let title: String
    let content: ContentSection.Content
    var id: String { title }
}

private struct CatalogRESTExample: Identifiable {
    let title: String
    let section: ContentSection
    var id: String { title }
}

private struct CatalogHomepageExample: Identifiable {
    let title: String
    let section: HomepageParser.Section
    var id: String { title }
}

/// Decodes stable fixture identities once for all catalog variants.
@MainActor
private struct CatalogFixtures {
    typealias JSON = [String: Any]
    static let shared = Result { try CatalogFixtures(samples: PlaygroundSamples.shared.get()) }
    var groups: [CatalogFamily: [CatalogContentExample]] = [:]
    var abstracts: [CatalogContentExample] = []
    let richCalloutBlocks: [ContentSection.Content]
    var declarations: [ContentSection.Declaration] = []
    var declarationLabels: [String] = []
    var references: [String: Reference]
    var referenceIDs: [String]
    var rest: [CatalogRESTExample] = []
    var homepage: [CatalogHomepageExample] = []
    var downloads: [Article.SampleCodeDownload] = []
    var notices: [LegalNotices] = []

    private init(samples: PlaygroundSamples) throws {
        // Give the copied rich paragraph a separate identity from the editable paragraph.
        let richBlocks = samples.blocks.filter { $0.type == .paragraph || $0.type == .codeListing }
        richCalloutBlocks = try JSONDecoder().decode([ContentSection.Content].self, from: JSONEncoder().encode(richBlocks))
        references = samples.baseArticle.references
        referenceIDs = samples.identifiers
        for (label, type) in [("External reference", "link"), ("Unresolvable reference", "unresolvable"), ("A very long reference title that wraps across several lines at narrow widths", "topic")] {
            let id = "doc://catalog/\(referenceIDs.count)"
            references[id] = try Self.decode(["identifier": id, "title": label, "type": type, "role": "article", "url": "https://example.invalid/guide", "abstract": [Self.inline("A longer abstract tests wrapping and the spacing between reference titles and descriptions.")]])
            referenceIDs.append(id)
        }
        for level in 1...6 {
            try add(.text, "Heading level \(level)", ["type": "heading", "level": level, "text": "Heading level \(level)", "anchor": "heading-\(level)"])
        }
        for (index, block) in samples.blocks.enumerated() {
            let family: CatalogFamily
            switch block.type {
            case .heading, .paragraph, .text, .strong, .small, .emphasis, .reference, .thematicBreak: family = .text
            case .code, .codeVoice, .codeListing: family = .code
            case .unorderedList, .orderedList, .termList: family = .lists
            case .tabNavigator: family = .tabs
            case .table: family = .tables
            case .row: family = .layouts
            case .image: family = .media
            default: continue
            }
            groups[family, default: []].append(.init(title: samples.blockTitles[index], content: block))
        }
        let longText = "A longer paragraph shows wrapping, spacing, and readability at narrow widths. "
        try add(.text, "Long paragraph", Self.paragraph(String(repeating: longText, count: 5)))
        for font in CodableFont.allCases {
            try add(.text, "Inline font · \(font.rawValue)", ["type": "paragraph", "inlineContent": [["type": "text", "text": "Documentation typography", "font": font.rawValue]]])
        }
        for weight in CodableFontWeight.allCases {
            try add(.text, "Inline weight · \(weight.rawValue)", ["type": "paragraph", "inlineContent": [["type": "text", "text": "Documentation typography", "fontWeight": weight.rawValue]]])
        }
        for (title, nodes) in [("Short", [Self.inline("A short abstract.")]), ("Multiline", [Self.inline(String(repeating: longText, count: 3))]), ("Code and reference", [Self.inline("Use "), ["type": "codeVoice", "code": "Browser"], Self.inline(" to open "), ["type": "reference", "identifier": samples.identifiers[0]]])] {
            abstracts.append(.init(title: title, content: try Self.decode(["type": "paragraph", "inlineContent": nodes])))
        }
        for (title, code) in [("Single line", "let title = \"Documentation\""), ("Multiline", "func open(_ url: URL) async throws {\n    try await browser.load(url)\n}"), ("Long line", "let documentationURL = URL(string: \"https://example.invalid/documentation/browser/a-long-path-that-tests-code-wrapping\")!")] {
            try add(.code, title, ["type": "codeListing", "code": code.components(separatedBy: "\n")])
            declarationLabels.append(title)
            declarations.append(try Self.decode(["tokens": [["kind": "text", "text": code]], "languages": ["swift"]]))
        }
        for type in ["unorderedList", "orderedList"] {
            try add(.lists, "\(type) · nested and multiline", ["type": type, "items": [
                ["content": [Self.paragraph(String(repeating: longText, count: 2)), ["type": type, "items": [["content": [Self.paragraph("Nested first item")]], ["content": [Self.paragraph("Nested second item")]]]]]],
                ["content": [Self.paragraph("Final item")]]
            ]])
            try add(.lists, "\(type) · empty", ["type": type, "items": []])
        }
        try add(.lists, "Multiple definitions", ["type": "termList", "items": ["Symbol", "Article", "Collection"].map { name in
            ["term": ["inlineContent": [Self.inline(name)]], "definition": ["content": [Self.paragraph("A \(name.lowercased()) organizes the documentation browser."), Self.paragraph("Definitions may contain more than one paragraph.")]]]
        }])
        for count in [1, 2, 4, 6] {
            let tabs: [JSON] = (1...count).map { index in ["title": index == count && count > 1 ? "A longer title for tab \(index)" : "Tab \(index)", "content": [Self.paragraph("Content for tab \(index). Select another tab to compare its content.")]] }
            try add(.tabs, "\(count) tabs · \(count > 4 ? "scrolling picker" : "wrapping picker")", ["type": "tabNavigator", "tabs": tabs])
        }
        for count in [2, 3, 5] {
            let header = (1...count).map { [Self.paragraph("Column \($0)")] }
            let values = (1...count).map { [Self.paragraph($0 == count ? String(repeating: "Wrapping table content. ", count: 3) : "Value \($0)")] }
            try add(.tables, "\(count) columns · wrapping cells", ["type": "table", "rows": [header, values, values]])
        }
        try add(.tables, "Header only", ["type": "table", "rows": [[[Self.paragraph("Name")], [Self.paragraph("Value")]]]])
        try add(.tables, "Empty table", ["type": "table", "rows": []])
        for sizes in [[1], [1, 1, 1], [2, 1], [1, 2]] {
            let columns: [JSON] = sizes.enumerated().map { index, size in ["size": size, "content": [Self.paragraph("Column \(index + 1) · span \(size)"), Self.paragraph(String(repeating: longText, count: 2))]] }
            try add(.layouts, "Column spans · \(sizes.map(String.init).joined(separator: ":"))", ["type": "row", "numberOfColumns": sizes.reduce(0, +), "columns": columns])
        }
        try add(.media, "Inline image and caption", ["type": "paragraph", "inlineContent": [["type": "image", "identifier": "playground-image", "metadata": ["abstract": [Self.inline("A local image with an inline caption.")]]]]])
        try makeREST(samples)
        try makeHomepage(samples)
        for (active, title) in [(true, nil as String?), (true, "Get the SwiftUI sample"), (false, nil)] {
            var action: JSON = ["isActive": active, "identifier": "playground-download", "type": "reference"]
            if let title { action["overridingTitle"] = title }
            downloads.append(try Self.decode(["action": action]))
        }
        notices = [
            LegalNotices(copyright: "<p>© Playground Samples</p>", termsOfUse: "http://[", privacyPolicy: "http://["),
            LegalNotices(copyright: "<p>© Playground Samples</p>", termsOfUse: "https://example.invalid/terms", privacyPolicy: "https://example.invalid/privacy"),
            LegalNotices(copyright: "", termsOfUse: "http://[", privacyPolicy: "http://[")
        ]
    }

    private mutating func add(_ family: CatalogFamily, _ title: String, _ node: JSON) throws {
        groups[family, default: []].append(.init(title: title, content: try Self.decode(node)))
    }

    private mutating func makeREST(_ samples: PlaygroundSamples) throws {
        for section in samples.endpoint.primaryContentSections ?? [] where [.restEndpoint, .restBody, .restResponses, .restParameters, .properties, .attributes].contains(section.kind) {
            rest.append(.init(title: "\(section.kind.rawValue) · complete", section: section))
            var minimal = try Self.object(section)
            minimal.removeValue(forKey: "title")
            minimal.removeValue(forKey: "mimeType")
            rest.append(.init(title: "\(section.kind.rawValue) · no title or MIME type", section: try Self.decode(minimal)))
        }
        for method in ["GET", "PUT", "DELETE", "PATCH"] {
            let section: JSON = ["kind": "restEndpoint", "title": "URL", "tokens": [["kind": "text", "text": "\(method) https://api.example.invalid/bookmarks/{id}"]]]
            rest.append(.init(title: "Endpoint · \(method)", section: try Self.decode(section)))
        }
        let responses: [JSON] = [200, 201, 204, 400, 401, 404, 500].map { code in
            ["status": code, "reason": "HTTP \(code)", "type": [["text": "Browser", "kind": "typeIdentifier", "identifier": "docc-playground://playground/documentation/Browser"]], "content": [Self.paragraph("A representative HTTP response.")]]
        }
        rest.append(.init(title: "Responses · success and error statuses", section: try Self.decode(["kind": "restResponses", "title": "Responses", "mimeType": "application/json", "items": responses])))
        for kind in ["restParameters", "properties", "restResponses"] {
            rest.append(.init(title: "\(kind) · empty", section: try Self.decode(["kind": kind, "title": "Empty section", "items": []])))
        }
    }

    private mutating func makeHomepage(_ samples: PlaygroundSamples) throws {
        for section in samples.homepage.sections {
            let name = section.body?.kind.rawValue ?? section.kind.rawValue
            homepage.append(.init(title: "\(name) · complete", section: section))
            var alternate = try Self.object(section)
            if section.kind == .hero {
                alternate["image"] = "playground-image"
                homepage.append(.init(title: "Hero · image background", section: try Self.decode(alternate)))
                alternate.removeValue(forKey: "image")
                alternate.removeValue(forKey: "content")
                homepage.append(.init(title: "Hero · title only", section: try Self.decode(alternate)))
            } else if section.kind == .homepageResources {
                var resources = alternate["resources"] as? [JSON] ?? []
                if !resources.isEmpty { resources[0]["image"] = "playground-image" }
                alternate["resources"] = resources
                homepage.append(.init(title: "Resources · with artwork", section: try Self.decode(alternate)))
            } else if var body = alternate["body"] as? JSON {
                switch section.body?.kind {
                case .links:
                    for style in ["list", "compactGrid"] {
                        var newBody = body
                        newBody["links"] = [["type": "links", "style": style, "items": samples.identifiers]]
                        alternate["body"] = newBody
                        homepage.append(.init(title: "Homepage links · \(style)", section: try Self.decode(alternate)))
                    }
                case .cards:
                    var cards = body["cards"] as? [JSON] ?? []
                    for index in cards.indices { cards[index]["isFeatured"] = false }
                    body["cards"] = cards
                    alternate["body"] = body
                    homepage.append(.init(title: "Cards · regular grid", section: try Self.decode(alternate)))
                case .highlightedLinks:
                    body.removeValue(forKey: "image")
                    alternate["body"] = body
                    homepage.append(.init(title: "Highlighted links · text only", section: try Self.decode(alternate)))
                default: break
                }
            }
        }
    }

    static func headerOnly(_ article: Article) -> Article {
        Article(metadata: article.metadata, topicSectionsStyle: .hidden, abstract: article.abstract, primaryContentSections: [], references: article.references, legalNotices: nil, seeAlsoSections: nil, topicSections: nil, relationshipsSections: nil, sampleCodeDownload: nil, deprecationSummary: article.deprecationSummary, betaSummary: article.betaSummary, variants: nil, variantOverrides: nil)
    }

    private static func inline(_ text: String) -> JSON { ["type": "text", "text": text] }
    private static func paragraph(_ text: String) -> JSON { ["type": "paragraph", "inlineContent": [inline(text)]] }

    private static func decode<T: Decodable>(_ object: Any) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: object))
    }

    private static func object<T: Encodable>(_ value: T) throws -> JSON {
        guard let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? JSON else {
            throw CocoaError(.coderInvalidValue)
        }
        return object
    }
}
#endif
