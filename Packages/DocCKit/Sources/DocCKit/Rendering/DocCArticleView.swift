import SwiftUI

/// Renders a DocC article payload.
public struct DocCArticleView<Navigator: DocCNavigator>: View {
    /// Article payload to render.
    private let article: Article
    /// Reference represented by the article.
    private let reference: Reference
    /// Flattened render rows used as direct vertical-stack children.
    private let renderItems: [ArticleRenderItem]
    /// Whether to show symbol kind badges in reference list rows.
    private let showsReferenceSymbolBadges: Bool
    /// Host-app navigation coordinator.
    @State private var navigator: Navigator
    
    @State private var gradientState = ArticleGradientState()
    @State private var headerSize: CGSize?
    
    /// Creates an article renderer.
    ///
    /// - Parameters:
    ///   - article: Article payload to render.
    ///   - reference: Reference represented by the article.
    ///   - navigator: Host-app navigation coordinator.
    ///   - showsReferenceSymbolBadges: Whether to show symbol kind badges in reference list rows.
    public init(article: Article, reference: Reference, navigator: Navigator, showsReferenceSymbolBadges: Bool = false) {
        self.article = article
        self.reference = reference
        self.renderItems = ArticleRenderPlan(article: article).items
        self.showsReferenceSymbolBadges = showsReferenceSymbolBadges
        self.navigator = navigator
    }
    
    /// Creates an article renderer from a render-ready page.
    ///
    /// - Parameters:
    ///   - page: Render-ready article page.
    ///   - navigator: Host-app navigation coordinator.
    ///   - showsReferenceSymbolBadges: Whether to show symbol kind badges in reference list rows.
    public init(page: DocCArticlePage, navigator: Navigator, showsReferenceSymbolBadges: Bool = false) {
        self.init(article: page.article, reference: page.reference, navigator: navigator, showsReferenceSymbolBadges: showsReferenceSymbolBadges)
    }
    
    /// Creates an article renderer by synthesizing a lightweight reference from the article metadata.
    ///
    /// - Parameters:
    ///   - article: Article payload to render.
    ///   - navigator: Host-app navigation coordinator.
    ///   - showsReferenceSymbolBadges: Whether to show symbol kind badges in reference list rows.
    public init(article: Article, navigator: Navigator, showsReferenceSymbolBadges: Bool = false) {
        self.init(article: article, navigator: navigator, identifier: nil, showsReferenceSymbolBadges: showsReferenceSymbolBadges)
    }
    
    /// Creates an article renderer by synthesizing a lightweight reference from the article metadata.
    ///
    /// - Parameters:
    ///   - article: Article payload to render.
    ///   - navigator: Host-app navigation coordinator.
    ///   - identifier: Optional canonical article identifier. If omitted, DocCKit creates a local identifier from the article title.
    ///   - docCSite: Optional custom DocC source used to resolve relative assets.
    ///   - showsReferenceSymbolBadges: Whether to show symbol kind badges in reference list rows.
    public init(article: Article, navigator: Navigator, identifier: String? = nil, docCSite: DocCSource? = nil, showsReferenceSymbolBadges: Bool = false) {
        self.init(
            article: article,
            reference: Reference(
                title: article.metadata.title,
                identifier: identifier ?? Self.defaultIdentifier(for: article),
                type: "article",
                role: article.metadata.role,
                roleHeading: article.metadata.roleHeading,
                docCSite: docCSite
            ),
            navigator: navigator,
            showsReferenceSymbolBadges: showsReferenceSymbolBadges
        )
    }
    
    /// The general accent color.
    public var accentColor: Color? {
        if let standardColorIdentifier = article.metadata.color?.standardColorIdentifier {
            return standardColorIdentifier.readableAccentColor
        }
        
        // Keep contrast good
        guard article.metadata.role != .article else {
            return nil
        }
        
        return article.metadata.role.readableAccentColor
    }
    
    /// Gradient colors resolved from article metadata role/color.
    public var topColorGradient: [Color] {
        article.metadata.color?.gradientColors ?? article.metadata.role.gradientColors
    }
    
    public var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading) {
                ArticleHeadingView(article: article, reference: reference)
                    .padding(.bottom, 15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onGeometryChange(for: CGSize.self) { proxy in
                        proxy.size
                    } action: { size in
                        guard headerSize != size else { return }
                        headerSize = size
                    }
                
                ForEach(renderItems) { item in
                    ArticleRenderItemView(item: item, article: article, showsReferenceSymbolBadges: showsReferenceSymbolBadges)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 15)
            .padding([.horizontal, .bottom], 30)
            
            if let legalNotices = article.legalNotices {
                DocCLegalNoticesView(legalNotices: legalNotices)
                    .padding([.horizontal, .bottom])
            }
        }
        .lineSpacing(4)
        .scrollContentBackground(.hidden)
        .defaultScrollAnchor(.center, for: .sizeChanges)
        .background {
            #if canImport(UIKit)
            if UIDevice.current.userInterfaceIdiom != .vision { // disable for visionOS due to state bugs
                ElasticArticleGradientBackground(colors: topColorGradient, baseHeight: gradientBaseHeight, state: gradientState)
            }
            #else
            ElasticArticleGradientBackground(colors: topColorGradient, baseHeight: gradientBaseHeight, state: gradientState)
            #endif
        }
        .environment(\.docCSite, reference.docCSite ?? navigator.technology?.docCSite)
        .environment(\.docCIsUsingSplitView, navigator.isUsingSplitView)
        .environment(\.docCDeepLinkScheme, navigator.deepLinkScheme)
        .environment(\.docCNavigateToReference, DocCReferenceNavigationAction { reference in
            navigator.setReference(reference, forceHistory: false)
        })
        .docCTintColor(accentColor)
        .accentColor(accentColor)
    }
    
    private var gradientBaseHeight: CGFloat {
        (headerSize?.height ?? 0) + 50
    }
    
    private static func defaultIdentifier(for article: Article) -> String {
        let slug = article.metadata.title
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: "-")
        
        return "doc://article/\(slug.isEmpty ? "untitled" : slug)"
    }
}

private struct ArticleHeadingView: View {
    let article: Article
    let reference: Reference
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if (article.metadata.roleHeading != nil || article.metadata.platforms != nil) && article.topicSectionsStyle != .hidden {
                HStack(spacing: 15) {
                    if let roleHeading = article.metadata.roleHeading {
                        Text(roleHeading)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    
                    ArticleHeadingBadge(article: article, reference: reference)
                }
                .font(.headline)
                .padding(.bottom, 5)
            }
            
            Text(article.metadata.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .textSelection(.enabled)
            
            if let abstract = article.abstract {
                AbstractView(abstract: abstract)
                    .textSelection(.enabled)
            }
            
            if let sampleCodeDownload = article.sampleCodeDownload {
                DownloadButtonView(sampleCodeDownload: sampleCodeDownload, references: article.references)
            }
            
            if let platforms = article.metadata.platforms {
                WrappingHStack(alignment: .leading, horizontalSpacing: 10) {
                    ForEach(platforms) { platform in
                        PlatformCapsule(platform: platform)
                    }
                }
            }
        }
        .multilineTextAlignment(.leading)
        .lineSpacing(3)
    }
}

private struct ArticleHeadingBadge: View {
    let article: Article
    let reference: Reference
    
    var body: some View {
        if let platforms = article.metadata.platforms {
            if platforms.allSatisfy({ $0.beta == true }) || reference.beta == true || article.betaSummary != nil {
                ArticleBadge(badge: .beta)
            }
            if platforms.allSatisfy({ $0.deprecated == true || $0.deprecatedAt != nil }) || article.deprecationSummary != nil || reference.deprecated == true {
                ArticleBadge(badge: .deprecated)
            }
        }
    }
}

private struct ArticleRenderPlan {
    let items: [ArticleRenderItem]
    
    init(article: Article) {
        var items: [ArticleRenderItem] = []
        
        if let betaSummary = article.betaSummary {
            items.append(.init(id: "aside-beta", kind: .aside(style: .experiment, content: betaSummary)))
        }
        
        if let deprecationSummary = article.deprecationSummary {
            items.append(.init(id: "aside-deprecation", kind: .aside(style: .deprecated, content: deprecationSummary)))
        }
        
        for section in article.primaryContentSections ?? [] {
            switch section.kind {
            case .content:
                for content in section.condensedContent {
                    items.append(.init(
                        id: "primary-\(section.id.uuidString)-content-\(content.id.uuidString)",
                        kind: .content(content)
                    ))
                }
            case .declarations:
                for declaration in section.declarations ?? [] {
                    items.append(.init(
                        id: "primary-\(section.id.uuidString)-declaration-\(declaration.id.uuidString)",
                        kind: .declaration(declaration)
                    ))
                }
            case .mentions:
                items.append(.init(
                    id: "primary-\(section.id.uuidString)-mentions",
                    kind: .mentions(section.mentions ?? [])
                ))
            case .details:
                if let details = section.details {
                    items.append(.init(
                        id: "primary-\(section.id.uuidString)-details",
                        kind: .details(details)
                    ))
                }
            case .restBody:
                items.append(.init(
                    id: "primary-\(section.id.uuidString)-rest-body",
                    kind: .restBody(section)
                ))
            case .restEndpoint:
                items.append(.init(
                    id: "primary-\(section.id.uuidString)-rest-endpoint",
                    kind: .restEndpoint(section)
                ))
            case .restResponses:
                items.append(.init(
                    id: "primary-\(section.id.uuidString)-rest-responses",
                    kind: .restResponses(section)
                ))
            case .properties, .restParameters:
                items.append(.init(
                    id: "primary-\(section.id.uuidString)-rest-properties",
                    kind: .restProperties(section)
                ))
            case .attributes:
                items.append(.init(
                    id: "primary-\(section.id.uuidString)-rest-attributes",
                    kind: .restAttributes(section)
                ))
            default:
                for content in section.content ?? [] {
                    items.append(.init(
                        id: "primary-\(section.id.uuidString)-raw-content-\(content.id.uuidString)",
                        kind: .content(content)
                    ))
                }
            }
        }
        
        Self.appendFooterItems(
            to: &items,
            namespace: "topics",
            title: "Topics",
            sections: article.topicSections,
            style: article.topicSectionsStyle ?? .list,
            sectionHeadingStyle: .prominent
        )
        Self.appendFooterItems(
            to: &items,
            namespace: "relationships",
            title: "Relationships",
            sections: article.relationshipsSections,
            style: .list,
            sectionHeadingStyle: .plain
        )
        Self.appendFooterItems(
            to: &items,
            namespace: "see-also",
            title: "See Also",
            sections: article.seeAlsoSections,
            style: .list,
            sectionHeadingStyle: .prominent
        )
        
        self.items = items
    }
    
    private static func appendFooterItems(
        to items: inout [ArticleRenderItem],
        namespace: String,
        title: String,
        sections: [Framework.TopicSection]?,
        style: ContentSection.Content.Style,
        sectionHeadingStyle: ArticleFooterSectionHeadingStyle
    ) {
        guard let sections, style != .hidden else { return }
        
        items.append(.init(id: "\(namespace)-divider", kind: .divider))
        items.append(.init(id: "\(namespace)-title", kind: .footerTitle(title)))
        
        for section in sections {
            if let title = section.title {
                items.append(.init(
                    id: "\(namespace)-section-\(section.id.uuidString)-title",
                    kind: .footerSectionTitle(title, style: sectionHeadingStyle)
                ))
            }
            
            switch style {
            case .list:
                for (index, identifier) in section.identifiers.enumerated() {
                    items.append(.init(
                        id: "\(namespace)-section-\(section.id.uuidString)-link-\(index)-\(identifier)",
                        kind: .referenceLink(identifier)
                    ))
                }
            default:
                items.append(.init(
                    id: "\(namespace)-section-\(section.id.uuidString)-links",
                    kind: .linkSection(identifiers: section.identifiers, style: style)
                ))
            }
        }
    }
}

private struct ArticleRenderItem: Identifiable {
    let id: String
    let kind: Kind
    
    init(id: String, kind: Kind) {
        self.id = id
        self.kind = kind
    }
    
    enum Kind {
        case aside(style: ContentSection.Content.Style, content: [ContentSection.Content])
        case content(ContentSection.Content)
        case declaration(ContentSection.Declaration)
        case mentions([String])
        case details(ContentSection.Details)
        case restBody(ContentSection)
        case restEndpoint(ContentSection)
        case restResponses(ContentSection)
        case restProperties(ContentSection)
        case restAttributes(ContentSection)
        case divider
        case footerTitle(String)
        case footerSectionTitle(String, style: ArticleFooterSectionHeadingStyle)
        case referenceLink(String)
        case linkSection(identifiers: [String], style: ContentSection.Content.Style)
    }
}

private enum ArticleFooterSectionHeadingStyle {
    case plain
    case prominent
}

private struct ArticleRenderItemView: View {
    let item: ArticleRenderItem
    let article: Article
    let showsReferenceSymbolBadges: Bool
    
    var body: some View {
        Group {
            switch item.kind {
            case .aside(let style, let content):
                AsideView(style: style, content: content, references: article.references)
            case .content(let content):
                ArticleContentView(content: content, references: article.references)
                    .padding(.top, content.type == .heading ? nil : 0)
            case .declaration(let declaration):
                DeclarationContentView(content: declaration, article: article)
            case .mentions(let mentions):
                MentionsView(mentions: mentions, article: article)
            case .details(let details):
                DetailsView(details: details)
            case .restBody(let section):
                WebEndpointRestBody(contentSection: section, references: article.references)
            case .restEndpoint(let section):
                WebEndpointRestEndPoint(contentSection: section, references: article.references)
            case .restResponses(let section):
                WebEndpointRestResponse(contentSection: section, references: article.references)
            case .restProperties(let section):
                WebEndpointRestPropertiesView(contentSection: section, references: article.references)
            case .restAttributes(let section):
                WebEndpointRestAttributesView(contentSection: section, references: article.references)
            case .divider:
                Divider()
                    .padding(.vertical)
            case .footerTitle(let title):
                Text(title)
                    .font(.title2)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .footerSectionTitle(let title, let style):
                footerSectionTitle(title, style: style)
            case .referenceLink(let identifier):
                DocCReferenceListRow(identifier: identifier, references: article.references, showsSymbolKindBadge: showsReferenceSymbolBadges)
            case .linkSection(let identifiers, let style):
                LinksGridListView(identifiers: identifiers, style: style, references: article.references, showsSymbolKindBadge: showsReferenceSymbolBadges)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private func footerSectionTitle(_ title: String, style: ArticleFooterSectionHeadingStyle) -> some View {
        switch style {
        case .plain:
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .prominent:
            Text(title)
                .font(.title3)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

@Observable
@MainActor
private final class ArticleGradientState {
    var scrollOffset: CGFloat = 0
}

private struct ElasticArticleGradientBackground: View {
    let colors: [Color]
    let baseHeight: CGFloat
    let state: ArticleGradientState
    
    var body: some View {
        let scrollOffset = state.scrollOffset
        
        ZStack(alignment: .top) {
            Color(platformColor: .systemBackground)
            LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
                .frame(height: baseHeight - min(0, scrollOffset))
                .offset(y: -max(0, scrollOffset))
        }
        .ignoresSafeArea()
        .docCBackgroundExtensionEffectIfAvailable()
    }
}
