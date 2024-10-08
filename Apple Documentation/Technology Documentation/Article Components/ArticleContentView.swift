//
//  ArticleContentView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/7/24.
//

import SwiftUI
import Kingfisher

struct ArticleContentView: View {
    let content: ContentSection.Content
    let article: Article
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        switch content.type {
        case .heading:
            if let text = content.text {
                Text(text)
                    .font(.title3)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .paragraph:
            if let inlineContent = content.inlineContent {
                self.inlineContent(for: inlineContent)
            }
        case .text:
            if let text = content.text {
                Text(text)
            }
        case .image:
            if let identifier = content.identifier, let reference = article.references[identifier], let variants = reference.variants {
                if let darkVariant = variants.first(where: { $0.traits.contains("dark") }), colorScheme == .dark {
                    KFImage(URL(string: darkVariant.url))
                        .resizable()
                        .scaledToFit()
                        .padding()
                } else if let lightVariant = variants.first(where: { $0.traits.contains("light") }) {
                    KFImage(URL(string: lightVariant.url))
                        .resizable()
                        .scaledToFit()
                        .padding()
                }
            }
        case .video:
            EmptyView()
        case .termList:
            EmptyView()
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
                
                if let identifier = inline.identifier, let reference = article.references[identifier], let variants = reference.variants {
                    if let darkVariant = variants.first(where: { $0.traits.contains("dark") }), colorScheme == .dark {
                        let image = KFImage(URL(string: darkVariant.url))
                            .resizable()
                            .scaledToFit()
                            .padding(.bottom)
                        
                        views.append(.init(image))
                    } else if let lightVariant = variants.first(where: { $0.traits.contains("light") }) {
                        let image = KFImage(URL(string: lightVariant.url))
                            .resizable()
                            .scaledToFit()
                            .padding(.bottom)
                        
                        views.append(.init(image))
                    }
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

