import SwiftUI

/// Renders a DocC article payload.
public struct DocCArticleView<Navigator: DocCNavigator>: View {
    /// Article payload to render.
    private let article: Article
    /// Reference represented by the article.
    private let reference: Reference
    /// Host-app navigation coordinator.
    @State private var navigator: Navigator
    
    @State private var gradientState = ArticleGradientState()
    @State private var headerSize: CGSize?
    @State private var showToolbarBackground = false
    
    /// Creates an article renderer.
    ///
    /// - Parameters:
    ///   - article: Article payload to render.
    ///   - reference: Reference represented by the article.
    ///   - navigator: Host-app navigation coordinator.
    public init(article: Article, reference: Reference, navigator: Navigator) {
        self.article = article
        self.reference = reference
        self.navigator = navigator
    }
    
    /// Creates an article renderer from a render-ready page.
    ///
    /// - Parameters:
    ///   - page: Render-ready article page.
    ///   - navigator: Host-app navigation coordinator.
    public init(page: DocCArticlePage, navigator: Navigator) {
        self.init(article: page.article, reference: page.reference, navigator: navigator)
    }
    
    /// Creates an article renderer by synthesizing a lightweight reference from the article metadata.
    ///
    /// - Parameters:
    ///   - article: Article payload to render.
    ///   - navigator: Host-app navigation coordinator.
    public init(article: Article, navigator: Navigator) {
        self.init(article: article, navigator: navigator, identifier: nil)
    }
    
    /// Creates an article renderer by synthesizing a lightweight reference from the article metadata.
    ///
    /// - Parameters:
    ///   - article: Article payload to render.
    ///   - navigator: Host-app navigation coordinator.
    ///   - identifier: Optional canonical article identifier. If omitted, DocCKit creates a local identifier from the article title.
    ///   - docCSite: Optional custom DocC source used to resolve relative assets.
    public init(article: Article, navigator: Navigator, identifier: String? = nil, docCSite: DocCSource? = nil) {
        self.init(
            article: article,
            reference: Reference(
                title: article.metadata.title,
                identifier: identifier ?? Self.defaultIdentifier(for: article),
                type: "article",
                role: article.metadata.role,
                docCSite: docCSite
            ),
            navigator: navigator
        )
    }
    
    /// The general accent color.
    public var accentColor: Color? {
        article.metadata.color?.standardColorIdentifier.swiftUIColor ?? article.metadata.role.accentColor
    }
    
    /// Gradient colors resolved from article metadata role/color.
    public var topColorGradient: [Color] {
        article.metadata.color?.gradientColors ?? article.metadata.role.gradientColors
    }
    
    public var body: some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading) {
                ArticleHeadingView(article: article, reference: reference, onToolbarVisibilityChange: setToolbarVisibility)
                    .padding(.bottom, 15)
                    .id(ArticleScrollIdentifier.header)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onGeometryChange(for: CGSize.self) { proxy in
                        proxy.size
                    } action: { size in
                        guard headerSize != size else { return }
                        headerSize = size
                    }
                
                ArticleSummaryAsides(article: article)
                ArticlePrimaryContent(article: article)
                ArticleFooterSections(article: article)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 15)
            .padding([.horizontal, .bottom], 30)
            
            if let legalNotices = article.legalNotices {
                DocCLegalNoticesView(legalNotices: legalNotices)
                    .padding([.horizontal, .bottom])
            }
        }
        .scrollTargetLayout()
        .lineSpacing(4)
        .scrollContentBackground(.hidden)
        .toolbarBackgroundVisibility(showToolbarBackground ? .visible : .hidden, for: .navigationBar)
        .onScrollGeometryChange(for: CGFloat.self, of: { proxy in
            elasticGradientOffset(for: proxy.contentOffset.y)
        }, action: { _, newValue in
            guard gradientState.scrollOffset != newValue else { return }
            gradientState.scrollOffset = newValue
        })
        .background {
            ElasticArticleGradientBackground(colors: topColorGradient, baseHeight: gradientBaseHeight, state: gradientState)
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
    
    private func elasticGradientOffset(for rawOffset: CGFloat) -> CGFloat {
        let roundedOffset: CGFloat
        if rawOffset < 0 {
            roundedOffset = rawOffset.rounded(.toNearestOrAwayFromZero)
        } else {
            roundedOffset = (rawOffset / 4).rounded(.toNearestOrAwayFromZero) * 4
        }
        
        guard roundedOffset > 0 else {
            return roundedOffset
        }
        
        return min(roundedOffset, gradientBaseHeight)
    }
    
    private func setToolbarVisibility(_ isVisible: Bool) {
        guard showToolbarBackground != isVisible else { return }
        
        withAnimation(.easeInOut(duration: 0.12)) {
            self.showToolbarBackground = isVisible
        }
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
    let onToolbarVisibilityChange: (Bool) -> Void
    
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
                .onScrollVisibilityChange { isVisible in
                    onToolbarVisibilityChange(!isVisible)
                }
            }
            
            Text(article.metadata.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .textSelection(.enabled)
                .onScrollVisibilityChange { isVisible in
                    if article.metadata.roleHeading == nil && article.metadata.platforms == nil {
                        onToolbarVisibilityChange(!isVisible)
                    }
                }
            
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

private struct ArticleSummaryAsides: View {
    let article: Article
    
    var body: some View {
        if let betaSummary = article.betaSummary {
            AsideView(style: .experiment, content: betaSummary, references: article.references)
        }
        
        if let deprecationSummary = article.deprecationSummary {
            AsideView(style: .deprecated, content: deprecationSummary, references: article.references)
        }
    }
}

private struct ArticlePrimaryContent: View {
    let article: Article
    
    var body: some View {
        LazyVStack(alignment: .leading) {
            ForEach(article.primaryContentSections ?? []) { section in
                ArticleSectionContent(section: section, article: article)
            }
        }
        .id(ArticleScrollIdentifier.primaryContent)
        .textSelection(.enabled)
    }
}

private struct ArticleSectionContent: View {
    let section: ContentSection
    let article: Article
    
    var body: some View {
        switch section.kind {
        case .content:
            VStack(spacing: 15) {
                ForEach(section.condensedContent) { content in
                    ArticleContentView(content: content, references: article.references)
                        .padding(.top, content.type == .heading ? nil : 0)
                }
            }
        case .declarations:
            ForEach(section.declarations ?? []) { declaration in
                DeclarationContentView(content: declaration, article: article)
            }
        case .mentions:
            MentionsView(mentions: section.mentions ?? [], article: article)
        case .details:
            if let details = section.details {
                DetailsView(details: details)
            }
        case .restBody:
            WebEndpointRestBody(contentSection: section, references: article.references)
        case .restEndpoint:
            WebEndpointRestEndPoint(contentSection: section, references: article.references)
        case .restResponses:
            WebEndpointRestResponse(contentSection: section, references: article.references)
        case .properties, .restParameters:
            WebEndpointRestPropertiesView(contentSection: section, references: article.references)
        case .attributes:
            WebEndpointRestAttributesView(contentSection: section, references: article.references)
        default:
            VStack {
                ForEach(section.content ?? []) { content in
                    ArticleContentView(content: content, references: article.references)
                        .padding(.top, content.type == .heading ? nil : 0)
                }
            }
        }
    }
}

private struct ArticleFooterSections: View {
    let article: Article
    
    var body: some View {
        if article.topicSections != nil {
            Divider()
                .padding(.vertical)
            TopicsView(article: article)
                .id(ArticleScrollIdentifier.topics)
        }
        
        if article.relationshipsSections != nil {
            Divider()
                .padding(.vertical)
            RelationshipsView(article: article)
                .id(ArticleScrollIdentifier.relationships)
        }
        
        if article.seeAlsoSections != nil {
            Divider()
                .padding(.vertical)
            SeeAlsoView(article: article)
                .id(ArticleScrollIdentifier.seeAlso)
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

private enum ArticleScrollIdentifier {
    case header
    case primaryContent
    case topics
    case relationships
    case seeAlso
}
