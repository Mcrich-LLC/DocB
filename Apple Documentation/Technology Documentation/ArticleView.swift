//
//  ArticleView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/6/24.
//

import SwiftUI

struct ArticleView: View {
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
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
                                    .padding(.top, -100)
                                    .padding(.bottom, -50)
                                    .padding(.horizontal, -200)
                                    .zIndex(10)
                            }

                        LazyVStack(alignment: .leading) {
                            // Main Content
                            ForEach(article.primaryContentSections ?? []) { section in
                                switch section.kind {
                                case .content:
                                    VStack(spacing: 15) {
                                        ForEach(section.content ?? []) { content in
                                            ArticleContentView(content: content, article: article)
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
                                default:
                                    VStack {
                                        ForEach(section.content ?? []) { content in
                                            ArticleContentView(content: content, article: article)
                                                .padding(.top, content.type == .heading ? nil : 0)
                                        }
                                    }
                                }
                            }
                        }
                        .id(ScrollIdentifier.primaryContent)
                        
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
                    .frame(maxWidth: 950, alignment: .top)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 15)
                    .padding([.horizontal, .bottom], 30)
                    .toolbar {
                        let role = article.metadata.role
                        let color: Color = role.accentColor
                        
                        if UIDevice.current.userInterfaceIdiom != .phone && horizontalSizeClass == .regular {
                            ToolbarItemGroup(placement: .navigation) {
                                Group{
                                    Button("Backward", systemImage: "chevron.backward") {
                                        navigationViewModel.goBackward()
                                    }
                                    .disabled(!navigationViewModel.previousHistoryExists)
                                    
                                    Button("Forward", systemImage: "chevron.forward") {
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
                                
                                Button("Download", systemImage: "arrow.down.circle") {
                                    // TODO: Implement Downloading
                                }
                                
                                Button("Save", systemImage: "bookmark") {
                                    // TODO: Implement Bookmarks
                                }
                            }
                            .tint(color)
                        }
                    }
                    .toolbarBackgroundVisibility(showToolbarBG ? .visible : .hidden, for: .navigationBar)
                    
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
        }
        .onAppear {
            navigationViewModel.reference = reference
        }
    }
    
    @ViewBuilder
    func Heading(_ article: Article) -> some View {
        VStack(alignment: .leading, spacing: 10) {
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
                if UIDevice.current.userInterfaceIdiom == .phone {
                    setToolbarVisibility(!isVisible)
                }
            }
            
            Text(article.metadata.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .textSelection(.enabled)
                .onScrollVisibilityChange { isVisible in
                    if UIDevice.current.userInterfaceIdiom != .phone && horizontalSizeClass == .regular && article.abstract == nil && article.metadata.platforms == nil {
                        setToolbarVisibility(!isVisible)
                    }
                }
            
            if let abstract = article.abstract {
                AbstractView(abstract: abstract)
                    .textSelection(.enabled)
                    .onScrollVisibilityChange { isVisible in
                        if UIDevice.current.userInterfaceIdiom != .phone && horizontalSizeClass == .regular && article.metadata.platforms == nil {
                            setToolbarVisibility(!isVisible)
                        }
                    }
            }
            
            if let platforms = article.metadata.platforms {
                WrappingHStack(alignment: .leading, horizontalSpacing: 10) {
                    ForEach(platforms) { platform in
                        PlatformCapsule(platform: platform)
                    }
                }
                .onScrollVisibilityChange { isVisible in
                    if UIDevice.current.userInterfaceIdiom != .phone && horizontalSizeClass == .regular {
                        setToolbarVisibility(!isVisible)
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
            if platforms.filter({ $0.beta == true }).count == platforms.count {
                ArticleBadge(badge: .beta)
            }
            if platforms.filter({ $0.deprecated == true || $0.deprecatedAt != nil }).count == platforms.count {
                ArticleBadge(badge: .deprecated)
            }
        }
    }
    
    func loadArticle() async {
        do {
            let article = try await documentationViewModel.fetchArticle(for: reference.identifier)
            
            self.article = article
        } catch {
            print(error)
        }
    }
}
