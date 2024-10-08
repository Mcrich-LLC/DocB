//
//  ArticleView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/6/24.
//

import SwiftUI

struct ArticleView: View {
    
    @EnvironmentObject var navigationViewModel: NavigationViewModel
    @EnvironmentObject var documentationViewModel: DocumentationViewModel
    let reference: Reference
    
    @State var article: Article?
    @State var showToolbarBG: Bool = false
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                if let article {
                    LazyVStack(alignment: .leading) {
                        Heading(article)
                            .padding(.bottom, 15)
                            .id("HEADER")

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
                        
                        if article.topicSections != nil {
                            Divider()
                                .padding(.vertical)
                            TopicsView(article: article)
                        }
                        
                        if article.relationshipsSections != nil {
                            Divider()
                                .padding(.vertical)
                            RelationshipsView(article: article)
                        }
                        
                        if article.seeAlsoSections != nil {
                            Divider()
                                .padding(.vertical)
                            SeeAlsoView(article: article)
                        }
                    }
                    .frame(maxWidth: 950, alignment: .top)
                    .frame(maxWidth: .infinity)
                    .padding([.horizontal, .bottom], 25)
                    .background(alignment: .top) {
                        if let role = reference.role {
                            let color: Color = switch role {
                            case .sampleCode:
                                Color.sampleCode
                            default:
                                Color.article
                            }
                            
                            LinearGradient(colors: [color.opacity(0.4), color.opacity(0.0)], startPoint: .top, endPoint: .bottom)
                                .frame(height: 300)
                                .padding(.top, -100)
                        }
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            let url = documentationViewModel.jsonUrl(for: reference.identifier)!.absoluteString.replacingOccurrences(of: "doc://com.apple.documentation", with: "https://developer.apple.com").replacingOccurrences(of: ".json", with: "")
                            
                            ShareLink(item: URL(string: url)!) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            
                            Button("Download", systemImage: "arrow.down.circle.fill") {
                                
                            }
                            
                            Button("Save", systemImage: "bookmark") {
                                
                            }
                        }
                    }
                    .toolbarBackgroundVisibility(showToolbarBG ? .visible : .hidden, for: .navigationBar)
                    
                } else {
                    ProgressView("Loading")
                }
            }
            .lineSpacing(4)
            .task {
                await loadArticle()
            }
            .onChange(of: navigationViewModel.reference) {
                proxy.scrollTo("HEADER")
                Task {
                    await loadArticle()
                }
            }
            .id(reference)
        }
    }
    
    @ViewBuilder
    func Heading(_ article: Article) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 15) {
                if let roleHeading = article.metadata.roleHeading {
                    Text(roleHeading)
                        .foregroundStyle(.secondary)
                }
                HeadingBadge(article.metadata)
            }
            .font(.headline)
            .padding(.bottom, 5)
            
            Text(article.metadata.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .onAppear {
                    showToolbarBG = false
                }
                .onDisappear {
                    showToolbarBG = true
                }
            
            if let abstract = article.abstract {
                AbstractView(abstract: abstract)
            }
            
            WrappingHStack(alignment: .leading, horizontalSpacing: 10) {
                ForEach(article.metadata.platforms ?? []) { platform in
                    PlatformCapsule(platform: platform)
                }
            }
        }
        .multilineTextAlignment(.leading)
        .lineSpacing(3)
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

//#Preview {
//    ArticleView()
//}
