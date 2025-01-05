//
//  ArticleView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/6/24.
//

import SwiftUI

struct ArticleView: View {
    
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var navigationViewModel: NavigationViewModel
    @EnvironmentObject var documentationViewModel: DocumentationViewModel
    let reference: Reference
    
    @State var article: Article?
    @State var showToolbarBG: Bool = false
    
    enum ScrollIdentifier: CaseIterable {
        case header
        case primaryContent
        case topics
        case relationships
        case seeAlso
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                if let article {
                    LazyVStack(alignment: .leading) {
                        Heading(article)
                            .padding(.bottom, 15)
                            .id(ScrollIdentifier.header)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(alignment: .top) {
                                LinearGradient(colors: article.metadata.role.gradientColors, startPoint: .top, endPoint: .bottom)
                                    .padding(.top, -120)
                                    .padding(.bottom, -50)
                                    .padding(.horizontal, -200)
                                    .ignoresSafeArea()
                                    .zIndex(10)
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
                                        ForEach(section.content ?? []) { content in
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
                        
                        if navigationViewModel.isUsingSplitView {
                            ToolbarItemGroup(placement: .topBarLeading) {
                                Group {
                                    Button("Backward", systemImage: "chevron.left") {
                                        navigationViewModel.goBackward()
                                    }
                                    .disabled(!navigationViewModel.previousHistoryExists)
                                    
                                    Button("Forward", systemImage: "chevron.right") {
                                        navigationViewModel.goForward()
                                    }
                                    .disabled(!navigationViewModel.futureHistoryExists)
                                }
                                .tint(color)
                            }
                        }
                        
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            
                            Group {
                                if let url = reference.shareUrl {
                                    ShareLink(item: url) {
                                        Label("Share", systemImage: "square.and.arrow.up")
                                    }
                                }
                                
//                                Button("Download", systemImage: "arrow.down.circle") {
//                                    // TODO: Implement Downloading
//                                }
                                
                                Button("Save", systemImage: "bookmark") {
                                    // TODO: Implement Bookmarks
                                }
                                
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
            .task {
                await loadArticle()
            }
            .onChange(of: navigationViewModel.reference) {
                proxy.scrollTo(ScrollIdentifier.header)
                Task {
                    await loadArticle()
                }
            }
            .id(reference)
            .scrollContentBackground(.hidden)
            .background(Color(platformColor: .systemBackground)
                .ignoresSafeArea()
            )
        }
        .onChange(of: documentationViewModel.preferedProgrammingLanguage, {
            Task {
                self.article = nil
                await loadArticle()
            }
        })
        .onDisappear {
            navigationViewModel.handleHistoryRemoval(for: reference)
        }
    }
    
    @ViewBuilder
    func Heading(_ article: Article) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if article.metadata.roleHeading != nil || article.metadata.platforms != nil {
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
