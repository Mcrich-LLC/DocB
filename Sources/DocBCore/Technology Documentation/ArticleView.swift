//
//  ArticleView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/6/24.
//

import SwiftUI
import SwiftData

/// ArticleView renders a reusable SwiftUI view.
struct ArticleView: View {
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(NavigationViewModel.self) var navigationViewModel
    @Environment(DocumentationViewModel.self) var documentationViewModel
    /// Reference currently being displayed.
    let reference: Reference
    
    /// Whether the current reference is already bookmarked.
    @State var isBookmarked = false
    /// Loaded article payload.
    @State var article: Article?
    /// Isolated state for the elastic top gradient so scroll updates do not invalidate article content.
    @State private var gradientState = ArticleGradientState()
    /// Cached header size used to size the top gradient.
    @State private var headerSize: CGSize?
    
    /// Stable scroll anchors used by `ScrollViewReader`/layout IDs.
    enum ScrollIdentifier: CaseIterable {
        case header
        case primaryContent
        case topics
        case relationships
        case seeAlso
    }
    
    /// The general accent color
    var accentColor: Color? {
        article?.metadata.color?.standardColorIdentifier.swiftUIColor ?? article?.metadata.role.accentColor
    }
    
    /// Gradient colors resolved from article metadata role/color.
    var topColorGradient: [Color] {
        article?.metadata.color?.gradientColors ?? article?.metadata.role.gradientColors ?? []
    }
    
    var body: some View {
        ScrollView(.vertical) {
            if let article {
                ArticleScrollContent(
                    article: article,
                    reference: reference,
                    accentColor: accentColor,
                    horizontalSizeClass: horizontalSizeClass,
                    headerSize: $headerSize,
                    isBookmarked: $isBookmarked
                )
            } else {
                ProgressView("Loading")
            }
        }
        .scrollTargetLayout()
        .lineSpacing(4)
        .task(id: navigationViewModel.reference) {
            await loadArticle()
        }
        .id(reference)
        .scrollContentBackground(.hidden)
        .onScrollGeometryChange(for: CGFloat.self, of: { proxy in
            elasticGradientOffset(for: proxy.contentOffset.y)
        }, action: { _, newValue in
            guard gradientState.scrollOffset != newValue else { return }
            
            gradientState.scrollOffset = newValue
        })
        .background {
            ElasticArticleGradientBackground(
                colors: topColorGradient,
                baseHeight: gradientBaseHeight,
                state: gradientState
            )
        }
        .environment(\.docCSite, reference.docCSite ?? navigationViewModel.technology?.docCSite)
        .onChange(of: documentationViewModel.preferedProgrammingLanguage, {
            Task {
                self.article = nil
                await loadArticle()
            }
        })
        .onChange(of: reference, initial: true) {
            getIfBookmarked()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave), perform: { _ in
            Task {
                try? await Task.sleep(nanoseconds: 25)
                getIfBookmarked()
            }
        })
        .onDisappear {
            navigationViewModel.handleHistoryRemoval(for: reference)
        }
        .tintColor(accentColor)
        .accentColor(accentColor)
    }
    
    /// Baseline gradient height before pull-down stretch.
    private var gradientBaseHeight: CGFloat {
        (headerSize?.height ?? 0) + 50
    }
    
    /// Returns the scroll offset needed for the elastic gradient while limiting unnecessary churn.
    ///
    /// - Parameter rawOffset: Current vertical content offset.
    /// - Returns: A quantized offset capped once normal upward scrolling has moved the gradient out of view.
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
    
    /// Refreshes bookmark state for the currently displayed reference.
    func getIfBookmarked() {
        do {
            let descriptor = FetchDescriptor<Bookmark>(
                predicate: #Predicate { bookmark in
                    bookmark.identifier == (reference.identifier as String?)
                }
            )
            
            let bookmarks = try modelContext.fetch(descriptor)
            isBookmarked = !bookmarks.isEmpty
        } catch {
            print(error)
            isBookmarked = false
        }
    }
    
    /// Fetches and assigns full article content for the current reference.
    func loadArticle() async {
        do {
            let article = try await documentationViewModel.fetchArticle(for: reference.identifier, site: reference.docCSite)
            
            self.article = article
        } catch {
            print(error)
        }
    }
}

/// Renders the complete scrollable article content while keeping `ArticleView` focused on state orchestration.
private struct ArticleScrollContent: View {
    /// Loaded article payload.
    let article: Article
    /// Reference currently being displayed.
    let reference: Reference
    /// Accent color resolved by the parent article view.
    let accentColor: Color?
    /// Horizontal size class used to size bookmark popovers.
    let horizontalSizeClass: UserInterfaceSizeClass?
    /// Header size reported back to the parent for gradient sizing.
    @Binding var headerSize: CGSize?
    /// Whether the current reference is already bookmarked.
    @Binding var isBookmarked: Bool
    
    /// Whether to show a toolbar background while scrolling.
    @State private var showToolbarBackground = false
    /// Controls Add Bookmark popover presentation.
    @State private var isShowingAddBookmark = false
    
    var body: some View {
        LazyVStack(alignment: .leading) {
            ArticleHeadingView(
                article: article,
                reference: reference,
                onToolbarVisibilityChange: setToolbarVisibility
            )
            .padding(.bottom, 15)
            .id(ArticleView.ScrollIdentifier.header)
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
        .toolbar {
            ArticleToolbar(
                article: article,
                reference: reference,
                accentColor: accentColor,
                horizontalSizeClass: horizontalSizeClass,
                isBookmarked: $isBookmarked,
                isShowingAddBookmark: $isShowingAddBookmark
            )
        }
        .toolbarBackgroundVisibility(showToolbarBackground ? .visible : .hidden, for: .navigationBar)
        
        if let legalNotices = article.legalNotices {
            LegalNoticesView(legalNotices: legalNotices)
                .padding([.horizontal, .bottom])
        }
    }
    
    /// Animates toolbar background visibility changes based on heading visibility.
    private func setToolbarVisibility(_ isVisible: Bool) {
        guard showToolbarBackground != isVisible else { return }
        
        withAnimation(.easeInOut(duration: 0.12)) {
            self.showToolbarBackground = isVisible
        }
    }
}

/// Renders the toolbar controls for article actions and variants.
private struct ArticleToolbar: ToolbarContent {
    /// Loaded article payload.
    let article: Article
    /// Reference currently being displayed.
    let reference: Reference
    /// Accent color resolved by the parent article view.
    let accentColor: Color?
    /// Horizontal size class used to size bookmark popovers.
    let horizontalSizeClass: UserInterfaceSizeClass?
    /// Whether the current reference is already bookmarked.
    @Binding var isBookmarked: Bool
    /// Controls Add Bookmark popover presentation.
    @Binding var isShowingAddBookmark: Bool
    
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Group {
                if let url = reference.externalURL {
                    ShareLink(item: url) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
                
                //                                Button("Download", systemImage: "arrow.down.circle") {
                //                                    // TODO: Implement Downloading
                //                                }
                
                Button("Save", systemImage: isBookmarked ? "bookmark.fill" : "bookmark") {
                    isShowingAddBookmark.toggle()
                }
                .animation(.default, value: isBookmarked)
                .popover(isPresented: $isShowingAddBookmark, content: {
                    NavigationStack {
                        AddBookmarkView(reference: reference)
                            .frame(minWidth: horizontalSizeClass == .regular ? 400 : nil, minHeight: horizontalSizeClass == .regular ? 400 : nil)
                    }
                })
                
                if let variants = article.variants {
                    LanguagePicker(variants: variants)
                }
            }
            .tintColor(accentColor)
        }
    }
}

/// Renders the article heading block including badges, abstract, and platforms.
private struct ArticleHeadingView: View {
    /// Loaded article payload.
    let article: Article
    /// Reference currently being displayed.
    let reference: Reference
    /// Called when heading visibility should change toolbar background state.
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

/// Renders beta/deprecation badges for article metadata.
private struct ArticleHeadingBadge: View {
    /// Loaded article payload.
    let article: Article
    /// Reference currently being displayed.
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

/// Renders beta and deprecation summary asides above primary article content.
private struct ArticleSummaryAsides: View {
    /// Loaded article payload.
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

/// Renders primary article content sections.
private struct ArticlePrimaryContent: View {
    /// Loaded article payload.
    let article: Article
    
    var body: some View {
        LazyVStack(alignment: .leading) {
            ForEach(article.primaryContentSections ?? []) { section in
                ArticleSectionContent(section: section, article: article)
            }
        }
        .id(ArticleView.ScrollIdentifier.primaryContent)
        .textSelection(.enabled)
    }
}

/// Renders one primary content section according to its DocC kind.
private struct ArticleSectionContent: View {
    /// Content section being rendered.
    let section: ContentSection
    /// Loaded article payload.
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

/// Renders non-primary article sections below the main body.
private struct ArticleFooterSections: View {
    /// Loaded article payload.
    let article: Article
    
    var body: some View {
        if article.topicSections != nil {
            Divider()
                .padding(.vertical)
            TopicsView(article: article)
                .id(ArticleView.ScrollIdentifier.topics)
        }
        
        if article.relationshipsSections != nil {
            Divider()
                .padding(.vertical)
            RelationshipsView(article: article)
                .id(ArticleView.ScrollIdentifier.relationships)
        }
        
        if article.seeAlsoSections != nil {
            Divider()
                .padding(.vertical)
            SeeAlsoView(article: article)
                .id(ArticleView.ScrollIdentifier.seeAlso)
        }
    }
}

/// Stores scroll-driven gradient state separately from the full article view tree.
@Observable
@MainActor
private final class ArticleGradientState {
    /// Quantized scroll offset used by the elastic gradient.
    var scrollOffset: CGFloat = 0
}

/// Renders the elastic article background gradient.
private struct ElasticArticleGradientBackground: View {
    /// Gradient colors resolved from article metadata.
    let colors: [Color]
    /// Baseline gradient height before pull-down stretch.
    let baseHeight: CGFloat
    /// Isolated state updated by scroll geometry changes.
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
        .backgroundExtensionEffectIfAvailable()
    }
}
