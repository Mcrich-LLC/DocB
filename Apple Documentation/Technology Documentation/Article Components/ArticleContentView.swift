//
//  ArticleContentView.swift
//  Apple Documentation
//
//  Created by Morris Richman on 10/7/24.
//
// swiftlint:disable type_body_length

import SwiftUI
import NukeUI
import AVKit
import HighlightSwift

@Observable
private class ArticleContentManager {
    var content: ContentSection.Content
    var references: [String : Reference]
    var type: ContentType?
    var alignment: Alignment
    var orderedListIndex: Int
    var enlargedImageSheetIdentifier: EnlargedImageSheetIdentifier?
    
    init(content: ContentSection.Content, references: [String : Reference], type: ContentType? = nil, alignment: Alignment, orderedListIndex: Int) {
        self.content = content
        self.references = references
        self.type = type
        self.alignment = alignment
        self.orderedListIndex = orderedListIndex
    }
    
    func specialStyleString(_ string: String, type: ContentType? = nil, orderedListIndex: Int? = nil) -> AttributedString {
        let type = type ?? self.type
        let orderedListIndex = orderedListIndex ?? self.orderedListIndex
        
        switch type {
        case .unorderedList:
            var bulletString = AttributedString(" • ")
            bulletString.foregroundColor = Color.primary
            
            return bulletString + AttributedString(string)
        case .orderedList:
            var numberString = AttributedString(" \(orderedListIndex). ")
            numberString.foregroundColor = Color.primary
            
            return numberString + AttributedString(string)
        default:
            return AttributedString(string)
        }
    }
    
    /// Fetch variant URLs based on identifier. Fundamentally, the url structure is the same, which allows finding both photo and video urls in one go.
    func fetchPhotoVideoURL(for identifier: String, colorScheme: ColorScheme, docCSite: DocCSiteDTO?) -> URL? {
        guard let url = Constants.fetchPhotoVideoURL(for: identifier, references: references, colorScheme: colorScheme, docCSite: docCSite) else {
            return nil
        }
        
        guard url.host() == nil else {
            return url
        }
        
        let fullUrl = docCSite?.url.appending(path: url.path())
        
        return fullUrl
    }
    
    func getReferenceText(for identifier: String) -> AttributedString? {
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
        
        return AttributedString(attributedString)
    }
    
    func getEmphasisString(_ content: ContentStruct) -> String {
        var string = ""
        
        for inContent in [content] + (content.inlineContent ?? []) {
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
}

struct ArticleContentView: View {
    @State private var manager: ArticleContentManager
    @Environment(\.docCSite) var docCSite
    @Environment(NavigationViewModel.self) var navigationViewModel
    
    init(content: ContentSection.Content, references: [String : Reference], from type: ContentType? = nil, orderedListIndex: Int = 1, alignment: Alignment = .leading) {
        self.manager = .init(content: content, references: references, type: type, alignment: alignment, orderedListIndex: orderedListIndex)
    }
    
    @State var player: AVPlayer?
    @State private var tabSelection: ContentSection.Content.Tab = .init(content: [], title: "")
    @State private var viewSize: CGSize?
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        let content = manager.content
        
        VStack {
            if let inlineContent = content.inlineContent {
                InlineContentView(for: inlineContent)
            } else {
                typeBody
            }
        }
        .sheet(item: $manager.enlargedImageSheetIdentifier, content: { identifier in
            EnlargedImageView(identifier: identifier)
        })
        .onAppear {
            if content.type == .video, let identifier = content.identifier, let url = fetchPhotoVideoURL(for: identifier) {
                self.player = AVPlayer(url: url)
            }
            
            if content.type == .tabNavigator, let tab = content.tabs?.first {
                self.tabSelection = tab
            }
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newValue in
            viewSize = newValue
        }
        .environment(manager)
    }
    
    @ViewBuilder
    var typeBody: some View {
        let content = manager.content
        
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
                
                Text(manager.specialStyleString(text))
                    .font(font)
                    .bold().textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: self.manager.alignment)
                    .padding(.top, 10)
            }
        case .paragraph:
            if let text = content.text {
                Text(manager.specialStyleString(text)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: self.manager.alignment)
            }
        case .text:
            if let text = content.text {
                Text(manager.specialStyleString(text)).textSelection(.enabled)
            }
        case .strong:
            if let text = content.text {
                Text(manager.specialStyleString(text)).textSelection(.enabled)
                    .bold()
            }
        case .small:
            if let text = content.text {
                Text(manager.specialStyleString(text)).textSelection(.enabled)
                    .font(.caption)
            }
        case .image:
            if let identifier = content.identifier {
                LazyImage(url: fetchPhotoVideoURL(for: identifier)) { state in
                    if state.isLoading {
                        Image(systemSymbol: .photo)
                            .resizable()
                            .scaledToFit()
                    } else if let image = state.image {
                        image
                        .resizable()
                        .scaledToFit()
                    }
                }
                    .frame(maxWidth: 700, maxHeight: 700)
                    .onTapGesture {
                        if let url = fetchPhotoVideoURL(for: identifier) {
                            self.manager.enlargedImageSheetIdentifier = .init(identifier: identifier, url: url)
                        }
                    }
            }
        case .video:
            VideoPlayer(player: player)
                .scaledToFit()
        case .termList:
            if let termListItems = content.termListItems {
                VStack(alignment: manager.alignment.horizontal, spacing: 10) {
                    ForEach(termListItems) { termItem in
                        VStack {
                            InlineContentView(for: termItem.term.inlineContent)
                                .fontWeight(.semibold)
                            
                            ForEach(termItem.definition.content) { content in
                                ArticleContentView(content: content, references: self.manager.references)
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
                                ArticleContentView(content: subcontent, references: self.manager.references, from: .unorderedList)
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
                                    references: self.manager.references,
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
                
                ForEach(tabSelection.condensedContent) { tabContents in
                    ArticleContentView(content: tabContents, references: manager.references, alignment: .top)
                }
            }
        case .reference:
            if let identifier = content.identifier, let referenceText = manager.getReferenceText(for: identifier) {
                Text(referenceText)
            }
        case .table:
            if let rows = content.rows {
                tableView(rows: rows)
            }
        case .emphasis:
            if let inlineContent = content.inlineContent {
                ForEach(inlineContent) { inline in
                    let string = manager.getEmphasisString(inline)
                    
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
                        .applyCodeFont()
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: self.manager.alignment)
                        .foregroundStyle(Color.primary)
                        .overlay(alignment: .topTrailing) {
                            CodeCopyOverlayButton(string: code.joined(separator: "\n"))
                        }
                }
            }
#if os(visionOS)
            .backgroundStyle(colorScheme == .dark ? .black : .white)
#endif
        case .thematicBreak:
            Divider()
        case .aside:
            if let style = content.style {
                AsideView(style: style, content: content.content ?? [], references: manager.references)
            }
        case .code:
            let attributedString = manager.getCodeString(content.code ?? [])
            
            Text(attributedString)
                .applyCodeFont()
                .textSelection(.enabled)
        case .codeVoice:
            let attributedString = manager.getCodeString(content.code ?? [])
            
            Text(attributedString)
                .applyCodeFont()
                .textSelection(.enabled)
        case .links:
            if let linkItems = content.linkItems, let Style = content.style {
                LinksGridListView(identifiers: linkItems, style: Style, references: manager.references, navigationViewModel: navigationViewModel)
            }
        case .row:
            if (content.columns ?? []).filter({ $0.size > 1 }).isEmpty {
                let widthDeterminedColumns: Int = if let viewSize {
                    max(1, Int(viewSize.width / 350))
                } else {
                    content.columns?.count ?? 1
                }
                
                LazyVGrid(columns: .init(repeating: .init(.flexible(minimum: 50)), count: min(content.columns?.count ?? 1, widthDeterminedColumns)), alignment: self.manager.alignment.horizontal, spacing: 20) {
                    ForEach(content.columns ?? [], id: \.self) { column in
                        VStack(alignment: .center) {
                            ForEach(column.content) { content in
                                ArticleContentView(content: content, references: manager.references)
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .top)
                    }
                }
            } else {
                HStack {
                    let columnNumber = content.numberOfColumns ?? (content.columns ?? []).reduce(0, { partialResult, column in
                        partialResult.advanced(by: column.size)
                    })
                    let columnWidth = if let viewSize {
                        viewSize.width/CGFloat(columnNumber)
                    } else {
                        // Should not be shown because viewSize is set instantly
                        50.0
                    }
                    
                    ForEach(content.columns ?? [], id: \.self) { column in
                        VStack(alignment: .center) {
                            ForEach(column.content) { content in
                                ArticleContentView(content: content, references: manager.references)
                            }
                        }
                        .frame(maxWidth: columnWidth*CGFloat(column.size), maxHeight: .infinity, alignment: .top)
                    }
                }
            }
        case .none:
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
                        ArticleContentView(content: item, references: self.manager.references)
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
    
    func fetchPhotoVideoURL(for identifier: String) -> URL? {
        manager.fetchPhotoVideoURL(for: identifier, colorScheme: colorScheme, docCSite: docCSite)
    }
    
    // swiftlint:disable shorthand_operator cyclomatic_complexity
    struct InlineContentView: View {
        let content: [ContentStruct]
        let alignment: Alignment?
        
        @Environment(\.colorScheme) private var colorScheme
        @Environment(\.docCSite) private var docCSite
        
        @Environment(ArticleContentManager.self) private var manager
        
        init(for content: [ContentStruct], alignment: Alignment? = nil) {
            self.content = content
            self.alignment = alignment
        }
        
        func fetchPhotoVideoURL(for identifier: String) -> URL? {
            manager.fetchPhotoVideoURL(for: identifier, colorScheme: colorScheme, docCSite: docCSite)
        }
        
        var body: some View {
            var views: [InlineContent] = []
            
            var text: AttributedString = manager.specialStyleString("", type: .text)
            
            func appendText() {
                views.append(.init(Text(text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: alignment ?? self.manager.alignment)))
                text = manager.specialStyleString("", type: .text)
            }
            
            func appendContent(_ content: [ContentStruct]) {
                for inline in content {
                    switch inline.type {
                    case .text, .orderedList, .unorderedList, .paragraph, .heading:
                        let inlineText: String
                        
                        if let text = inline.text {
                            inlineText = text
                        } else if let text = inline.code {
                            inlineText = text
                        } else if let identifier = inline.identifier {
                            // Get reference if possible
                            if let reference = manager.references[identifier], let title = reference.title {
                                inlineText = title
                            } else {
                                // Fallback to parsing identifier for text if not possible
                                inlineText = String(identifier.split(separator: "/").last?.split(separator: "-").first ?? "").capitalized
                            }
                        } else {
                            inlineText = ""
                        }
                        
                        if !(inline.text == " " && content.filter({ !($0.text ?? "").isEmpty }).first == inline) {
                            var attributedString = manager.specialStyleString(inlineText, type: inline.type, orderedListIndex: inline.orderedListInt)
                            
                            if let font = inline.font?.font {
                                if let weight = inline.fontWeight?.fontWeight {
                                    attributedString.font = font.weight(weight)
                                } else {
                                    attributedString.font = font
                                }
                            } else if let weight = inline.fontWeight?.fontWeight {
                                attributedString.font = .body.weight(weight)
                            }
                            
                            if let identifier = inline.identifier {
                                // Get official link if possible
                                if let reference = manager.references[identifier], let url = reference.externalURL {
                                    attributedString.link = url
                                } else {
                                    // Fall back to parsing identifier if not possible
                                    attributedString.link = URL(string: identifier)
                                }
                            }
                            
                            if inlineText == "/%1.5_break_/%" {
                                attributedString = AttributedString("\n\n")
                                attributedString.font = .system(size: 2)
                            }
                            
                            text = text + attributedString
                        }
                    case .codeVoice:
                        let attributedString = self.manager.getCodeString(inline)
                        
                        text = text + attributedString
                    case .emphasis:
                        if inline.inlineContent?.isAllSomeFormOfText == true {
                            text += inline.getFlattenedAttributedString()
                            continue
                        }
                        
                        let string = manager.getEmphasisString(inline)
                        var attributedString = AttributedString(string)
                        attributedString.font = .body.italic()
                        
                        text = text + attributedString
                    case .strong:
                        if inline.inlineContent?.isAllSomeFormOfText == true {
                            text += inline.getFlattenedAttributedString()
                            continue
                        }
                        
                        let string = manager.getEmphasisString(inline)
                        var attributedString = AttributedString(string)
                        attributedString.font = .body.bold()
                        
                        text = text + attributedString
                    case .reference:
                        if let identifier = inline.identifier, let referenceText = manager.getReferenceText(for: identifier) {
                            text = text + referenceText
                        }
                    case .image:
                        appendText()
                        
                        if let identifier = inline.identifier {
                            let image = LazyImage(url: fetchPhotoVideoURL(for: identifier)) { state in
                                if state.isLoading {
                                    RoundedRectangle(cornerRadius: 25)
                                        .fill(Color.clear)
                                        .stroke(Color.primary, lineWidth: 2)
                                        .scaledToFit()
                                        .overlay {
                                            ProgressView()
                                        }
                                } else if let image = state.image {
                                    image
                                    .resizable()
                                    .scaledToFit()
                                }
                            }
                                .frame(maxWidth: 700, maxHeight: 700, alignment: self.manager.alignment)
                                .padding(.bottom)
                                .onTapGesture {
                                    if let url = fetchPhotoVideoURL(for: identifier) {
                                        self.manager.enlargedImageSheetIdentifier = .init(identifier: identifier, url: url)
                                    }
                                }

                            views.append(image)
                            for ref in inline.metadata?.abstract ?? [] {
                                views.append(InlineContentView(for: [ref], alignment: .top).multilineTextAlignment(.center))
                            }
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
                    
                    if let inlineContent = inline.inlineContent {
                        appendContent(inlineContent)
                    }
                }
            }
            appendContent(content)
            
            if text != AttributedString("") {
                appendText()
            }
            
            return VStack {
                ForEach(views) { inlineContent in
                    inlineContent.view
                }
            }
            .padding(.bottom, [ContentType.unorderedList, .orderedList].contains(manager.type) ? 5 : 0)
        }
    }
    // swiftlint:enable shorthand_operator cyclomatic_complexity
    
    fileprivate struct InlineContent: Identifiable {
        let id = UUID()
        
        let view: AnyView
        
        init(_ view: any View) {
            self.view = AnyView(view)
        }
    }
}

private extension [ArticleContentView.InlineContent] {
    mutating func append(_ view: any View) {
        self.append(.init(view))
    }
}

// swiftlint:enable type_body_length
