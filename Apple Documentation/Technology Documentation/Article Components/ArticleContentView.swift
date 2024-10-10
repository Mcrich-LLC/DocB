//
//  ArticleContentView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/7/24.
//
// swiftlint:disable type_body_length

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
    @State private var tabSelection: ContentSection.Content.Tab = .init(content: [], title: "")
    
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
            
            if content.type == .tabNavigator, let tab = content.tabs?.first {
                self.tabSelection = tab
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
        } else if let lightVariant = variants.first, let url = URL(string: lightVariant.url) {
            return url
        }
        
        return nil
    }
    
    func getReferenceText(for identifier: String) -> Text? {
        guard let reference = article.references[identifier], let title = reference.title else {
            return nil
        }
        
        let attributes: [NSAttributedString.Key: Any]
        
        if let url = URL(string: identifier.replacingOccurrences(of: "doc://", with: Constants.deeplinkScheme)) {
            attributes = [
                .foregroundColor: UIColor.accent,
                .underlineStyle : 0,
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
    
    func getCodeString(_ content: ContentStruct) -> AttributedString {
        return getCodeString([content.code ?? ""])
    }
    
    func getCodeString(_ content: [String]) -> AttributedString {
        var strings = ""
        
        for subcontent in content {
            strings.append(subcontent)
        }
        
        let attributes: [NSAttributedString.Key: Any] = [
            .backgroundColor: UIColor.secondarySystemBackground
        ]
        
        let attributedString = NSAttributedString(string: strings, attributes: attributes)
        
        return AttributedString(attributedString)
    }
    
    @ViewBuilder
    var typeBody: some View {
        switch content.type {
        case .heading:
            if let text = content.text, let level = content.level {
                let font: Font = switch level {
                case 3:
                        .title3
                case 2:
                        .title2
                default:
                        .title
                }
                
                Text(specialStyleString(text))
                    .font(font)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
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
        case .strong:
            if let text = content.text {
                Text(specialStyleString(text))
                    .bold()
            }
        case .image:
            if let identifier = content.identifier {
                KFImage(fetchPhotoVideoURL(for: identifier))
                    .resizable()
                    .scaledToFit()
            }
        case .video:
            VideoPlayer(player: player)
                .scaledToFit()
        case .termList:
            if let termListItems = content.termListItems {
                VStack(alignment:.leading, spacing: 10) {
                    ForEach(termListItems) { termItem in
                        VStack {
                            inlineContent(for: termItem.term.inlineContent)
                                .font(.headline)
                            
                            ForEach(termItem.definition.content) { content in
                                ArticleContentView(content: content, article: self.article)
                                    .padding(.leading, 15)
                            }
                        }
                    }
                }
            }
        case .unorderedList:
            if let unorderedListItems = content.unorderedListItems {
                ForEach(unorderedListItems) { item in
                    if let content = item.content {
                        VStack(spacing: 5) {
                            ForEach(content) { subcontent in
                                ArticleContentView(content: subcontent, article: self.article, from: .unorderedList)
                                    .padding(.bottom, content.last == subcontent ? 10 : 0)
                            }
                        }
                        
                    }
                }
            }
        case .orderedList:
            if let orderedListItems = content.orderedListItems {
                ForEach(orderedListItems) { item in
                    if let content = item.content {
                        VStack(spacing: 5) {
                            ForEach(content) { subcontent in
                                ArticleContentView(content: subcontent, article: self.article, from: .orderedList, orderedListIndex: (orderedListItems.firstIndex(where: { $0 == item }) ?? 0) + 1 )
                                    .padding(.bottom, content.last == subcontent ? 10 : 0)
                            }
                        }
                    }
                }
            }
        case .tabNavigator:
            if let tabs = content.tabs {
                if tabs.count <= 4 {
                    MultilinePicker(data: tabs, selection: self.$tabSelection, cell: { tab in
                        Text(tab.title)
                            .tag(tab.title)
                            .fixedSize(horizontal: false, vertical: true)
                    })
                    .padding([.horizontal, .bottom], 15)
                } else {
                    ScrollView(.horizontal) {
                        MultilinePicker(data: tabs, selection: self.$tabSelection, cell: { tab in
                            Text(tab.title)
                                .tag(tab.title)
                                .fixedSize(horizontal: false, vertical: true)
                        })
                        .padding(.bottom, 15)
                        .padding(.horizontal, 25)
                    }
                    .padding(.horizontal, -25)
                }
                
                ForEach(tabSelection.content) { tabContents in
                    if let inlineContent = tabContents.inlineContent {
                        self.inlineContent(for: inlineContent)
                    }
                    
                    if let items = tabContents.items {
                        ForEach(items) { tabItem in
                            ForEach(tabItem.content) { content in
                                ArticleContentView(content: content, article: self.article, from: tabContents.type)
                            }
                        }
                    }
                }
            }
        case .reference:
            if let identifier = content.identifier, let referenceText = getReferenceText(for: identifier) {
                referenceText
            }
        case .table:
            // TODO: Implement Content Table Support
            EmptyView()
        case .emphasis:
            if let inlineContent = content.inlineContent {
                ForEach(inlineContent) { inline in
                    let string = getEmphasisString(inline)
                    
                    Text(string).italic()
                }
            }
        case .codeListing:
            GroupBox {
                if let code = content.code {
                    CodeText(code.joined(separator: "\n"))
                        .highlightLanguage(.swift)
                        .codeTextColors(.theme(.xcode))
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        case .row:
            // TODO: Implement Content Row Support
            EmptyView()
        case .aside:
            // TODO: Implement Content Aside Support
            EmptyView()
        case .code:
            let attributedString = getCodeString(content.code ?? [])
            
            Text(attributedString)
        case .codeVoice:
            let attributedString = getCodeString(content.code ?? [])
            
            Text(attributedString)
        case .links:
            switch content.style {
            case .compactGrid:
                WrappingHStack(alignment: .topLeading) {
                    ForEach(content.linkItems ?? [], id: \.self) { identifier in
                        if let reference = article.references[identifier],
                            let title = reference.title,
                            let imageId = reference.images?.first?.identifier,
                           let openUrl = URL(string: reference.identifier.replacingOccurrences(of: "doc://", with: Constants.deeplinkScheme)) {
                            
                            let imageUrl = fetchPhotoVideoURL(for: imageId)
                            
                            Link(destination: openUrl) {
                                VStack(alignment: .leading) {
                                    KFImage(imageUrl)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                    
                                    Text(title)
                                        .foregroundStyle(Color.primary)
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(maxWidth: 300)
                            }
                        }
                    }
                }
            default:
                EmptyView()
            }
        case .none:
            EmptyView()
        }
    }
    
    func specialStyleString(_ string: String) -> String {
        switch type {
        case .unorderedList:
            return " • \(string)"
        case .orderedList:
            return " \(orderedListIndex). \(string)"
        default:
            return string
        }
    }
    
    // swiftlint:disable cyclomatic_complexity
    func inlineContent(for content: [ContentStruct]) -> some View {
        var views: [InlineContent] = []
        
        var text: Text = Text(specialStyleString(""))
        
        func appendText() {
            views.append(.init(text.frame(maxWidth: .infinity, alignment: .leading)))
            text = Text(specialStyleString(""))
        }
        
        // swiftlint:disable shorthand_operator
        for inline in content {
            switch inline.type {
            case .text:
                text = text + Text(inline.text ?? "")
            case .codeVoice:
                let attributedString = self.getCodeString(inline)
                
                text = text + Text(attributedString)
            case .emphasis:
                let string = getEmphasisString(inline)
                
                text = text + Text(string).italic()
            case .strong:
                let string = getEmphasisString(inline)
                
                text = text + Text(string).bold()
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
        // swiftlint:enable shorthand_operator
        
        if text != Text("") {
            appendText()
        }
        
        return VStack {
            ForEach(views) { inlineContent in
                inlineContent.view
            }
        }
        .padding(.bottom, [ContentType.unorderedList, .orderedList].contains(type) ? 5 : 0)
    }
    // swiftlint:enable cyclomatic_complexity
    
    private struct InlineContent: Identifiable {
        let id = UUID()
        
        let view: AnyView
        
        init(_ view: any View) {
            self.view = AnyView(view)
        }
    }
}

// swiftlint:enable type_body_length
