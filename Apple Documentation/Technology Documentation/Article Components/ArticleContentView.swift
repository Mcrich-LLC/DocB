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
    let references: [String : Reference]
    let type: ContentType?
    let alignment: Alignment
    @Environment(\.docCSite) var docCSite
    @State var orderedListIndex: Int
    @EnvironmentObject var navigationViewModel: NavigationViewModel
    
    init(content: ContentSection.Content, references: [String : Reference], from type: ContentType? = nil, orderedListIndex: Int = 1, alignment: Alignment = .leading) {
        self.content = content
        self.references = references
        self.type = type
        self.orderedListIndex = orderedListIndex
        self.alignment = alignment
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
        
        guard let url = Constants.fetchPhotoVideoURL(for: identifier, references: references, colorScheme: colorScheme),
              url.host() == nil
        else {
            return nil
        }
        
        let fullUrl = docCSite?.url.appending(path: url.path())
        
        return fullUrl
    }
    
    func getReferenceText(for identifier: String) -> Text? {
        guard let reference = references[identifier], let title = reference.title else {
            return nil
        }
        
        let attributes: [NSAttributedString.Key: Any]
        
        if let url = URL(string: identifier.replacingOccurrences(of: "doc://", with: Constants.deeplinkScheme)) {
            let role = reference.role ?? .article
            
            if role == .symbol {
                attributes = [
                    .foregroundColor: PlatformColor.accent,
                    .font: PlatformFont.monospacedSystemFont(ofSize: PlatformFont.labelFontSize, weight: .medium),
                    .underlineStyle : 0,
                    .link: url
                ]
            } else {
                attributes = [
                    .foregroundColor: PlatformColor.accent,
                    .underlineStyle : 0,
                    .link: url
                ]
            }
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
        
        #if os(macOS)
        let attributes: [NSAttributedString.Key: Any] = [
            .backgroundColor: PlatformColor.controlBackgroundColor
        ]
        #else
        let attributes: [NSAttributedString.Key: Any] = [
            .backgroundColor: PlatformColor.secondarySystemBackground
        ]
        #endif
        
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
                    .bold().textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: self.alignment)
                    .padding(.top, 10)
            }
        case .paragraph:
            if let text = content.text {
                Text(specialStyleString(text)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: self.alignment)
            }
        case .text:
            if let text = content.text {
                Text(specialStyleString(text)).textSelection(.enabled)
            }
        case .strong:
            if let text = content.text {
                Text(specialStyleString(text)).textSelection(.enabled)
                    .bold()
            }
        case .image:
            if let identifier = content.identifier {
                KFImage(fetchPhotoVideoURL(for: identifier))
                    .placeholder({
                        Image(systemSymbol: .photo)
                            .resizable()
                            .scaledToFit()
                    })
                    .resizable()
                    .scaledToFit()
            }
        case .video:
            VideoPlayer(player: player)
                .scaledToFit()
        case .termList:
            if let termListItems = content.termListItems {
                VStack(alignment: alignment.horizontal, spacing: 10) {
                    ForEach(termListItems) { termItem in
                        VStack {
                            inlineContent(for: termItem.term.inlineContent)
                                .fontWeight(.semibold)
                            
                            ForEach(termItem.definition.content) { content in
                                ArticleContentView(content: content, references: self.references)
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
                                ArticleContentView(content: subcontent, references: self.references, from: .unorderedList)
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
                                ArticleContentView(
                                    content: subcontent,
                                    references: self.references,
                                    from: .orderedList,
                                    orderedListIndex: (orderedListItems.firstIndex(where: { $0 == item }) ?? 0) + 1
                                )
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
                    ArticleContentView(content: tabContents, references: references)
                }
            }
        case .reference:
            if let identifier = content.identifier, let referenceText = getReferenceText(for: identifier) {
                referenceText
            }
        case .table:
            if let rows = content.rows {
                tableView(rows: rows)
            }
        case .emphasis:
            if let inlineContent = content.inlineContent {
                ForEach(inlineContent) { inline in
                    let string = getEmphasisString(inline)
                    
                    Text(string).italic()
                        .textSelection(.enabled)
                }
            }
        case .codeListing:
            GroupBox {
                if let code = content.code {
                    CodeText(code.joined(separator: "\n"))
                        .highlightLanguage(.swift)
                        .codeTextColors(.theme(.xcode))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: self.alignment)
                        .font(.subheadline)
                        .foregroundStyle(Color.primary)
                        .overlay(alignment: .topTrailing) {
                            CodeCopyOverlayButton(string: code.joined(separator: "\n"))
                        }
                }
            }
#if os(visionOS)
            .backgroundStyle(colorScheme == .dark ? .black : .white)
#endif
        case .aside:
            if let style = content.style {
                AsideView(style: style, content: content.content ?? [], references: references)
            }
        case .code:
            let attributedString = getCodeString(content.code ?? [])
            
            Text(attributedString)
                .textSelection(.enabled)
        case .codeVoice:
            let attributedString = getCodeString(content.code ?? [])
            
            Text(attributedString)
                .textSelection(.enabled)
        case .links:
            if let linkItems = content.linkItems, let Style = content.style {
                LinksGridListView(identifiers: linkItems, style: Style, references: references, navigationViewModel: navigationViewModel)
            }
        default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    func tableRow(content: [[ContentSection.Content]]) -> some View {
        HStack {
            ForEach(content, id: \.self) { contentSlice in
                if contentSlice != content.first {
                    Spacer()
                    Divider()
                    Spacer()
                }
                
                VStack {
                    ForEach(contentSlice) { item in
                        ArticleContentView(content: item, references: self.references)
                    }
                }
                .padding(.vertical)
            }
        }
    }
    
    @ViewBuilder
    func tableView(rows: [[[ContentSection.Content]]]) -> some View {
        VStack(spacing: 0) {
            if let firstRow = rows.first {
                tableRow(content: firstRow)
                    .bold()
            }
            
            ForEach(rows.dropFirst(), id: \.self) { row in
                Divider()
                tableRow(content: row)
            }
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
    
    // swiftlint:disable cyclomatic_complexity function_body_length
    func inlineContent(for content: [ContentStruct]) -> some View {
        var views: [InlineContent] = []
        
        var text: Text = Text(specialStyleString(""))
        
        func appendText() {
            views.append(.init(text.textSelection(.enabled).frame(maxWidth: .infinity, alignment: self.alignment)))
            text = Text(specialStyleString(""))
        }
        
        // swiftlint:disable shorthand_operator
        for inline in content {
            switch inline.type {
            case .text:
                if !(inline.text == " " && content.filter({ !($0.text ?? "").isEmpty }).first == inline) {
                    text = text + Text(inline.text ?? "")
                }
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
                        .placeholder({
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color.clear)
                                .stroke(Color.primary, lineWidth: 2)
                                .scaledToFit()
                                .overlay {
                                    ProgressView()
                                }
                        })
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
    // swiftlint:enable cyclomatic_complexity function_body_length
    
    private struct InlineContent: Identifiable {
        let id = UUID()
        
        let view: AnyView
        
        init(_ view: any View) {
            self.view = AnyView(view)
        }
    }
}

// swiftlint:enable type_body_length
