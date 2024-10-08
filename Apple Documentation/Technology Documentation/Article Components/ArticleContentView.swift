//
//  ArticleContentView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/7/24.
//

import SwiftUI
import Kingfisher
import AVKit
import HighlightSwift

struct ArticleContentView: View {
    let content: ContentSection.Content
    let article: Article
    let type: ContentType?
    @State var orderedListIndex: Int
    
    init(content: ContentSection.Content, article: Article, from type: ContentType? = nil, orderedListIndex: Int = 1) {
        self.content = content
        self.article = article
        self.type = type
        self.orderedListIndex = orderedListIndex
    }
    
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
    
    func getReferenceText(for identifier: String) -> Text? {
        guard let reference = article.references[identifier], let title = reference.title else {
            return nil
        }
        
        let attributes: [NSAttributedString.Key: Any]
        
        if let url = URL(string: reference.identifier) {
            attributes = [
                .foregroundColor: UIColor.blue,
                .underlineStyle : 1,
                .link: url
            ]
        } else {
            attributes = [:]
        }
        
        let attributedString = NSAttributedString(string: title, attributes: attributes)
        
        return Text(AttributedString(attributedString))
    }
    
    func getEmphasisString(_ content: ContentStruct) -> String {
        var string = ""
        
        for inContent in content.inlineContent ?? [] {
            switch inContent.type {
            case .text:
                if let text = inContent.text {
                    string.append(text)
                }
            case .codeVoice:
                if let code = inContent.code {
                    string.append(code)
                }
            case .emphasis:
                let str = getEmphasisString(inContent)
                
                string.append(str)
            default:
                if let text = inContent.text {
                    string.append(text)
                }
            }
        }
        
        return string
    }
    
    @ViewBuilder
    var typeBody: some View {
        switch content.type {
        case .heading:
            if let text = content.text {
                Text(specialStyleString(text))
                    .font(.title3)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .paragraph:
            if let text = content.text {
                Text(specialStyleString(text))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .text:
            if let text = content.text {
                Text(specialStyleString(text))
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
            if let unorderedListItems = content.unorderedListItems {
                ForEach(unorderedListItems) { item in
                    if let content = item.content {
                        ForEach(content) { subcontent in
                            ArticleContentView(content: subcontent, article: self.article, from: .unorderedList)
                        }
                    }
                }
            }
        case .orderedList:
            if let orderedListItems = content.orderedListItems {
                ForEach(orderedListItems) { item in
                    if let content = item.content {
                        ForEach(content) { subcontent in
                            ArticleContentView(content: subcontent, article: self.article, from: .orderedList, orderedListIndex: (orderedListItems.firstIndex(where: { $0 == item }) ?? 0)+1)
                        }
                    }
                }
            }
        case .tabNavigator:
            EmptyView()
        case .reference:
            if let identifier = content.identifier, let referenceText = getReferenceText(for: identifier) {
                referenceText
            }
        case .table:
            EmptyView()
        case .emphasis:
            let string = getEmphasisString(content)
            
            Text(string).italic()
        case .codeListing:
            VStack {
                if let code = content.code {
                    CodeText(code.joined(separator: "\n"))
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 4).fill(Color(uiColor: .secondarySystemBackground)))
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
    
    func specialStyleString(_ string: String) -> String {
        switch type {
        case .unorderedList:
            return "• \(string)"
        case .orderedList:
            return "\(orderedListIndex) \(string)"
        default:
            return string
        }
    }
    
    func inlineContent(for content: [ContentStruct]) -> some View {
        var views: [InlineContent] = []
        
        var text: Text = Text(specialStyleString(""))
        
        func appendText() {
            views.append(.init(text.frame(maxWidth: .infinity, alignment: .leading)))
            text = Text(specialStyleString(""))
        }
        
        for inline in content {
            switch inline.type {
                case .text:
                text = text + Text(inline.text ?? "")
            case .codeVoice:
                text = text + Text(inline.code ?? "").italic()
            case .emphasis:
                let string = getEmphasisString(inline)
                
                text = text + Text(string).italic()
            case .reference:
                if let identifier = inline.identifier, let referenceText = getReferenceText(for: identifier) {
                    text = text + referenceText
                }
            case .image:
                appendText()
                
                if let identifier = inline.identifier {
                    let image = KFImage(fetchPhotoVideoURL(for: identifier))
                        .resizable()
                        .scaledToFit()
                        .padding(.bottom)
                    
                    views.append(.init(image))
                }
            case .video:
                appendText()
                
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
            appendText()
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

