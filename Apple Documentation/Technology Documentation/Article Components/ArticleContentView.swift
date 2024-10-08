//
//  ArticleContentView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/7/24.
//

import SwiftUI
import Kingfisher
import AVKit

struct ArticleContentView: View {
    let content: ContentSection.Content
    let article: Article
    @State var player: AVPlayer?
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack {
            if let inlineContent = content.inlineContent {
                self.inlineContent(for: inlineContent)
            } else {
                typeBody
            }
        }
        .onAppear {
            if content.type == .video, let identifier = content.identifier, let url = fetchPhotoVideoURL(for: identifier) {
                self.player = AVPlayer(url: url)
            }
        }
    }
    
    /// Fetch variant URLs based on identifier. Fundamentally, the url structure is the same, which allows finding both photo and video urls in one go.
    func fetchPhotoVideoURL(for identifier: String) -> URL? {
        guard let reference = article.references[identifier], let variants = reference.variants else {
            return nil
        }
        if let darkVariant = variants.first(where: { $0.traits.contains("dark") }), colorScheme == .dark, let url = URL(string: darkVariant.url) {
            return url
        } else if let lightVariant = variants.first(where: { $0.traits.contains("light") }), let url = URL(string: lightVariant.url) {
            return url
        }
        
        return nil
    }
    
    @ViewBuilder
    var typeBody: some View {
        switch content.type {
        case .heading:
            if let text = content.text {
                Text(text)
                    .font(.title3)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .paragraph:
            if let text = content.text {
                Text(text)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .text:
            if let text = content.text {
                Text(text)
            }
        case .image:
            if let identifier = content.identifier {
                KFImage(fetchPhotoVideoURL(for: identifier))
                    .resizable()
                    .scaledToFit()
                    .padding()
            }
        case .video:
            VideoPlayer(player: player)
                .scaledToFit()
        case .termList:
            if let termListItems = content.termListItems {
                ForEach(termListItems) { termItem in
                    VStack {
                        inlineContent(for: termItem.term.inlineContent)
                            .font(.headline)
                        
                        ForEach(termItem.definition.content) { content in
                            ArticleContentView(content: content, article: self.article)
                        }
                    }
                }
            }
        case .unorderedList:
            EmptyView()
        case .orderedList:
            EmptyView()
        case .tabNavigator:
            EmptyView()
        case .reference:
            EmptyView()
        case .table:
            EmptyView()
        case .emphasis:
            EmptyView()
        case .codeListing:
            EmptyView()
        case .row:
            EmptyView()
        case .aside:
            EmptyView()
        case .code:
            EmptyView()
        case .codeVoice:
            EmptyView()
        case .none:
            EmptyView()
        }
    }
    
    func inlineContent(for content: [ContentStruct]) -> some View {
        var views: [InlineContent] = []
        var text: Text = Text("")
        
        for inline in content {
            switch inline.type {
                case .text:
                text = text + Text(inline.text ?? "")
            case .code:
                text = text + Text(inline.code ?? "")
            case .image:
                views.append(.init(text.frame(maxWidth: .infinity, alignment: .leading)))
                text = Text("")
                
                if let identifier = inline.identifier {
                    let image = KFImage(fetchPhotoVideoURL(for: identifier))
                        .resizable()
                        .scaledToFit()
                        .padding(.bottom)
                    
                    views.append(.init(image))
                }
            case .video:
                views.append(.init(text.frame(maxWidth: .infinity, alignment: .leading)))
                text = Text("")
                
                if let identifier = inline.identifier, let url = fetchPhotoVideoURL(for: identifier) {
                    let player = AVPlayer(url: url)
                    let playerView = VideoPlayer(player: player)
                        .scaledToFit()
                    
                    views.append(.init(playerView))
                }
            default: break
            }
        }
        
        if text != Text("") {
            views.append(.init(text.frame(maxWidth: .infinity, alignment: .leading)))
            text = Text("")
        }
        
        return VStack {
            ForEach(views) { inlineContent in
                inlineContent.view
            }
        }
    }
    
    private struct InlineContent: Identifiable {
        let id = UUID()
        
        let view: AnyView
        
        init(_ view: any View) {
            self.view = AnyView(view)
        }
    }
}

