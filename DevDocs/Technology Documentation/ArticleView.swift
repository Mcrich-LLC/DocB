//
//  ArticleView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/6/24.
//

import SwiftUI
import SwiftData

struct ArticleView: View {
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(NavigationViewModel.self) var navigationViewModel
    @Environment(DocumentationViewModel.self) var documentationViewModel
    let reference: Reference
    
    @State var isBookmarked = false
    @State var article: Article?
    @State var showToolbarBG: Bool = false
    @State var scrollOffset: CGFloat = 0
    @State var isShowingAddBookmark = false
    @State var headerSize: CGSize?
    
    enum ScrollIdentifier: CaseIterable {
        case header
        case primaryContent
        case topics
        case relationships
        case seeAlso
    }
    
    var topColorGradient: [Color] {
        article?.metadata.color?.gradientColors ?? article?.metadata.role.gradientColors ?? []
    }
    
    var body: some View {
        ScrollView(.vertical) {
            if let article {
                LazyVStack(alignment: .leading) {
                    Heading(article)
                        .padding(.bottom, 15)
                        .id(ScrollIdentifier.header)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onGeometryChange(for: CGSize.self) { proxy in
                            proxy.size
                        } action: { size in
                            headerSize = size
                        }

                    if let betaSummary = article.betaSummary {
                        AsideView(style: .experiment, content: betaSummary, references: article.references)
                    }
                    
                    if let deprecationSummary = article.deprecationSummary {
                        AsideView(style: .deprecated, content: deprecationSummary, references: article.references)
                    }
                    
                    LazyVStack(alignment: .leading) {
                        // Main Content
                        ForEach(article.primaryContentSections ?? []) { section in
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
                    .id(ScrollIdentifier.primaryContent)
                    .textSelection(.enabled)
                    
                    if article.topicSections != nil {
                        Divider()
                            .padding(.vertical)
                        TopicsView(article: article)
                            .id(ScrollIdentifier.topics)
                    }
                    
                    if article.relationshipsSections != nil {
                        Divider()
                            .padding(.vertical)
                        RelationshipsView(article: article)
                            .id(ScrollIdentifier.relationships)
                    }
                    
                    if article.seeAlsoSections != nil {
                        Divider()
                            .padding(.vertical)
                        SeeAlsoView(article: article)
                            .id(ScrollIdentifier.seeAlso)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 15)
                .padding([.horizontal, .bottom], 30)
                .toolbar {
                    let role = article.metadata.role
                    let color: Color = role.accentColor
                    
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
                        .tint(color)
                    }
                }
                .toolbarBackgroundVisibility(showToolbarBG ? .visible : .hidden, for: .navigationBar)
                
                if let legalNotices = article.legalNotices {
                    LegalNoticesView(legalNotices: legalNotices)
                        .padding([.horizontal, .bottom])
                }
            } else {
                ProgressView("Loading")
            }
        }
        .scrollTargetLayout()
        .lineSpacing(4)
        .task(id: navigationViewModel.reference) {
            await loadArticle()
        }
        .onScrollGeometryChange(for: CGFloat.self, of: { proxy in
            proxy.contentOffset.y
        }, action: { _, newValue in
            self.scrollOffset = newValue
        })
        .id(reference)
        .scrollContentBackground(.hidden)
//        .background(Color(platformColor: .systemBackground)
//            .ignoresSafeArea()
//        )
        .background {
            ZStack(alignment: .top) {
                Color(platformColor: .systemBackground)
                LinearGradient(colors: topColorGradient, startPoint: .top, endPoint: .bottom)
                    .frame(height: (headerSize?.height ?? 0)+50 - min(0, scrollOffset))
            }
            .ignoresSafeArea()
            .backgroundExtensionEffectIfAvailable()
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
        .accentColor(Color.accentColor)
    }
    
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
    
    @ViewBuilder
    func Heading(_ article: Article) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if (article.metadata.roleHeading != nil || article.metadata.platforms != nil) && article.topicSectionsStyle != .hidden {
                HStack(spacing: 15) {
                    if let roleHeading = article.metadata.roleHeading {
                        Text(roleHeading)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    
                    HeadingBadge(article.metadata)
                }
                .font(.headline)
                .padding(.bottom, 5)
                .onScrollVisibilityChange { isVisible in
                    setToolbarVisibility(!isVisible)
                }
            }
            
            Text(article.metadata.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .textSelection(.enabled)
                .onScrollVisibilityChange { isVisible in
                    if article.metadata.roleHeading == nil && article.metadata.platforms == nil {
                        setToolbarVisibility(!isVisible) // Runs if nothing is above this view
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
    
    func setToolbarVisibility(_ isVisible: Bool) {
        withAnimation {
            self.showToolbarBG = isVisible
        }
    }
    
    @ViewBuilder
    func HeadingBadge(_ metadata: Article.Metadata) -> some View {
        if let platforms = metadata.platforms {
            if platforms.filter({ $0.beta == true }).count == platforms.count || reference.beta == true || article?.betaSummary != nil {
                ArticleBadge(badge: .beta)
            }
            if platforms.filter({ $0.deprecated == true || $0.deprecatedAt != nil }).count == platforms.count || article?.deprecationSummary != nil || reference.deprecated == true {
                ArticleBadge(badge: .deprecated)
            }
        }
    }
    
    func loadArticle() async {
        do {
            let article = try await documentationViewModel.fetchArticle(for: reference.identifier, site: reference.docCSite)
            
            self.article = article
        } catch {
            print(error)
        }
    }
}
